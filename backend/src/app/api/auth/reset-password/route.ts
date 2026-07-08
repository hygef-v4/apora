/**
 * POST /api/auth/reset-password - UC03 (bước 2): Xác thực OTP + đặt mật khẩu mới
 * Body: { phone, otp, newPassword }
 * Sau khi reset, mọi JWT cũ của user bị vô hiệu hóa (BR-07).
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess } from '@/lib/middleware';
import * as userService from '@/services/user.service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    await userService.verifyOTPAndReset(body.phone, body.otp, body.newPassword);
    return jsonSuccess('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
  } catch (error) {
    return jsonError(error);
  }
}
