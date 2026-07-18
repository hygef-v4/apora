/**
 * POST /api/auth/forgot-password - UC03 (bước 1): Yêu cầu gửi OTP
 * Body: { phone }
 * OTP hết hạn sau 5 phút (BR-08). Gọi lại endpoint = Resend (mã cũ bị vô hiệu).
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess } from '@/lib/middleware';
import * as userService from '@/services/user.service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const data = await userService.generateOTP(body.phone);
    return jsonSuccess('Mã OTP đã được gửi tới số điện thoại của bạn.', data);
  } catch (error) {
    return jsonError(error);
  }
}
