/**
 * POST /api/auth/login - UC01: Role-based Login
 * Body: { phone, password, fcmToken? }
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess } from '@/lib/middleware';
import * as userService from '@/services/user.service';
import { LoginRequest } from '@/types';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as LoginRequest;
    const data = await userService.authenticateUser(body.phone, body.password, body.fcmToken);
    return jsonSuccess('Đăng nhập thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
