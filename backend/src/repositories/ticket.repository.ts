/**
 * TicketRepository - Data Access Layer cho Module 4: Incident Management (UC18-UC21)
 *
 * Thao tác trên bảng repair_tickets, join apartments để lấy unit_number.
 * Chỉ chứa truy vấn thuần; nghiệp vụ/validate nằm ở ticket.service.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 4 (RepairTicketRepository)
 */

import { PoolClient } from 'pg';
import { query } from '@/lib/db';
import { RepairTicket, StaffRole, TaskStatus, TicketStatus } from '@/types';

/**
 * Dòng repair_tickets kèm unit_number + tên người báo + tên nhân viên đang
 * được giao (FID-18 field 8-9; null khi ticket chưa phân công).
 */
export interface TicketRow extends RepairTicket {
  unit_number: string;
  resident_name: string;
  assignee_name: string | null;
}

/** SELECT chung cho danh sách UC18: join căn hộ, người báo và task mới nhất. */
const TICKET_LIST_SELECT = `
  SELECT rt.*, a.unit_number, u.full_name AS resident_name,
         asg.full_name AS assignee_name
  FROM repair_tickets rt
  JOIN apartments a ON a.id = rt.apartment_id
  JOIN users u ON u.id = rt.resident_id
  LEFT JOIN LATERAL (
    SELECT t.assigned_to FROM tasks t
    WHERE t.ticket_id = rt.id AND t.status <> 'CANCELLED'
    ORDER BY t.assigned_at DESC LIMIT 1
  ) lt ON TRUE
  LEFT JOIN users asg ON asg.id = lt.assigned_to`;

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
    `${TICKET_LIST_SELECT}
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
    `${TICKET_LIST_SELECT}${statusClause}
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
  task_assignee_phone: string | null;
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
            su.phone_number AS task_assignee_phone,
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

// ==========================================
// UC21: Assign Task
// ==========================================

/** 1 nhân viên khả dụng để phân công (UC21 - BR-41). */
export interface AssignableStaffRow {
  id: number;
  full_name: string;
  roles: StaffRole[];
  open_task_count: number;
}

/**
 * UC21 (BR-41): danh sách nhân viên ACTIVE thuộc CẢ 3 role vận hành
 * (SECURITY_GUARD / JANITOR / TECHNICIAN) kèm số task đang hoạt động
 * (ASSIGNED + IN_PROGRESS) để Manager cân nhắc tải việc.
 */
export async function findAssignableStaff(): Promise<AssignableStaffRow[]> {
  const result = await query(
    `SELECT u.id, u.full_name, u.roles,
            COALESCE(t.open_count, 0)::int AS open_task_count
     FROM users u
     LEFT JOIN LATERAL (
       SELECT COUNT(*) AS open_count
       FROM tasks
       WHERE tasks.assigned_to = u.id
         AND tasks.status IN ('ASSIGNED', 'IN_PROGRESS')
     ) t ON TRUE
     WHERE u.roles && ARRAY['SECURITY_GUARD','JANITOR','TECHNICIAN']::text[]
       AND u.status = 'ACTIVE'
     ORDER BY t.open_count ASC, u.full_name ASC`,
  );
  return result.rows;
}

/**
 * UC21: nhân viên hợp lệ để nhận việc - phải ACTIVE và giữ role vận hành.
 * Trả null nếu không thỏa (service báo lỗi 400).
 */
export async function findAssignableStaffById(
  staffId: number,
): Promise<AssignableStaffRow | null> {
  const result = await query(
    `SELECT u.id, u.full_name, u.roles, 0::int AS open_task_count
     FROM users u
     WHERE u.id = $1
       AND u.status = 'ACTIVE'
       AND u.roles && ARRAY['SECURITY_GUARD','JANITOR','TECHNICIAN']::text[]`,
    [staffId],
  );
  return result.rows[0] ?? null;
}

/**
 * UC21 (chạy trong transaction): chuyển ticket PENDING -> ASSIGNED.
 * Điều kiện status = 'PENDING' nằm ngay trong UPDATE để chống race khi
 * 2 Manager phân công cùng lúc (AT3) - trả false nếu ticket đã đổi trạng thái.
 */
export async function markTicketAssigned(
  client: PoolClient,
  ticketId: number,
): Promise<boolean> {
  const result = await client.query(
    `UPDATE repair_tickets
     SET status = 'ASSIGNED', updated_at = NOW()
     WHERE id = $1 AND status = 'PENDING'
     RETURNING id`,
    [ticketId],
  );
  return (result.rowCount ?? 0) > 0;
}

/**
 * UC23 (chạy trong transaction): đồng bộ trạng thái ticket theo tiến độ task
 * (task IN_PROGRESS -> ticket PROCESSING, task COMPLETED -> ticket RESOLVED).
 */
export async function setTicketStatus(
  client: PoolClient,
  ticketId: number,
  status: TicketStatus,
): Promise<void> {
  await client.query(
    `UPDATE repair_tickets SET status = $2, updated_at = NOW() WHERE id = $1`,
    [ticketId, status],
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

/**
 * Counts unresolved incident tickets (PENDING, ASSIGNED, PROCESSING) for a specific month (BR-05, BR-07, BR-09).
 * If monthYear is omitted, it counts all active unresolved tickets.
 *
 * @param monthYear Optional month filter in format 'MM/YYYY'
 * @returns The unresolved tickets count
 */
export async function countActiveUnresolvedTickets(monthYear?: string): Promise<number> {
  let sql = `
    SELECT COUNT(*)::int AS count 
    FROM repair_tickets 
    WHERE status IN ('PENDING', 'ASSIGNED', 'PROCESSING')
  `;
  const params: any[] = [];
  if (monthYear) {
    sql += ` AND TO_CHAR(created_at, 'MM/YYYY') = $1`;
    params.push(monthYear);
  }
  const result = await query(sql, params);
  return result.rows[0].count;
}
