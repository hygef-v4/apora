/**
 * UserService - Business Logic cho Module 1: Auth & Profile (UC01-UC05)
 *
 * Điều phối UserRepository + Cloudinary + SMS (mock).
 * Mọi message lỗi là tiếng Việt, ném HttpError để route map sang response.
 *
 * Business Rules chính:
 * - BR-01: không tự đăng ký; mật khẩu mặc định phải đổi ở lần login đầu
 * - BR-02: phone_number là username duy nhất
 * - BR-03/BR-06: bcrypt hash
 * - BR-04/BR-05: tài khoản INACTIVE không được login / nhận OTP
 * - BR-07: reset mật khẩu -> vô hiệu hóa mọi JWT (token_version)
 * - BR-08: OTP hết hạn 5 phút, tối đa 3 lần nhập sai
 * - BR-09: mật khẩu >= 8 ký tự, >= 1 hoa, >= 1 số
 * - BR-12: log audit khi đổi số điện thoại
 * - BR-44: lưu FCM token khi login, revoke khi logout
 */

import {
  comparePassword,
  hashPassword,
  signToken,
  validatePasswordComplexity,
} from '@/lib/auth';
import { uploadImage } from '@/lib/cloudinary';
import { HttpError } from '@/lib/middleware';
import * as userRepo from '@/repositories/user.repository';
import { LoginResponseData, PublicUser, User } from '@/types';

const OTP_TTL_MS = 5 * 60 * 1000; // BR-08: 5 phút

// MSG theo SRS
const MSG_LOGIN_FAILED = 'Số điện thoại hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.';
const MSG_INACTIVE = 'Tài khoản của bạn đã bị vô hiệu hóa. Vui lòng liên hệ Ban quản lý.';
const MSG_OTP_INVALID = 'Mã OTP không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu mã mới.';
const MSG_PHONE_EXISTS = 'Số điện thoại đã tồn tại. Vui lòng nhập số khác.';

function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    phoneNumber: user.phone_number,
    fullName: user.full_name,
    avatarUrl: user.avatar_url,
    roles: user.roles,
  };
}

/**
 * Gửi SMS - hiện tại MOCK (log console).
 * Khi tích hợp SMS provider thật chỉ cần thay thân hàm này, không đổi API.
 */
function sendSms(phone: string, content: string): void {
  console.log(`[MOCK SMS] Gửi tới ${phone}: ${content}`);
}

// ==========================================
// UC01: Login
// ==========================================

export async function authenticateUser(
  phone: string,
  password: string,
  fcmToken?: string,
): Promise<LoginResponseData> {
  if (!phone?.trim()) throw new HttpError(400, 'Vui lòng nhập Số điện thoại.');
  if (!password) throw new HttpError(400, 'Vui lòng nhập Mật khẩu.');

  const user = await userRepo.findByPhone(phone.trim());
  if (!user || !(await comparePassword(password, user.password_hash))) {
    throw new HttpError(401, MSG_LOGIN_FAILED);
  }
  if (user.status !== 'ACTIVE') {
    throw new HttpError(403, MSG_INACTIVE); // BR-04
  }

  if (fcmToken) {
    await userRepo.saveDeviceToken(user.id, fcmToken); // BR-44
  }

  const token = signToken({ id: user.id, roles: user.roles, tv: user.token_version });
  return {
    token,
    mustChangePassword: user.must_change_password, // BR-01
    user: toPublicUser(user),
  };
}

// ==========================================
// UC02: Logout
// ==========================================

export async function invalidateSession(userId: number, fcmToken?: string): Promise<void> {
  if (fcmToken) {
    await userRepo.revokeDeviceToken(userId, fcmToken); // BR-44
  }
}

// ==========================================
// UC03: Forgot Password (OTP)
// ==========================================

export async function generateOTP(phone: string): Promise<{ devOtp?: string }> {
  if (!phone?.trim()) throw new HttpError(400, 'Vui lòng nhập Số điện thoại.');

  const user = await userRepo.findByPhone(phone.trim());
  if (!user) {
    throw new HttpError(404, 'Số điện thoại không tồn tại trong hệ thống.');
  }
  if (user.status !== 'ACTIVE') {
    throw new HttpError(403, MSG_INACTIVE); // BR-05
  }

  const code = String(Math.floor(100000 + Math.random() * 900000)); // 6 chữ số
  const expiredAt = new Date(Date.now() + OTP_TTL_MS);
  await userRepo.createOtp(user.phone_number, code, expiredAt);

  sendSms(user.phone_number, `Ma OTP khoi phuc mat khau APORA cua ban la ${code}. Het han sau 5 phut.`);

  // Chỉ trả OTP kèm response ở môi trường dev để demo (production không bao giờ trả)
  return process.env.NODE_ENV !== 'production' ? { devOtp: code } : {};
}

export async function verifyOTPAndReset(
  phone: string,
  otp: string,
  newPassword: string,
): Promise<void> {
  if (!phone?.trim() || !otp?.trim()) {
    throw new HttpError(400, MSG_OTP_INVALID);
  }

  const complexityError = validatePasswordComplexity(newPassword); // BR-09
  if (complexityError) throw new HttpError(400, complexityError);

  const record = await userRepo.findActiveOtp(phone.trim());
  if (!record) {
    throw new HttpError(400, MSG_OTP_INVALID);
  }
  if (record.otp_code !== otp.trim()) {
    await userRepo.increaseOtpAttempt(record.id); // quá 3 lần -> OTP tự vô hiệu
    throw new HttpError(400, MSG_OTP_INVALID);
  }

  const hash = await hashPassword(newPassword); // BR-06
  await userRepo.updatePasswordHash(phone.trim(), hash); // kèm bump token_version (BR-07)
  await userRepo.markOtpUsed(record.id);
}

// ==========================================
// UC04: View Profile
// ==========================================

export async function getUserProfile(userId: number): Promise<PublicUser> {
  const user = await userRepo.findById(userId);
  if (!user) throw new HttpError(404, 'Không tìm thấy người dùng.');
  return toPublicUser(user);
}

// ==========================================
// UC05: Update Profile
// ==========================================

export async function updateUserProfile(
  userId: number,
  fullName: string,
  phone: string,
  avatarBuffer?: Buffer,
): Promise<PublicUser> {
  if (!fullName?.trim()) throw new HttpError(400, 'Trường bắt buộc không được để trống.');
  if (!phone?.trim()) throw new HttpError(400, 'Vui lòng nhập Số điện thoại.');

  const current = await userRepo.findById(userId);
  if (!current) throw new HttpError(404, 'Không tìm thấy người dùng.');

  // BR-02: phone unique
  if (phone.trim() !== current.phone_number) {
    const existed = await userRepo.findByPhone(phone.trim());
    if (existed) throw new HttpError(409, MSG_PHONE_EXISTS);
    // BR-12: audit thay đổi số điện thoại (username đăng nhập)
    console.log(
      `[AUDIT] User #${userId} đổi số điện thoại: ${current.phone_number} -> ${phone.trim()}`,
    );
  }

  let avatarUrl: string | undefined;
  if (avatarBuffer) {
    avatarUrl = await uploadImage(avatarBuffer, 'avatars');
  }

  const updated = await userRepo.updateProfileDetails(userId, fullName.trim(), phone.trim(), avatarUrl);
  return toPublicUser(updated);
}

// ==========================================
// Change Password (flow BR-01 + link từ UC05)
// ==========================================

export async function changePassword(
  userId: number,
  oldPassword: string,
  newPassword: string,
): Promise<{ token: string }> {
  const user = await userRepo.findById(userId);
  if (!user) throw new HttpError(404, 'Không tìm thấy người dùng.');

  if (!(await comparePassword(oldPassword, user.password_hash))) {
    throw new HttpError(401, 'Mật khẩu hiện tại không đúng.');
  }

  const complexityError = validatePasswordComplexity(newPassword); // BR-09
  if (complexityError) throw new HttpError(400, complexityError);

  const hash = await hashPassword(newPassword);
  const newTv = await userRepo.updatePasswordById(userId, hash); // bump token_version (BR-07)

  // Ký token mới để phiên hiện tại không bị đá ra sau khi đổi mật khẩu
  const token = signToken({ id: user.id, roles: user.roles, tv: newTv });
  return { token };
}
