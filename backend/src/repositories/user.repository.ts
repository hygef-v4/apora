/**
 * UserRepository - Data Access Layer cho bảng users, device_tokens, password_reset_otps
 *
 * Chỉ chứa SQL thô (qua pg), KHÔNG chứa business logic.
 * Map raw rows -> entity trong types/index.ts.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 1 (UserRepository)
 */

import { query } from '@/lib/db';
import { PasswordResetOtp, User } from '@/types';

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

/** Lưu FCM token khi login. Token đã tồn tại -> kích hoạt lại (bỏ revoked). */
export async function saveDeviceToken(userId: number, token: string): Promise<void> {
  await query(
    `INSERT INTO device_tokens (user_id, token)
     VALUES ($1, $2)
     ON CONFLICT (user_id, token) DO UPDATE SET revoked_at = NULL`,
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

// ==========================================
// password_reset_otps (UC03)
// ==========================================

/**
 * Tạo OTP mới, đồng thời vô hiệu hóa mọi OTP cũ chưa dùng của số này
 * (flow Resend OTP trong SRS - mã cũ hết hiệu lực ngay khi cấp mã mới).
 */
export async function createOtp(phone: string, code: string, expiredAt: Date): Promise<void> {
  await query(
    'UPDATE password_reset_otps SET is_used = TRUE WHERE phone_number = $1 AND is_used = FALSE',
    [phone],
  );
  await query(
    'INSERT INTO password_reset_otps (phone_number, otp_code, expired_at) VALUES ($1, $2, $3)',
    [phone, code, expiredAt],
  );
}

/** Thời điểm cấp OTP gần nhất (kể cả đã dùng) - phục vụ cooldown chống spam SMS. */
export async function findLatestOtpCreatedAt(phone: string): Promise<Date | null> {
  const result = await query(
    `SELECT created_at FROM password_reset_otps
     WHERE phone_number = $1
     ORDER BY created_at DESC
     LIMIT 1`,
    [phone],
  );
  return result.rows[0]?.created_at ?? null;
}

/** OTP đang hiệu lực gần nhất (chưa dùng, chưa hết hạn). */
export async function findActiveOtp(phone: string): Promise<PasswordResetOtp | null> {
  const result = await query(
    `SELECT * FROM password_reset_otps
     WHERE phone_number = $1 AND is_used = FALSE AND expired_at > NOW()
     ORDER BY created_at DESC
     LIMIT 1`,
    [phone],
  );
  return result.rows[0] ?? null;
}

/** Tăng số lần nhập sai; quá 3 lần -> vô hiệu hóa luôn OTP (SRS alternative flow). */
export async function increaseOtpAttempt(id: number): Promise<number> {
  const result = await query(
    `UPDATE password_reset_otps
     SET attempt_count = attempt_count + 1,
         is_used = (attempt_count + 1 >= 3)
     WHERE id = $1
     RETURNING attempt_count`,
    [id],
  );
  return result.rows[0].attempt_count;
}

export async function markOtpUsed(id: number): Promise<void> {
  await query('UPDATE password_reset_otps SET is_used = TRUE WHERE id = $1', [id]);
}
