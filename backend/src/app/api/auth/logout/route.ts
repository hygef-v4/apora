/**
 * POST /api/auth/logout - UC02: Logout
 * Header: Authorization: Bearer <token>
 * Body: { fcmToken? } - revoke FCM token của thiết bị này (BR-44)
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as userService from '@/services/user.service';

export async function POST(req: NextRequest) {
  try {
    const auth = await requireAuth(req);
    const body = await req.json().catch(() => ({}));
    await userService.invalidateSession(auth.id, body.fcmToken);
    return jsonSuccess('Đăng xuất thành công.');
  } catch (error) {
    return jsonError(error);
  }
}
