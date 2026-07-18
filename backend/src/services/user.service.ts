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

import { createHash, randomInt } from 'crypto';

import {
  comparePassword,
  hashPassword,
  signToken,
  validatePasswordComplexity,
  validatePhoneNumber,
} from '@/lib/auth';
import { uploadImage } from '@/lib/cloudinary';
import { HttpError } from '@/lib/middleware';
import * as auditRepo from '@/repositories/audit.repository';
import * as userRepo from '@/repositories/user.repository';
import { LoginResponseData, PublicUser, User } from '@/types';

const OTP_TTL_MS = 5 * 60 * 1000; // BR-08: 5 phút
const OTP_RESEND_COOLDOWN_MS = 60 * 1000; // chống spam SMS: tối thiểu 60s giữa 2 lần gửi

// Chống brute-force đăng nhập: khóa tạm SĐT sau 5 lần sai trong 15 phút
const LOGIN_MAX_FAILURES = 5;
const LOGIN_LOCK_WINDOW_MS = 15 * 60 * 1000;

// Khớp VARCHAR(100) của users.full_name - trả 400 rõ ràng thay vì 500 (lỗi 22001)
const FULL_NAME_MAX = 100;

// MSG theo SRS
const MSG_LOGIN_FAILED = 'Số điện thoại hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.';
const MSG_INACTIVE = 'Tài khoản của bạn đã bị vô hiệu hóa. Vui lòng liên hệ Ban quản lý.';
const MSG_OTP_INVALID = 'Mã OTP không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu mã mới.';
const MSG_PHONE_EXISTS = 'Số điện thoại đã tồn tại. Vui lòng nhập số khác.';
const MSG_SAME_PASSWORD = 'Mật khẩu mới không được trùng mật khẩu hiện tại.';

/** SHA-256 hex - dùng để lưu/đối chiếu OTP, không bao giờ lưu OTP plaintext. */
function hashOtp(code: string): string {
  return createHash('sha256').update(code).digest('hex');
}

/**
 * Bộ đếm đăng nhập sai theo SĐT (in-memory).
 * Lưu ý: mỗi instance serverless có bộ đếm riêng (cold start là reset) - đủ tốt
 * cho phạm vi đồ án; production nên chuyển sang Redis/DB để đếm tập trung.
 */
const loginFailures = new Map<string, { count: number; firstAt: number }>();

function assertLoginNotLocked(phone: string): void {
  const entry = loginFailures.get(phone);
  if (!entry) return;
  if (Date.now() - entry.firstAt > LOGIN_LOCK_WINDOW_MS) {
    loginFailures.delete(phone);
    return;
  }
  if (entry.count >= LOGIN_MAX_FAILURES) {
    const waitMinutes = Math.ceil(
      (LOGIN_LOCK_WINDOW_MS - (Date.now() - entry.firstAt)) / 60000,
    );
    throw new HttpError(
      429,
      `Bạn đã nhập sai quá ${LOGIN_MAX_FAILURES} lần. Vui lòng thử lại sau ${waitMinutes} phút.`,
    );
  }
}

function recordLoginFailure(phone: string): void {
  const now = Date.now();
  const entry = loginFailures.get(phone);
  if (!entry || now - entry.firstAt > LOGIN_LOCK_WINDOW_MS) {
    loginFailures.set(phone, { count: 1, firstAt: now });
  } else {
    entry.count += 1;
  }
}

/**
 * Hash bcrypt "mồi" để so sánh giả khi SĐT không tồn tại - giữ thời gian phản
 * hồi tương đương ca có tài khoản, tránh dò SĐT đã đăng ký qua timing.
 */
const dummyHashPromise = hashPassword('apora-dummy-timing-password');

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

  const trimmedPhone = phone.trim();
  assertLoginNotLocked(trimmedPhone); // chống brute-force

  const user = await userRepo.findByPhone(trimmedPhone);
  if (!user) {
    // So sánh "mồi" để thời gian phản hồi không tiết lộ SĐT nào có tài khoản
    await comparePassword(password, await dummyHashPromise);
    recordLoginFailure(trimmedPhone);
    throw new HttpError(401, MSG_LOGIN_FAILED);
  }
  if (!(await comparePassword(password, user.password_hash))) {
    recordLoginFailure(trimmedPhone);
    throw new HttpError(401, MSG_LOGIN_FAILED);
  }
  if (user.status !== 'ACTIVE') {
    throw new HttpError(403, MSG_INACTIVE); // BR-04
  }
  loginFailures.delete(trimmedPhone); // đăng nhập thành công -> reset bộ đếm

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
    // Trade-off có chủ đích: message này cho phép dò SĐT đã đăng ký (user
    // enumeration), nhưng SRS UC03 yêu cầu báo rõ để cư dân gõ nhầm số biết
    // đường sửa. Rủi ro được giảm nhẹ bằng cooldown 60s/SĐT ở dưới.
    throw new HttpError(404, 'Số điện thoại không tồn tại trong hệ thống.');
  }
  if (user.status !== 'ACTIVE') {
    throw new HttpError(403, MSG_INACTIVE); // BR-05
  }

  // Cooldown chống spam: tối thiểu 60s giữa 2 lần yêu cầu OTP cho cùng SĐT
  const lastCreatedAt = await userRepo.findLatestOtpCreatedAt(user.phone_number);
  if (lastCreatedAt && Date.now() - lastCreatedAt.getTime() < OTP_RESEND_COOLDOWN_MS) {
    const waitSeconds = Math.ceil(
      (OTP_RESEND_COOLDOWN_MS - (Date.now() - lastCreatedAt.getTime())) / 1000,
    );
    throw new HttpError(429, `Vui lòng đợi ${waitSeconds} giây trước khi yêu cầu mã mới.`);
  }

  // randomInt của crypto (CSPRNG) - Math.random() đoán được, không dùng cho OTP
  const code = String(randomInt(100000, 1000000)); // 6 chữ số
  const expiredAt = new Date(Date.now() + OTP_TTL_MS);
  await userRepo.createOtp(user.phone_number, hashOtp(code), expiredAt);

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

  // BR-05: re-check tại thời điểm reset - tài khoản có thể bị vô hiệu hóa
  // trong khoảng 5 phút từ lúc xin OTP tới lúc xác nhận.
  const user = await userRepo.findByPhone(phone.trim());
  if (!user) throw new HttpError(400, MSG_OTP_INVALID);
  if (user.status !== 'ACTIVE') throw new HttpError(403, MSG_INACTIVE);

  const record = await userRepo.findActiveOtp(phone.trim());
  if (!record) {
    throw new HttpError(400, MSG_OTP_INVALID);
  }
  // DB chỉ lưu SHA-256 của OTP -> đối chiếu bằng hash
  if (record.otp_code !== hashOtp(otp.trim())) {
    await userRepo.increaseOtpAttempt(record.id); // quá 3 lần -> OTP tự vô hiệu
    throw new HttpError(400, MSG_OTP_INVALID);
  }

  // Mật khẩu mới không được trùng mật khẩu hiện tại
  if (await comparePassword(newPassword, user.password_hash)) {
    throw new HttpError(400, MSG_SAME_PASSWORD);
  }

  // "Tiêu" OTP TRƯỚC khi đổi mật khẩu - atomic: 2 request đồng thời cùng mã
  // thì chỉ 1 request thắng, request kia nhận lỗi OTP không hợp lệ.
  const consumed = await userRepo.markOtpUsed(record.id);
  if (!consumed) {
    throw new HttpError(400, MSG_OTP_INVALID);
  }

  const hash = await hashPassword(newPassword); // BR-06
  await userRepo.updatePasswordHash(phone.trim(), hash); // kèm bump token_version (BR-07)
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
  currentPassword?: string,
): Promise<PublicUser & { avatarUploadFailed?: true }> {
  if (!fullName?.trim()) throw new HttpError(400, 'Trường bắt buộc không được để trống.');
  if (!phone?.trim()) throw new HttpError(400, 'Vui lòng nhập Số điện thoại.');
  if (fullName.trim().length > FULL_NAME_MAX) {
    throw new HttpError(400, `Họ tên tối đa ${FULL_NAME_MAX} ký tự.`);
  }

  const phoneError = validatePhoneNumber(phone.trim()); // BR-02
  if (phoneError) throw new HttpError(400, phoneError);

  const current = await userRepo.findById(userId);
  if (!current) throw new HttpError(404, 'Không tìm thấy người dùng.');

  // BR-02: phone unique
  const phoneChanged = phone.trim() !== current.phone_number;
  if (phoneChanged) {
    // Đổi SĐT = đổi username đăng nhập + nơi nhận OTP khôi phục -> yêu cầu
    // xác nhận mật khẩu hiện tại, kẻ chiếm được phiên không chiếm luôn tài khoản.
    if (!currentPassword) {
      throw new HttpError(400, 'Vui lòng nhập mật khẩu hiện tại để đổi số điện thoại.');
    }
    if (!(await comparePassword(currentPassword, current.password_hash))) {
      throw new HttpError(400, 'Mật khẩu hiện tại không đúng.');
    }
    const existed = await userRepo.findByPhone(phone.trim());
    if (existed) throw new HttpError(409, MSG_PHONE_EXISTS);
  }

  // Upload avatar lỗi -> vẫn lưu các field text, giữ avatar cũ, nhưng trả cờ
  // avatarUploadFailed để UI báo người dùng (đồng bộ hành vi với UC39 - AT3)
  let avatarUrl: string | undefined;
  let avatarUploadFailed = false;
  if (avatarBuffer) {
    try {
      avatarUrl = await uploadImage(avatarBuffer, 'avatars');
    } catch (error) {
      avatarUploadFailed = true;
      console.error('[UserService] Upload avatar thất bại, giữ avatar cũ:', error);
    }
  }

  const updated = await userRepo.updateProfileDetails(userId, fullName.trim(), phone.trim(), avatarUrl);

  // BR-12: audit thay đổi số điện thoại (username đăng nhập) - ghi sau khi update thành công
  if (phoneChanged) {
    await auditRepo.insertAuditLog(
      userId,
      userId,
      'PROFILE_PHONE_CHANGE',
      { phone: current.phone_number },
      { phone: updated.phone_number },
    );
  }

  return {
    ...toPublicUser(updated),
    ...(avatarUploadFailed ? { avatarUploadFailed: true as const } : {}),
  };
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

  // 400 (không phải 401) - 401 dành riêng cho "phiên hết hiệu lực"
  // để mobile auto-logout không đá user ra khi gõ nhầm mật khẩu cũ
  if (!(await comparePassword(oldPassword, user.password_hash))) {
    throw new HttpError(400, 'Mật khẩu hiện tại không đúng.');
  }

  const complexityError = validatePasswordComplexity(newPassword); // BR-09
  if (complexityError) throw new HttpError(400, complexityError);

  // Mật khẩu mới không được trùng mật khẩu hiện tại (đặc biệt quan trọng với
  // flow BR-01: đổi "mật khẩu mặc định" thành chính nó là vô nghĩa)
  if (await comparePassword(newPassword, user.password_hash)) {
    throw new HttpError(400, MSG_SAME_PASSWORD);
  }

  const hash = await hashPassword(newPassword);
  const newTv = await userRepo.updatePasswordById(userId, hash); // bump token_version (BR-07)

  // Ký token mới để phiên hiện tại không bị đá ra sau khi đổi mật khẩu
  const token = signToken({ id: user.id, roles: user.roles, tv: newTv });
  return { token };
}
