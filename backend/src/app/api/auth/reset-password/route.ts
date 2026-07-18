/**
 * POST /api/auth/reset-password - UC03 (bước 2): Đặt mật khẩu mới sau khi
 * mobile đã xác thực OTP với Firebase Phone Auth.
 * Body: { phone, firebaseIdToken, newPassword }
 * Backend verify Firebase ID token + đối chiếu SĐT trong token với tài khoản.
 * Sau khi reset, mọi JWT cũ của user bị vô hiệu hóa (BR-07).
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess } from '@/lib/middleware';
import * as userService from '@/services/user.service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    await userService.resetPasswordWithFirebase(
      body.phone,
      body.firebaseIdToken,
      body.newPassword,
    );
    return jsonSuccess('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
  } catch (error) {
    return jsonError(error);
  }
}
