/**
 * POST /api/users/change-password - Đổi mật khẩu khi đã đăng nhập
 * Phục vụ BR-01 (bắt buộc đổi mật khẩu mặc định ở lần login đầu) + link từ UC05.
 * Body: { oldPassword, newPassword }
 * Trả về JWT mới (token cũ bị vô hiệu do token_version tăng - BR-07).
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as userService from '@/services/user.service';

export async function POST(req: NextRequest) {
  try {
    // BR-01: endpoint duy nhất (cùng logout) mở cho user chưa đổi mật khẩu mặc định
    const auth = await requireAuth(req, undefined, { allowPendingPasswordChange: true });
    const body = await req.json();
    const data = await userService.changePassword(auth.id, body.oldPassword, body.newPassword);
    return jsonSuccess('Đổi mật khẩu thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
