/**
 * Auth Utilities - JWT & Bcrypt
 *
 * - Băm/so sánh mật khẩu bằng bcrypt (BR-03, BR-06)
 * - Ký (sign) và xác thực (verify) JWT Token
 * - Validate độ phức tạp mật khẩu (BR-09)
 *
 * ⚠️ LƯU Ý:
 * - KHÔNG BAO GIỜ lưu plain-text password
 * - JWT payload: { id, roles, tv } - tv dùng cho BR-07 (vô hiệu hóa token cũ)
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 1
 */

import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { JwtPayload } from '@/types';

const SALT_ROUNDS = 10;
const TOKEN_EXPIRES_IN = '7d';

function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('Thiếu biến môi trường JWT_SECRET');
  }
  return secret;
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

export async function comparePassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export function signToken(payload: Pick<JwtPayload, 'id' | 'roles' | 'tv'>): string {
  return jwt.sign(payload, getJwtSecret(), { expiresIn: TOKEN_EXPIRES_IN });
}

/** Trả về payload nếu hợp lệ, ném lỗi nếu token sai/hết hạn. */
export function verifyToken(token: string): JwtPayload {
  return jwt.verify(token, getJwtSecret()) as JwtPayload;
}

/**
 * BR-02: SĐT là username - phải đúng định dạng di động VN (10 chữ số, bắt đầu bằng 0).
 * @returns null nếu hợp lệ, ngược lại trả message lỗi tiếng Việt.
 */
export function validatePhoneNumber(phone: string): string | null {
  if (!/^0\d{9}$/.test(phone)) {
    return 'Số điện thoại không hợp lệ. Vui lòng nhập 10 chữ số bắt đầu bằng 0.';
  }
  return null;
}

/**
 * BR-09: Mật khẩu tối thiểu 8 ký tự, ít nhất 1 chữ hoa và 1 chữ số.
 * @returns null nếu hợp lệ, ngược lại trả message lỗi tiếng Việt.
 */
export function validatePasswordComplexity(password: string): string | null {
  if (!password || password.length < 8) {
    return 'Mật khẩu phải có ít nhất 8 ký tự.';
  }
  if (!/[A-Z]/.test(password)) {
    return 'Mật khẩu phải chứa ít nhất 1 chữ cái viết hoa.';
  }
  if (!/[0-9]/.test(password)) {
    return 'Mật khẩu phải chứa ít nhất 1 chữ số.';
  }
  return null;
}
