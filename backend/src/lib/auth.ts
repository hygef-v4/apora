/**
 * Auth Utilities - JWT & Bcrypt
 *
 * Xử lý:
 * - Băm mật khẩu bằng bcrypt (khi Admin tạo tài khoản)
 * - So sánh mật khẩu khi đăng nhập
 * - Ký (sign) và xác thực (verify) JWT Token
 *
 * ⚠️ LƯU Ý QUAN TRỌNG:
 * - Password PHẢI được hash bằng bcrypt trước khi lưu DB
 * - JWT Token chứa { id, role } của user
 * - KHÔNG BAO GIỜ lưu plain-text password
 *
 * @see PRM393 - Mục 3: Luồng hoạt động Custom Auth (JWT)
 */

// TODO: Implement
// import bcrypt from 'bcrypt';
// import jwt from 'jsonwebtoken';
//
// const JWT_SECRET = process.env.JWT_SECRET!;
// const SALT_ROUNDS = 10;
//
// export async function hashPassword(password: string): Promise<string> {
//   return bcrypt.hash(password, SALT_ROUNDS);
// }
//
// export async function comparePassword(password: string, hash: string): Promise<boolean> {
//   return bcrypt.compare(password, hash);
// }
//
// export function signToken(payload: { id: string; role: string }): string {
//   return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
// }
//
// export function verifyToken(token: string) {
//   return jwt.verify(token, JWT_SECRET);
// }

export {};
