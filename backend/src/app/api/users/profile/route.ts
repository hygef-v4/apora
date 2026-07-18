/**
 * GET  /api/users/profile - UC04: Xem hồ sơ cá nhân
 * PUT  /api/users/profile - UC05: Cập nhật hồ sơ (multipart/form-data)
 *   Fields: fullName, phone, avatar? (file - mobile đã nén < 500KB theo BR-10),
 *           currentPassword? (bắt buộc khi đổi SĐT - xác nhận chủ tài khoản)
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth, HttpError } from '@/lib/middleware';
import { readImageUpload } from '@/lib/upload';
import * as userService from '@/services/user.service';

export async function GET(req: NextRequest) {
  try {
    const auth = await requireAuth(req);
    const data = await userService.getUserProfile(auth.id);
    return jsonSuccess('Lấy thông tin hồ sơ thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}

export async function PUT(req: NextRequest) {
  try {
    const auth = await requireAuth(req);

    const form = await req.formData().catch(() => {
      throw new HttpError(400, 'Dữ liệu gửi lên không hợp lệ (yêu cầu multipart/form-data).');
    });

    const fullName = String(form.get('fullName') ?? '');
    const phone = String(form.get('phone') ?? '');
    const currentPasswordRaw = form.get('currentPassword');
    const currentPassword =
      typeof currentPasswordRaw === 'string' && currentPasswordRaw.length > 0
        ? currentPasswordRaw
        : undefined;
    const avatarBuffer = await readImageUpload(form, 'avatar');

    const data = await userService.updateUserProfile(
      auth.id,
      fullName,
      phone,
      avatarBuffer,
      currentPassword,
    );
    return jsonSuccess('Cập nhật hồ sơ thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
