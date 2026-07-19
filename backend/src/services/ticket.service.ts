/**
 * TicketService - Business Logic cho Module 4: Incident Management (UC18-UC21)
 *
 * Business Rules chính:
 * - UC18: RESIDENT chỉ thấy sự cố của chính mình; MANAGER/LANDLORD thấy tất cả.
 * - Không lộ internal_notes ra danh sách (chỉ có ở chi tiết UC20).
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 4 (RepairTicketService)
 */

import { deleteImagesBatch, uploadImage } from '@/lib/cloudinary';
import { withTransaction } from '@/lib/db';
import { HttpError } from '@/lib/middleware';
import * as notificationRepo from '@/repositories/notification.repository';
import * as taskRepo from '@/repositories/task.repository';
import * as ticketRepo from '@/repositories/ticket.repository';
import { sendPushNotification } from '@/services/firebase.service';
import {
  StaffWorkloadItem,
  TicketDetail,
  TicketListItem,
  TicketStatus,
  UserRole,
} from '@/types';

const TICKET_STATUSES: TicketStatus[] = [
  'PENDING',
  'ASSIGNED',
  'PROCESSING',
  'RESOLVED',
  'CANCELLED',
];

/** Danh mục sự cố hợp lệ (UC19 bước 2 - Điện/Nước/Nội thất/Khác). */
export const TICKET_CATEGORIES = ['Điện', 'Nước', 'Nội thất', 'Khác'];

/** BR-36: mô tả tối thiểu 10, tối đa 500 ký tự. */
const DESC_MIN = 10;
const DESC_MAX = 500;
/** BR-37: tối đa 3 ảnh trước sửa. */
const MAX_BEFORE_IMAGES = 3;
/** UC20: ghi chú nội bộ tối đa 500 ký tự (theo screen definition FID-20). */
const NOTES_MAX = 500;

/**
 * BR-40: máy trạng thái ticket - chỉ các bước chuyển này hợp lệ.
 * PENDING -> ASSIGNED | CANCELLED; ASSIGNED -> PROCESSING; PROCESSING -> RESOLVED.
 * RESOLVED/CANCELLED là trạng thái cuối.
 */
const TICKET_TRANSITIONS: Record<TicketStatus, TicketStatus[]> = {
  PENDING: ['ASSIGNED', 'CANCELLED'],
  ASSIGNED: ['PROCESSING'],
  PROCESSING: ['RESOLVED'],
  RESOLVED: [],
  CANCELLED: [],
};

/** Nhãn tiếng Việt của trạng thái - dùng cho message lỗi + thông báo cư dân. */
const TICKET_STATUS_LABELS: Record<TicketStatus, string> = {
  PENDING: 'Chờ xử lý',
  ASSIGNED: 'Đã phân công',
  PROCESSING: 'Đang xử lý',
  RESOLVED: 'Đã xong',
  CANCELLED: 'Đã hủy',
};

/** Ép chuỗi query ?status= về TicketStatus hợp lệ, bỏ qua nếu rỗng/sai. */
function parseStatus(raw?: string): TicketStatus | undefined {
  if (!raw) return undefined;
  if (!TICKET_STATUSES.includes(raw as TicketStatus)) {
    throw new HttpError(400, 'Trạng thái lọc không hợp lệ.');
  }
  return raw as TicketStatus;
}

function toTicketListItem(row: ticketRepo.TicketRow): TicketListItem {
  return {
    id: row.id,
    category: row.category,
    description: row.description,
    beforeImages: row.before_images,
    status: row.status,
    unitNumber: row.unit_number,
    residentName: row.resident_name,
    assigneeName: row.assignee_name,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// ==========================================
// UC18: View Ticket List
// ==========================================

/**
 * Danh sách sự cố theo vai trò người gọi.
 * - MANAGER/LANDLORD: toàn bộ sự cố trong tòa.
 * - RESIDENT: chỉ sự cố do chính mình báo.
 */
export async function getTickets(
  userId: number,
  roles: UserRole[],
  filter: { status?: string },
): Promise<TicketListItem[]> {
  const status = parseStatus(filter.status);
  const isManager = roles.includes('MANAGER') || roles.includes('LANDLORD');

  const rows = isManager
    ? await ticketRepo.findAllTickets(status)
    : await ticketRepo.findTicketsByResident(userId, status);

  return rows.map(toTicketListItem);
}

// ==========================================
// UC19: Create Ticket
// ==========================================

/**
 * Tạo sự cố mới cho cư dân (status PENDING).
 *
 * Trình tự chốt để KHÔNG bỏ rơi ảnh trên Cloudinary:
 * 1) Validate toàn bộ field text TRƯỚC (AT1 category, AT2/BR-36 description).
 * 2) Xác định căn hộ qua hợp đồng ACTIVE (PRE-02) - fail sớm trước khi upload.
 * 3) Upload ảnh, rồi INSERT; nếu INSERT lỗi thì xóa ảnh vừa upload (cleanup).
 *
 * @param imageBuffers ảnh đã validate loại/kích thước ở tầng route (BR-37).
 */
export async function createTicket(
  residentId: number,
  input: { category?: string; description?: string },
  imageBuffers: Buffer[],
): Promise<TicketListItem> {
  const category = input.category?.trim() ?? '';
  const description = input.description?.trim() ?? '';

  // AT1 (BR-36): bắt buộc chọn danh mục hợp lệ
  if (!category) {
    throw new HttpError(400, 'Vui lòng chọn danh mục sự cố.');
  }
  if (!TICKET_CATEGORIES.includes(category)) {
    throw new HttpError(400, 'Danh mục sự cố không hợp lệ.');
  }
  // AT2 (BR-36): mô tả 10-500 ký tự
  if (description.length < DESC_MIN) {
    throw new HttpError(400, `Mô tả phải có ít nhất ${DESC_MIN} ký tự.`);
  }
  if (description.length > DESC_MAX) {
    throw new HttpError(400, `Mô tả tối đa ${DESC_MAX} ký tự.`);
  }
  // BR-37: chặn phòng thủ nếu route để lọt quá 3 ảnh
  if (imageBuffers.length > MAX_BEFORE_IMAGES) {
    throw new HttpError(400, `Chỉ được đính kèm tối đa ${MAX_BEFORE_IMAGES} ảnh.`);
  }

  // PRE-02: cư dân phải gắn với 1 căn hộ đang thuê (hợp đồng ACTIVE)
  const apartment = await ticketRepo.findActiveApartmentByResident(residentId);
  if (!apartment) {
    throw new HttpError(
      400,
      'Bạn chưa gắn với căn hộ đang thuê nào nên không thể tạo yêu cầu sửa chữa.',
    );
  }

  // Upload ảnh trước, giữ danh sách URL để cleanup nếu bước sau lỗi
  const uploadedUrls: string[] = [];
  for (const buffer of imageBuffers) {
    uploadedUrls.push(await uploadImage(buffer, 'tickets'));
  }

  try {
    const row = await ticketRepo.createTicket(
      residentId,
      apartment.id,
      category,
      description,
      uploadedUrls,
    );
    return toTicketListItem(row);
  } catch (error) {
    // BR-38 (tinh thần): không để ảnh mồ côi trên Cloudinary khi ghi DB thất bại
    if (uploadedUrls.length > 0) {
      try {
        await deleteImagesBatch(uploadedUrls);
      } catch (cleanupError) {
        console.error('[TicketService] Cleanup ảnh mồ côi thất bại:', cleanupError);
      }
    }
    throw error;
  }
}

// ==========================================
// UC20: Update Ticket Status
// ==========================================

function toTicketDetail(row: ticketRepo.TicketDetailRow): TicketDetail {
  return {
    ...toTicketListItem(row),
    residentId: row.resident_id,
    residentName: row.resident_name,
    residentPhone: row.resident_phone,
    internalNotes: row.internal_notes,
    assignedTask:
      row.task_id === null
        ? null
        : {
            id: row.task_id,
            assignedTo: row.task_assigned_to!,
            assigneeName: row.task_assignee_name!,
            assigneePhone: row.task_assignee_phone,
            title: row.task_title!,
            status: row.task_status!,
            assignedAt: row.task_assigned_at!,
            completedAt: row.task_completed_at,
          },
  };
}

/**
 * UC20: chi tiết một sự cố.
 * - MANAGER/LANDLORD: xem đầy đủ (kèm ghi chú nội bộ + task đã phân công).
 * - RESIDENT: chỉ đọc sự cố của chính mình (BR-39); trả 404 với ticket của
 *   người khác để không lộ sự tồn tại (cô lập dữ liệu BR-23), và ẩn internalNotes.
 */
export async function getTicketDetail(
  userId: number,
  roles: UserRole[],
  ticketId: number,
): Promise<TicketDetail> {
  const row = await ticketRepo.findTicketDetailById(ticketId);
  if (!row) {
    throw new HttpError(404, 'Không tìm thấy sự cố.');
  }

  const isManager = roles.includes('MANAGER') || roles.includes('LANDLORD');
  if (!isManager) {
    if (row.resident_id !== userId) {
      throw new HttpError(404, 'Không tìm thấy sự cố.');
    }
    return { ...toTicketDetail(row), internalNotes: null };
  }
  return toTicketDetail(row);
}

/**
 * UC20: Manager/Landlord đổi trạng thái + ghi chú nội bộ.
 * - BR-40: chỉ chấp nhận transition hợp lệ; giữ nguyên status + có ghi chú
 *   = cập nhật ghi chú đơn thuần (AT4: không đổi gì cả -> 400).
 * - BR-38: hủy ticket -> purge ảnh Cloudinary + xóa URL trong DB.
 * - BR-18: đổi trạng thái thành công -> thông báo in-app + FCM cho cư dân
 *   (best-effort, lỗi noti không làm fail request).
 */
export async function updateTicketStatus(
  ticketId: number,
  input: { status?: string; internalNotes?: string },
): Promise<TicketDetail> {
  const status = input.status as TicketStatus | undefined;
  if (!status || !TICKET_STATUSES.includes(status)) {
    throw new HttpError(400, 'Trạng thái không hợp lệ.');
  }
  const notes = input.internalNotes?.trim() || undefined;
  if (notes && notes.length > NOTES_MAX) {
    throw new HttpError(400, `Ghi chú nội bộ tối đa ${NOTES_MAX} ký tự.`);
  }

  const current = await ticketRepo.findTicketDetailById(ticketId);
  if (!current) {
    throw new HttpError(404, 'Không tìm thấy sự cố.');
  }

  const statusChanged = status !== current.status;
  if (statusChanged && !TICKET_TRANSITIONS[current.status].includes(status)) {
    throw new HttpError(
      400,
      `Không thể chuyển từ "${TICKET_STATUS_LABELS[current.status]}" sang "${TICKET_STATUS_LABELS[status]}".`,
    );
  }
  // ASSIGNED chỉ được đặt qua luồng phân công (UC21/assignTicket) để LUÔN có
  // task + người xử lý đi kèm. Chặn set thủ công qua UC20 để không tạo ra
  // ticket "Đã phân công" mà không ai được giao (bất biến ASSIGNED <=> có task).
  if (statusChanged && status === 'ASSIGNED') {
    throw new HttpError(
      400,
      'Để chuyển sang "Đã phân công", vui lòng dùng chức năng phân công cho nhân viên.',
    );
  }
  // AT4: không đổi trạng thái và cũng không nhập ghi chú -> không có gì để lưu
  if (!statusChanged && !notes) {
    throw new HttpError(400, 'Không có thay đổi để lưu.');
  }

  const purgeImages = statusChanged && status === 'CANCELLED';
  await ticketRepo.updateTicketStatus(ticketId, status, notes ?? null, purgeImages);

  // BR-38: xóa ảnh trên Cloudinary SAU khi DB đã ghi (DB là nguồn chân lý;
  // xóa ảnh thất bại chỉ log, không rollback trạng thái hủy)
  if (purgeImages && current.before_images.length > 0) {
    try {
      await deleteImagesBatch(current.before_images);
    } catch (error) {
      console.error('[TicketService] Purge ảnh khi hủy ticket thất bại:', error);
    }
  }

  // BR-18: thông báo cho cư dân khi trạng thái đổi (không chặn response)
  if (statusChanged) {
    notifyResidentStatusChanged(current, status).catch((error) => {
      console.error('[TicketService] Gửi thông báo đổi trạng thái thất bại:', error);
    });
  }

  const updated = await ticketRepo.findTicketDetailById(ticketId);
  return toTicketDetail(updated!);
}

/**
 * BR-18: lưu thông báo in-app + đẩy FCM cho cư dân sở hữu ticket.
 * Export để task.service dùng lại khi tiến độ task kéo trạng thái ticket
 * đổi theo (UC23: IN_PROGRESS -> PROCESSING, COMPLETED -> RESOLVED).
 */
export async function notifyResidentStatusChanged(
  ticket: { id: number; category: string; resident_id: number },
  newStatus: TicketStatus,
): Promise<void> {
  const title = 'Cập nhật yêu cầu sửa chữa';
  const body = `Yêu cầu #TK-${ticket.id} (${ticket.category}) đã chuyển sang "${TICKET_STATUS_LABELS[newStatus]}".`;
  await notificationRepo.createNotificationsBulk(
    [ticket.resident_id],
    title,
    body,
    'TICKET',
    ticket.id,
  );
  const tokens = await notificationRepo.getActiveDeviceTokens([ticket.resident_id]);
  await sendPushNotification(tokens, title, body, {
    type: 'TICKET',
    referenceId: String(ticket.id),
  });
}

// ==========================================
// UC21: Assign Task
// ==========================================

/** Tiêu đề task: bắt buộc, tối đa 100 ký tự (VARCHAR(100) trong schema). */
const TASK_TITLE_MAX = 100;

/** BR-41: bảng tải việc nhân viên cho màn phân công (UC21). */
export async function getStaffWorkload(): Promise<StaffWorkloadItem[]> {
  const rows = await ticketRepo.findAssignableStaff();
  return rows.map((row) => ({
    id: row.id,
    fullName: row.full_name,
    roles: row.roles,
    openTaskCount: row.open_task_count,
  }));
}

/**
 * UC21: Manager/Landlord phân công sự cố cho nhân viên.
 * - AT1: title bắt buộc (≤100 ký tự); description tùy chọn ≤500.
 * - Người nhận phải là nhân viên vận hành ACTIVE (BR-40).
 * - PRE-02/AT3: ticket phải đang PENDING - check lần cuối NGAY TRONG
 *   transaction (markTicketAssigned điều kiện status=PENDING) để chống race.
 * - Tạo task ASSIGNED + đổi ticket sang ASSIGNED trong 1 transaction ACID.
 * - BR-18: báo cho nhân viên được giao + cư dân (best-effort).
 */
export async function assignTicket(
  managerId: number,
  ticketId: number,
  input: { assignedTo?: number; title?: string; description?: string },
): Promise<TicketDetail> {
  const title = input.title?.trim() ?? '';
  if (!title) {
    throw new HttpError(400, 'Vui lòng nhập tiêu đề công việc.');
  }
  if (title.length > TASK_TITLE_MAX) {
    throw new HttpError(400, `Tiêu đề công việc tối đa ${TASK_TITLE_MAX} ký tự.`);
  }
  const description = input.description?.trim() || null;
  if (description && description.length > DESC_MAX) {
    throw new HttpError(400, `Mô tả công việc tối đa ${DESC_MAX} ký tự.`);
  }
  if (!input.assignedTo || !Number.isInteger(input.assignedTo)) {
    throw new HttpError(400, 'Vui lòng chọn nhân viên để phân công.');
  }

  const ticket = await ticketRepo.findTicketDetailById(ticketId);
  if (!ticket) {
    throw new HttpError(404, 'Không tìm thấy sự cố.');
  }
  if (ticket.status !== 'PENDING') {
    throw new HttpError(
      409,
      'Không thể phân công. Sự cố không còn ở trạng thái "Chờ xử lý".',
    );
  }

  const staff = await ticketRepo.findAssignableStaffById(input.assignedTo);
  if (!staff) {
    throw new HttpError(400, 'Nhân viên không hợp lệ hoặc đã ngừng hoạt động.');
  }

  // Giao dịch ACID: đổi ticket + tạo task, không được nửa vời (CLAUDE.md)
  const task = await withTransaction(async (client) => {
    const assigned = await ticketRepo.markTicketAssigned(client, ticketId);
    if (!assigned) {
      // AT3: Manager khác vừa đổi trạng thái trong lúc mình thao tác
      throw new HttpError(
        409,
        'Không thể phân công. Sự cố không còn ở trạng thái "Chờ xử lý".',
      );
    }
    return taskRepo.insertTask(client, {
      ticketId,
      assignedTo: staff.id,
      assignedBy: managerId,
      title,
      description,
    });
  });

  // BR-18: báo nhân viên được giao + cư dân biết sự cố đã được tiếp nhận
  notifyStaffAssigned(staff.id, task.id, title, ticket.unit_number).catch((error) => {
    console.error('[TicketService] Gửi thông báo phân công thất bại:', error);
  });
  notifyResidentStatusChanged(ticket, 'ASSIGNED').catch((error) => {
    console.error('[TicketService] Gửi thông báo đổi trạng thái thất bại:', error);
  });

  const updated = await ticketRepo.findTicketDetailById(ticketId);
  return toTicketDetail(updated!);
}

/** BR-18: báo cho nhân viên vừa được giao việc (in-app + FCM). */
async function notifyStaffAssigned(
  staffId: number,
  taskId: number,
  taskTitle: string,
  unitNumber: string,
): Promise<void> {
  const title = 'Công việc mới';
  const body = `Bạn được phân công: "${taskTitle}" (Phòng ${unitNumber}).`;
  await notificationRepo.createNotificationsBulk([staffId], title, body, 'TASK', taskId);
  const tokens = await notificationRepo.getActiveDeviceTokens([staffId]);
  await sendPushNotification(tokens, title, body, {
    type: 'TASK',
    referenceId: String(taskId),
  });
}
