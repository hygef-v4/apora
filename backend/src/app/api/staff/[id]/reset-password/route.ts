/**
 * PUT /api/staff/:id/reset-password - Manager đặt lại mật khẩu cho nhân viên
 * (UC39 - flow riêng do Manager khởi tạo, khác UC03 tự phục vụ qua OTP)
 * Body: { newPassword }
 * Sau khi reset: staff bắt buộc đổi mật khẩu ở lần đăng nhập kế (BR-01),
 * mọi phiên đăng nhập hiện tại bị vô hiệu (BR-07).
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

    const body = await req.json();
    await staffService.resetStaffPasswordByManager(auth.id, staffId, body.newPassword);
    return jsonSuccess('Đặt lại mật khẩu thành công. Nhân viên sẽ phải đổi mật khẩu khi đăng nhập.');
  } catch (error) {
    return jsonError(error);
  }
}
