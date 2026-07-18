/**
 * POST /api/tickets/:id/assign - UC21: Phân công sự cố cho nhân viên
 *   Body JSON: { assignedTo, title, description? }
 *   Chỉ MANAGER / LANDLORD (BR-40). Ticket phải đang PENDING (AT3 -> 409).
 *   Tạo task ASSIGNED + đổi ticket sang ASSIGNED trong 1 transaction;
 *   nhân viên được giao nhận thông báo (BR-18).
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as ticketService from '@/services/ticket.service';

function parseTicketId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Mã sự cố không hợp lệ.');
  }
  return id;
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const auth = await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { id } = await params;
    const body = await req.json().catch(() => {
      throw new HttpError(400, 'Dữ liệu gửi lên không hợp lệ (yêu cầu JSON).');
    });
    const data = await ticketService.assignTicket(auth.id, parseTicketId(id), {
      assignedTo: typeof body.assignedTo === 'number' ? body.assignedTo : undefined,
      title: typeof body.title === 'string' ? body.title : undefined,
      description:
        typeof body.description === 'string' ? body.description : undefined,
    });
    return jsonSuccess('Phân công sự cố thành công.', data, 201);
  } catch (error) {
    return jsonError(error);
  }
}
