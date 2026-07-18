/**
 * /api/stay-extensions - Module 2: Stay Extension
 *   GET  - UC08: danh sách yêu cầu gia hạn (?status=PENDING|APPROVED|REJECTED)
 *          Chỉ MANAGER / LANDLORD (BR-16).
 *   POST - UC07: cư dân gửi yêu cầu gia hạn { requestedEndDate, reason }
 *          Chỉ RESIDENT; validate BR-12/BR-14/BR-15, chặn trùng PENDING.
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as contractService from '@/services/contract.service';

export async function GET(req: NextRequest) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const status = req.nextUrl.searchParams.get('status') ?? undefined;
    const data = await contractService.getExtensions({ status });
    return jsonSuccess('Lấy danh sách yêu cầu gia hạn thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}

export async function POST(req: NextRequest) {
  try {
    const payload = await requireAuth(req, ['RESIDENT']);
    const body = await req.json().catch(() => {
      throw new HttpError(400, 'Dữ liệu gửi lên không hợp lệ (yêu cầu JSON).');
    });
    const data = await contractService.requestExtension(payload.id, {
      requestedEndDate:
        typeof body.requestedEndDate === 'string' ? body.requestedEndDate : undefined,
      reason: typeof body.reason === 'string' ? body.reason : undefined,
    });
    return jsonSuccess('Gửi yêu cầu gia hạn thành công.', data, 201);
  } catch (error) {
    return jsonError(error);
  }
}
