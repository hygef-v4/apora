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
import { HttpError } from '@/lib/middleware';
import * as ticketRepo from '@/repositories/ticket.repository';
import { TicketListItem, TicketStatus, UserRole } from '@/types';

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
