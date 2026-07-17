/**
 * PUT /api/tickets/:id/status - UC20: Đổi trạng thái sự cố + ghi chú nội bộ
 *   Body JSON: { status, internalNotes? }
 *   Chỉ MANAGER / LANDLORD (BR-39). Transition validate theo BR-40;
 *   hủy ticket sẽ purge ảnh (BR-38) và cư dân được nhận thông báo (BR-18).
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

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { id } = await params;
    const body = await req.json().catch(() => {
      throw new HttpError(400, 'Dữ liệu gửi lên không hợp lệ (yêu cầu JSON).');
    });
    const data = await ticketService.updateTicketStatus(parseTicketId(id), {
      status: typeof body.status === 'string' ? body.status : undefined,
      internalNotes:
        typeof body.internalNotes === 'string' ? body.internalNotes : undefined,
    });
    return jsonSuccess('Cập nhật trạng thái sự cố thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
