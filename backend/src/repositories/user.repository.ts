/**
 * UserRepository - Data Access Layer cho bảng users, device_tokens
 *
 * Chỉ chứa SQL thô (qua pg), KHÔNG chứa business logic.
 * Map raw rows -> entity trong types/index.ts.
 *
 * Lưu ý: OTP quên mật khẩu (UC03) đi qua Firebase Phone Auth - backend không
 * còn sinh/lưu OTP nên bảng password_reset_otps không được truy cập ở đây.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 1 (UserRepository)
 */

import { query } from '@/lib/db';
import { User } from '@/types';

// ==========================================
// users
// ==========================================

export async function findByPhone(phone: string): Promise<User | null> {
  const result = await query('SELECT * FROM users WHERE phone_number = $1', [phone]);
  return result.rows[0] ?? null;
}

export async function findById(id: number): Promise<User | null> {
  const result = await query('SELECT * FROM users WHERE id = $1', [id]);
  return result.rows[0] ?? null;
}

/**
 * Cập nhật mật khẩu sau khi reset qua OTP (UC03).
 * Đồng thời: tắt must_change_password (BR-01) và tăng token_version
 * để vô hiệu hóa mọi JWT đang hoạt động (BR-07).
 */
export async function updatePasswordHash(phone: string, hash: string): Promise<void> {
  await query(
    `UPDATE users
     SET password_hash = $2, must_change_password = FALSE, token_version = token_version + 1
     WHERE phone_number = $1`,
    [phone, hash],
  );
}

/**
 * Đổi mật khẩu khi đã đăng nhập (UC05 / flow BR-01).
 * Trả về token_version mới để ký lại JWT cho phiên hiện tại.
 */
export async function updatePasswordById(id: number, hash: string): Promise<number> {
  const result = await query(
    `UPDATE users
     SET password_hash = $2, must_change_password = FALSE, token_version = token_version + 1
     WHERE id = $1
     RETURNING token_version`,
    [id, hash],
  );
  return result.rows[0].token_version;
}

export async function updateProfileDetails(
  id: number,
  fullName: string,
  phone: string,
  avatarUrl?: string,
): Promise<User> {
  const result = await query(
    `UPDATE users
     SET full_name = $2, phone_number = $3, avatar_url = COALESCE($4, avatar_url)
     WHERE id = $1
     RETURNING *`,
    [id, fullName, phone, avatarUrl ?? null],
  );
  return result.rows[0];
}

// ==========================================
// device_tokens (BR-44)
// ==========================================

/**
 * Lưu FCM token khi login. Token đã tồn tại -> kích hoạt lại: reset cả
 * revoked_at LẪN status (checkout căn hộ set status = 'REVOKED' - phải trả về
 * ACTIVE, nếu không token vĩnh viễn không nhận noti dù đã login lại).
 */
export async function saveDeviceToken(userId: number, token: string): Promise<void> {
  await query(
    `INSERT INTO device_tokens (user_id, token)
     VALUES ($1, $2)
     ON CONFLICT (user_id, token) DO UPDATE SET revoked_at = NULL, status = 'ACTIVE'`,
    [userId, token],
  );
}

/** Revoke FCM token khi logout (BR-44 - tránh gửi noti cho người dùng sau). */
export async function revokeDeviceToken(userId: number, token: string): Promise<void> {
  await query(
    'UPDATE device_tokens SET revoked_at = NOW() WHERE user_id = $1 AND token = $2',
    [userId, token],
  );
}
