/**
 * PUT /api/staff/:id/status - UC40: Vô hiệu hóa tài khoản nhân viên
 * Body: { reason? } (tối đa 250 ký tự - vào audit log)
 * BR-50: bị chặn (409) khi nhân viên còn task ASSIGNED/IN_PROGRESS.
 * Chỉ MANAGER / LANDLORD.
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as staffService from '@/services/staff.service';

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const auth = await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { id } = await params;
    const staffId = Number(id);
    if (!Number.isInteger(staffId) || staffId <= 0) {
      throw new HttpError(400, 'Mã nhân viên không hợp lệ.');
    }

    const body = await req.json().catch(() => ({}));
    await staffService.disableStaffAccount(auth.id, staffId, body.reason);
    return jsonSuccess('Đã vô hiệu hóa tài khoản nhân viên.');
  } catch (error) {
    return jsonError(error);
  }
}
