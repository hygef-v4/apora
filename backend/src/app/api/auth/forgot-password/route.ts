/**
 * POST /api/auth/forgot-password - UC03 (bước 1): Kiểm tra tài khoản trước khi
 * mobile nhờ Firebase Phone Auth gửi SMS OTP.
 * Body: { phone }
 * Backend KHÔNG sinh OTP - Firebase đảm nhiệm gửi mã/hết hạn/đếm nhập sai (BR-08).
 * 404 nếu SĐT không có tài khoản, 403 nếu tài khoản INACTIVE (BR-05).
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess } from '@/lib/middleware';
import * as userService from '@/services/user.service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    await userService.ensureAccountForPasswordReset(body.phone);
    return jsonSuccess('Tài khoản hợp lệ. Đang gửi mã OTP tới số điện thoại của bạn.');
  } catch (error) {
    return jsonError(error);
  }
}
