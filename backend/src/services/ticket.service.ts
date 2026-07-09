/**
 * TicketService - Business Logic cho Module 4: Incident Management (UC18-UC21)
 *
 * Business Rules chính:
 * - UC18: RESIDENT chỉ thấy sự cố của chính mình; MANAGER/LANDLORD thấy tất cả.
 * - Không lộ internal_notes ra danh sách (chỉ có ở chi tiết UC20).
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 4 (RepairTicketService)
 */

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
