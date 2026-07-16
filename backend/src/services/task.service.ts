/**
 * TaskService - Business Logic cho Module 4: Incident Management (UC22-UC23)
 *
 * Business Rules chính:
 * - BR-42: nhân viên chỉ thấy/cập nhật task được giao cho chính mình;
 *   MANAGER/LANDLORD được xem tất cả (chỉ xem - không cập nhật tiến độ).
 * - BR-43: đánh dấu COMPLETED bắt buộc ≥ 1 ảnh nghiệm thu.
 * - Tiến độ task kéo trạng thái ticket cha đổi theo trong 1 transaction:
 *   IN_PROGRESS -> ticket PROCESSING, COMPLETED -> ticket RESOLVED.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 4 (TaskService)
 */

import { deleteImagesBatch, uploadImage } from '@/lib/cloudinary';
import { withTransaction } from '@/lib/db';
import { HttpError } from '@/lib/middleware';
import * as taskRepo from '@/repositories/task.repository';
import * as ticketRepo from '@/repositories/ticket.repository';
import { notifyResidentStatusChanged } from '@/services/ticket.service';
import { TaskDetail, TaskListItem, TaskStatus, UserRole } from '@/types';

const TASK_STATUSES: TaskStatus[] = ['ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

/** UC23: ghi chú tiến độ tối đa 500 ký tự (FID-23 field 10). */
const NOTES_MAX = 500;
/** BR-37: tối đa 3 ảnh nghiệm thu. */
const MAX_COMPLETION_IMAGES = 3;

/** Nhãn tiếng Việt cho message lỗi chuyển trạng thái. */
const TASK_STATUS_LABELS: Record<TaskStatus, string> = {
  ASSIGNED: 'Đã giao',
  IN_PROGRESS: 'Đang làm',
  COMPLETED: 'Hoàn thành',
  CANCELLED: 'Đã hủy',
};

/**
 * Máy trạng thái task: ASSIGNED -> IN_PROGRESS -> COMPLETED
 * (cho phép hoàn thành thẳng từ ASSIGNED nếu nhân viên quên bấm bắt đầu).
 * COMPLETED/CANCELLED là trạng thái cuối.
 */
const TASK_TRANSITIONS: Record<TaskStatus, TaskStatus[]> = {
  ASSIGNED: ['IN_PROGRESS', 'COMPLETED'],
  IN_PROGRESS: ['COMPLETED'],
  COMPLETED: [],
  CANCELLED: [],
};

/** Ép chuỗi query ?status= về filter hợp lệ (1 trạng thái hoặc ACTIVE). */
function parseStatusFilter(raw?: string): TaskStatus | 'ACTIVE' | undefined {
  if (!raw) return undefined;
  if (raw === 'ACTIVE') return 'ACTIVE';
  if (!TASK_STATUSES.includes(raw as TaskStatus)) {
    throw new HttpError(400, 'Trạng thái lọc không hợp lệ.');
  }
  return raw as TaskStatus;
}

function toTaskListItem(row: taskRepo.TaskRow): TaskListItem {
  return {
    id: row.id,
    ticketId: row.ticket_id,
    title: row.title,
    description: row.description,
    status: row.status,
    category: row.category,
    unitNumber: row.unit_number,
    assignedByName: row.assigned_by_name,
    assignedAt: row.assigned_at,
    completedAt: row.completed_at,
  };
}

function toTaskDetail(row: taskRepo.TaskDetailRow): TaskDetail {
  return {
    ...toTaskListItem(row),
    ticketDescription: row.ticket_description,
    ticketBeforeImages: row.ticket_before_images,
    residentName: row.resident_name,
    progressNotes: row.progress_notes,
    completionImages: row.completion_images,
  };
}

// ==========================================
// UC22: View Task List
// ==========================================

/**
 * Danh sách công việc theo vai trò (BR-39/BR-42):
 * - Staff: chỉ task được giao cho chính mình.
 * - MANAGER/LANDLORD: toàn bộ task của mọi nhân viên (chỉ đọc).
 */
export async function getTasks(
  userId: number,
  roles: UserRole[],
  filter: { status?: string },
): Promise<TaskListItem[]> {
  const status = parseStatusFilter(filter.status);
  const isManager = roles.includes('MANAGER') || roles.includes('LANDLORD');

  const rows = isManager
    ? await taskRepo.findAllTasks(status)
    : await taskRepo.findTasksByAssignee(userId, status);

  return rows.map(toTaskListItem);
}

// ==========================================
// UC23: Update Progress
// ==========================================

/**
 * UC23: chi tiết công việc (kèm ngữ cảnh sự cố cha).
 * BR-42: chỉ nhân viên được giao hoặc MANAGER/LANDLORD; người khác trả 404
 * để không lộ sự tồn tại.
 */
export async function getTaskDetail(
  userId: number,
  roles: UserRole[],
  taskId: number,
): Promise<TaskDetail> {
  const row = await taskRepo.findTaskDetailById(taskId);
  if (!row) {
    throw new HttpError(404, 'Không tìm thấy công việc.');
  }
  const isManager = roles.includes('MANAGER') || roles.includes('LANDLORD');
  if (!isManager && row.assigned_to !== userId) {
    throw new HttpError(404, 'Không tìm thấy công việc.');
  }
  return toTaskDetail(row);
}

/**
 * UC23: nhân viên cập nhật tiến độ công việc của CHÍNH MÌNH (BR-42).
 * - status: IN_PROGRESS (bắt đầu làm) hoặc COMPLETED (nghiệm thu).
 * - COMPLETED bắt buộc ≥ 1 ảnh nghiệm thu (BR-43), tối đa 3 (BR-37);
 *   ảnh upload Cloudinary TRƯỚC, nếu ghi DB lỗi thì xóa ảnh (không mồ côi).
 * - Task + ticket cha cập nhật trong 1 transaction:
 *   IN_PROGRESS -> ticket PROCESSING; COMPLETED -> ticket RESOLVED.
 * - BR-18: cư dân nhận thông báo khi trạng thái ticket đổi (best-effort).
 */
export async function updateTaskProgress(
  staffId: number,
  taskId: number,
  input: { status?: string; progressNotes?: string },
  imageBuffers: Buffer[],
): Promise<TaskDetail> {
  const status = input.status as TaskStatus | undefined;
  if (!status || !TASK_STATUSES.includes(status)) {
    throw new HttpError(400, 'Trạng thái không hợp lệ.');
  }
  const notes = input.progressNotes?.trim() || undefined;
  if (notes && notes.length > NOTES_MAX) {
    throw new HttpError(400, `Ghi chú tiến độ tối đa ${NOTES_MAX} ký tự.`);
  }

  const task = await taskRepo.findTaskDetailById(taskId);
  if (!task || task.assigned_to !== staffId) {
    // BR-42: task của người khác trả 404 như không tồn tại
    throw new HttpError(404, 'Không tìm thấy công việc.');
  }

  if (!TASK_TRANSITIONS[task.status].includes(status)) {
    throw new HttpError(
      400,
      `Không thể chuyển từ "${TASK_STATUS_LABELS[task.status]}" sang "${TASK_STATUS_LABELS[status]}".`,
    );
  }

  // BR-43: nghiệm thu bắt buộc có ảnh chứng minh; BR-37: tối đa 3 ảnh
  if (status === 'COMPLETED' && imageBuffers.length === 0) {
    throw new HttpError(400, 'Cần ít nhất 1 ảnh nghiệm thu để hoàn thành công việc.');
  }
  if (imageBuffers.length > MAX_COMPLETION_IMAGES) {
    throw new HttpError(400, `Chỉ được đính kèm tối đa ${MAX_COMPLETION_IMAGES} ảnh.`);
  }

  // Upload ảnh trước, giữ URL để cleanup nếu transaction lỗi
  const uploadedUrls: string[] = [];
  for (const buffer of imageBuffers) {
    uploadedUrls.push(await uploadImage(buffer, 'tasks'));
  }

  // Ticket cha đổi theo: bắt đầu làm -> PROCESSING, hoàn thành -> RESOLVED
  const newTicketStatus = status === 'COMPLETED' ? 'RESOLVED' : 'PROCESSING';
  try {
    await withTransaction(async (client) => {
      await taskRepo.updateTaskProgress(
        client,
        taskId,
        status,
        notes ?? null,
        uploadedUrls.length > 0 ? uploadedUrls : null,
      );
      await ticketRepo.setTicketStatus(client, task.ticket_id, newTicketStatus);
    });
  } catch (error) {
    if (uploadedUrls.length > 0) {
      try {
        await deleteImagesBatch(uploadedUrls);
      } catch (cleanupError) {
        console.error('[TaskService] Cleanup ảnh mồ côi thất bại:', cleanupError);
      }
    }
    throw error;
  }

  // BR-18: cư dân được báo khi ticket đổi trạng thái (không chặn response)
  notifyResidentStatusChanged(
    { id: task.ticket_id, category: task.category, resident_id: task.resident_id },
    newTicketStatus,
  ).catch((error) => {
    console.error('[TaskService] Gửi thông báo đổi trạng thái thất bại:', error);
  });

  const updated = await taskRepo.findTaskDetailById(taskId);
  return toTaskDetail(updated!);
}
