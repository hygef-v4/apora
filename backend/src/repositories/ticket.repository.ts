/**
 * TicketRepository - Data Access Layer cho Module 4: Incident Management (UC18-UC21)
 *
 * Thao tác trên bảng repair_tickets, join apartments để lấy unit_number.
 * Chỉ chứa truy vấn thuần; nghiệp vụ/validate nằm ở ticket.service.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 4 (RepairTicketRepository)
 */

import { query } from '@/lib/db';
import { RepairTicket, TicketStatus } from '@/types';

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
