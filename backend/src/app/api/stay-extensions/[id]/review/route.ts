/**
 * PUT /api/stay-extensions/:id/review - UC09: Duyệt / từ chối yêu cầu gia hạn
 *   Body JSON: { action: 'APPROVE' | 'REJECT', rejectReason? }
 *   Chỉ MANAGER / LANDLORD (BR-16). APPROVE dời contracts.end_date trong
 *   1 transaction (BR-17); cư dân nhận thông báo kết quả (BR-18).
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as contractService from '@/services/contract.service';

function parseExtensionId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Mã yêu cầu gia hạn không hợp lệ.');
  }
  return id;
}

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const payload = await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { id } = await params;
    const body = await req.json().catch(() => {
      throw new HttpError(400, 'Dữ liệu gửi lên không hợp lệ (yêu cầu JSON).');
    });
    const data = await contractService.reviewExtension(
      payload.id,
      parseExtensionId(id),
      {
        action: typeof body.action === 'string' ? body.action : undefined,
        rejectReason:
          typeof body.rejectReason === 'string' ? body.rejectReason : undefined,
      },
    );
    return jsonSuccess('Xử lý yêu cầu gia hạn thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
