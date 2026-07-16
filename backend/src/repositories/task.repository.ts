/**
 * TaskRepository - Data Access Layer cho Module 4: Incident Management (UC21-UC23)
 *
 * Thao tác trên bảng tasks, join repair_tickets/apartments/users để lấy
 * ngữ cảnh sự cố. Chỉ chứa truy vấn thuần; nghiệp vụ nằm ở task.service.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 4 (TaskRepository)
 */

import { PoolClient } from 'pg';
import { query } from '@/lib/db';
import { Task, TaskStatus } from '@/types';

/** Dòng task kèm ngữ cảnh ticket cha (category, phòng) + tên người giao (UC22). */
export interface TaskRow extends Task {
  category: string;
  unit_number: string;
  assigned_by_name: string;
}

/** Dòng chi tiết task (UC23): thêm mô tả + ảnh gốc + người báo của sự cố. */
export interface TaskDetailRow extends TaskRow {
  ticket_description: string;
  ticket_before_images: string[];
  ticket_status: string;
  resident_id: number;
  resident_name: string;
}

const TASK_SELECT = `
  SELECT t.*, rt.category, a.unit_number, mgr.full_name AS assigned_by_name
  FROM tasks t
  JOIN repair_tickets rt ON rt.id = t.ticket_id
  JOIN apartments a ON a.id = rt.apartment_id
  JOIN users mgr ON mgr.id = t.assigned_by`;

/**
 * UC21 (chạy trong transaction): tạo task ASSIGNED gắn với ticket.
 * Đi cùng markTicketAssigned trong CÙNG transaction - không được nửa vời.
 */
export async function insertTask(
  client: PoolClient,
  input: {
    ticketId: number;
    assignedTo: number;
    assignedBy: number;
    title: string;
    description: string | null;
  },
): Promise<Task> {
  const result = await client.query(
    `INSERT INTO tasks (ticket_id, assigned_to, assigned_by, title, description)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [input.ticketId, input.assignedTo, input.assignedBy, input.title, input.description],
  );
  return result.rows[0];
}

/**
 * UC22: danh sách công việc của 1 nhân viên (BR-42: chỉ việc của chính mình).
 * statusFilter: 1 trạng thái cụ thể, hoặc 'ACTIVE' = ASSIGNED + IN_PROGRESS.
 * Sắp xếp mới giao trước.
 */
export async function findTasksByAssignee(
  staffId: number,
  statusFilter?: TaskStatus | 'ACTIVE',
): Promise<TaskRow[]> {
  const params: unknown[] = [staffId];
  let statusClause = '';
  if (statusFilter === 'ACTIVE') {
    statusClause = ` AND t.status IN ('ASSIGNED', 'IN_PROGRESS')`;
  } else if (statusFilter) {
    params.push(statusFilter);
    statusClause = ` AND t.status = $${params.length}`;
  }

  const result = await query(
    `${TASK_SELECT}
     WHERE t.assigned_to = $1${statusClause}
     ORDER BY t.assigned_at DESC`,
    params,
  );
  return result.rows;
}

/** UC22 (BR-39): Manager/Landlord xem toàn bộ công việc của mọi nhân viên. */
export async function findAllTasks(
  statusFilter?: TaskStatus | 'ACTIVE',
): Promise<TaskRow[]> {
  const params: unknown[] = [];
  let statusClause = '';
  if (statusFilter === 'ACTIVE') {
    statusClause = ` WHERE t.status IN ('ASSIGNED', 'IN_PROGRESS')`;
  } else if (statusFilter) {
    params.push(statusFilter);
    statusClause = ` WHERE t.status = $${params.length}`;
  }

  const result = await query(
    `${TASK_SELECT}${statusClause}
     ORDER BY t.assigned_at DESC`,
    params,
  );
  return result.rows;
}

/** UC23: chi tiết task kèm mô tả + ảnh gốc + trạng thái của sự cố cha. */
export async function findTaskDetailById(id: number): Promise<TaskDetailRow | null> {
  const result = await query(
    `SELECT t.*, rt.category, a.unit_number, mgr.full_name AS assigned_by_name,
            rt.description   AS ticket_description,
            rt.before_images AS ticket_before_images,
            rt.status        AS ticket_status,
            rt.resident_id,
            res.full_name    AS resident_name
     FROM tasks t
     JOIN repair_tickets rt ON rt.id = t.ticket_id
     JOIN apartments a ON a.id = rt.apartment_id
     JOIN users mgr ON mgr.id = t.assigned_by
     JOIN users res ON res.id = rt.resident_id
     WHERE t.id = $1`,
    [id],
  );
  return result.rows[0] ?? null;
}

/**
 * UC23 (chạy trong transaction): cập nhật tiến độ task.
 * - progressNotes null = giữ ghi chú cũ.
 * - completionImages: chỉ ghi khi COMPLETED (mảng URL Cloudinary).
 * - completed_at chỉ set khi status = COMPLETED (BR nghiệm thu).
 */
export async function updateTaskProgress(
  client: PoolClient,
  taskId: number,
  status: TaskStatus,
  progressNotes: string | null,
  completionImages: string[] | null,
): Promise<void> {
  await client.query(
    `UPDATE tasks
     SET status = $2::varchar,
         progress_notes = COALESCE($3, progress_notes),
         completion_images = COALESCE($4::text[], completion_images),
         completed_at = CASE WHEN $2::varchar = 'COMPLETED' THEN NOW() ELSE completed_at END
     WHERE id = $1`,
    [taskId, status, progressNotes, completionImages],
  );
}
