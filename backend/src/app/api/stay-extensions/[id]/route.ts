/**
 * GET /api/stay-extensions/:id - UC09: Chi tiết yêu cầu gia hạn (màn duyệt)
 *   Chỉ MANAGER / LANDLORD (BR-16).
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

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { id } = await params;
    const data = await contractService.getExtensionDetail(parseExtensionId(id));
    return jsonSuccess('Lấy chi tiết yêu cầu gia hạn thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
