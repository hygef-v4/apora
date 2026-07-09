/**
 * GET /api/tickets - UC18: Danh sách sự cố
 *   Query: ?status=PENDING|ASSIGNED|PROCESSING|RESOLVED|CANCELLED
 *   - RESIDENT: sự cố của chính mình.
 *   - MANAGER/LANDLORD: toàn bộ sự cố trong tòa.
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as ticketService from '@/services/ticket.service';

export async function GET(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['RESIDENT', 'MANAGER', 'LANDLORD']);
    const { searchParams } = req.nextUrl;
    const data = await ticketService.getTickets(auth.id, auth.roles, {
      status: searchParams.get('status') ?? undefined,
    });
    return jsonSuccess('Lấy danh sách sự cố thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
