/**
 * TicketRepository - Data Access Layer cho Module 4: Incident Management (UC18-UC21)
 *
 * Thao tác trên bảng repair_tickets, join apartments để lấy unit_number.
 * Chỉ chứa truy vấn thuần; nghiệp vụ/validate nằm ở ticket.service.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 4 (RepairTicketRepository)
 */

import { query } from '@/lib/db';
import { RepairTicket, TaskStatus, TicketStatus } from '@/types';

/** Dòng repair_tickets kèm unit_number (join apartments) cho danh sách/chi tiết. */
export interface TicketRow extends RepairTicket {
  unit_number: string;
}

/**
 * UC18 (Resident): danh sách sự cố do chính cư dân này báo.
 * Lọc theo status nếu truyền. Sắp xếp mới nhất trước.
 */
export async function findTicketsByResident(
  residentId: number,
  status?: TicketStatus,
): Promise<TicketRow[]> {
  const params: unknown[] = [residentId];
  let statusClause = '';
  if (status) {
    params.push(status);
    statusClause = ` AND rt.status = $${params.length}`;
  }

  const result = await query(
    `SELECT rt.*, a.unit_number
     FROM repair_tickets rt
     JOIN apartments a ON a.id = rt.apartment_id
     WHERE rt.resident_id = $1${statusClause}
     ORDER BY rt.created_at DESC`,
    params,
  );
  return result.rows;
}

/**
 * UC18 (Manager): danh sách toàn bộ sự cố trong tòa nhà.
 * Lọc theo status nếu truyền. Sắp xếp mới nhất trước.
 */
export async function findAllTickets(status?: TicketStatus): Promise<TicketRow[]> {
  const params: unknown[] = [];
  let statusClause = '';
  if (status) {
    params.push(status);
    statusClause = ` WHERE rt.status = $${params.length}`;
  }

  const result = await query(
    `SELECT rt.*, a.unit_number
     FROM repair_tickets rt
     JOIN apartments a ON a.id = rt.apartment_id${statusClause}
     ORDER BY rt.created_at DESC`,
    params,
  );
  return result.rows;
}

/** Căn hộ đang thuê của cư dân (PRE-02 UC19). */
export interface ResidentApartment {
  id: number;
  unit_number: string;
  floor: string;
}

/**
 * UC19 (PRE-02/BR-39): căn hộ mà cư dân đang gắn qua hợp đồng ACTIVE.
 * Trả null nếu cư dân không có hợp đồng đang hiệu lực -> không được tạo sự cố.
 */
export async function findActiveApartmentByResident(
  residentId: number,
): Promise<ResidentApartment | null> {
  const result = await query(
    `SELECT a.id, a.unit_number, a.floor
     FROM contracts c
     JOIN apartments a ON a.id = c.apartment_id
     WHERE c.resident_id = $1 AND c.status = 'ACTIVE'
     ORDER BY c.created_at DESC
     LIMIT 1`,
    [residentId],
  );
  return result.rows[0] ?? null;
}

/**
 * Dòng chi tiết sự cố (UC20): ticket + người báo cáo + task mới nhất (nếu có).
 * Cột task_* NULL khi ticket chưa được phân công (UC21).
 */
export interface TicketDetailRow extends TicketRow {
  resident_name: string;
  resident_phone: string;
  task_id: number | null;
  task_assigned_to: number | null;
  task_assignee_name: string | null;
  task_title: string | null;
  task_status: TaskStatus | null;
  task_assigned_at: Date | null;
  task_completed_at: Date | null;
}

/**
 * UC20: chi tiết một sự cố theo id.
 * Join users để lấy người báo cáo; LATERAL lấy task mới nhất gắn với ticket
 * (thiết kế 1 ticket - 1 task, LIMIT 1 phòng thủ nếu có dữ liệu cũ trùng).
 */
export async function findTicketDetailById(id: number): Promise<TicketDetailRow | null> {
  const result = await query(
    `SELECT rt.*, a.unit_number,
            u.full_name  AS resident_name,
            u.phone_number AS resident_phone,
            t.id          AS task_id,
            t.assigned_to AS task_assigned_to,
            su.full_name  AS task_assignee_name,
            t.title       AS task_title,
            t.status      AS task_status,
            t.assigned_at AS task_assigned_at,
            t.completed_at AS task_completed_at
     FROM repair_tickets rt
     JOIN apartments a ON a.id = rt.apartment_id
     JOIN users u ON u.id = rt.resident_id
     LEFT JOIN LATERAL (
       SELECT * FROM tasks
       WHERE ticket_id = rt.id
       ORDER BY assigned_at DESC
       LIMIT 1
     ) t ON TRUE
     LEFT JOIN users su ON su.id = t.assigned_to
     WHERE rt.id = $1`,
    [id],
  );
  return result.rows[0] ?? null;
}

/**
 * UC20: đổi trạng thái + ghi chú nội bộ (transition đã validate ở service - BR-40).
 * - internalNotes null = giữ nguyên ghi chú cũ.
 * - purgeImages true (khi CANCELLED - BR-38): xóa luôn URL ảnh trong DB,
 *   ảnh trên Cloudinary do service xóa.
 */
export async function updateTicketStatus(
  id: number,
  status: TicketStatus,
  internalNotes: string | null,
  purgeImages: boolean,
): Promise<void> {
  await query(
    `UPDATE repair_tickets
     SET status = $2,
         internal_notes = COALESCE($3, internal_notes),
         before_images = CASE WHEN $4 THEN '{}'::text[] ELSE before_images END,
         updated_at = NOW()
     WHERE id = $1`,
    [id, status, internalNotes, purgeImages],
  );
}

/**
 * UC19: tạo sự cố mới (mặc định PENDING theo schema).
 * Trả về ticket kèm unit_number (dùng CTE để chỉ 1 vòng truy vấn).
 */
export async function createTicket(
  residentId: number,
  apartmentId: number,
  category: string,
  description: string,
  beforeImages: string[],
): Promise<TicketRow> {
  const result = await query(
    `WITH ins AS (
       INSERT INTO repair_tickets (apartment_id, resident_id, category, description, before_images)
       VALUES ($1, $2, $3, $4, $5::text[])
       RETURNING *
     )
     SELECT ins.*, a.unit_number
     FROM ins JOIN apartments a ON a.id = ins.apartment_id`,
    [apartmentId, residentId, category, description, beforeImages],
  );
  return result.rows[0];
}
