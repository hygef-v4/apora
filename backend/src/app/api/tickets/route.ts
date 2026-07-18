/**
 * GET  /api/tickets - UC18: Danh sách sự cố
 *   Query: ?status=PENDING|ASSIGNED|PROCESSING|RESOLVED|CANCELLED
 *   - RESIDENT: sự cố của chính mình.
 *   - MANAGER/LANDLORD: toàn bộ sự cố trong tòa.
 * POST /api/tickets - UC19: Tạo sự cố (chỉ RESIDENT)
 *   Body: multipart { category, description, images[] (tối đa 3, JPG/PNG ≤5MB) }
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import { readImageUploads } from '@/lib/upload';
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

export async function POST(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['RESIDENT']);
    const form = await req.formData();
    // BR-37: tối đa 3 ảnh, validate loại/kích thước tại đây trước khi vào service
    const imageBuffers = await readImageUploads(form, 'images', 3);
    const data = await ticketService.createTicket(
      auth.id,
      {
        category: form.get('category')?.toString(),
        description: form.get('description')?.toString(),
      },
      imageBuffers,
    );
    return jsonSuccess('Gửi yêu cầu sửa chữa thành công.', data, 201);
  } catch (error) {
    return jsonError(error);
  }
}
