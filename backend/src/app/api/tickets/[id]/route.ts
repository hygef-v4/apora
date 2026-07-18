/**
 * GET /api/tickets/:id - UC20: Chi tiết sự cố
 *   - MANAGER/LANDLORD: đầy đủ (kèm ghi chú nội bộ + task đã phân công).
 *   - RESIDENT: chỉ đọc sự cố của chính mình (BR-39), không thấy ghi chú nội bộ.
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

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const auth = await requireAuth(req, ['RESIDENT', 'MANAGER', 'LANDLORD']);
    const { id } = await params;
    const data = await ticketService.getTicketDetail(
      auth.id,
      auth.roles,
      parseTicketId(id),
    );
    return jsonSuccess('Lấy chi tiết sự cố thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
