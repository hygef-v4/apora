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
