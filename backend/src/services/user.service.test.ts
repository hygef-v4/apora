/**
 * Unit test UserService (Module 1: UC01-UC05) - mock repository, không cần DB.
 * Phủ các Business Rule chính: BR-01/04 (login), BR-07/08/09 (OTP Firebase +
 * mật khẩu), BR-12 (audit đổi SĐT), chống brute-force login.
 */

import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import { hashPassword } from '@/lib/auth';
import { HttpError } from '@/lib/middleware';
import * as auditRepo from '@/repositories/audit.repository';
import * as userRepo from '@/repositories/user.repository';
import { User } from '@/types';
import * as userService from '@/services/user.service';

vi.mock('@/repositories/user.repository');
vi.mock('@/repositories/audit.repository');
vi.mock('@/lib/cloudinary', () => ({
  uploadImage: vi.fn(),
}));
// UC03: mock Firebase Admin - không gọi Firebase thật trong unit test
vi.mock('@/services/firebase.service', () => ({
  verifyPhoneIdToken: vi.fn(),
}));

import { uploadImage } from '@/lib/cloudinary';
import { verifyPhoneIdToken } from '@/services/firebase.service';

const PASSWORD = 'Apora@123';
let passwordHash: string;

function makeUser(overrides: Partial<User> = {}): User {
  return {
    id: 1,
    phone_number: '0900000001',
    password_hash: passwordHash,
    full_name: 'Nguyễn Văn A',
    avatar_url: null,
    roles: ['RESIDENT'],
    status: 'ACTIVE',
    must_change_password: false,
    token_version: 0,
    created_at: new Date(),
    ...overrides,
  };
}

beforeAll(async () => {
  process.env.JWT_SECRET = 'test-secret';
  passwordHash = await hashPassword(PASSWORD);
});

beforeEach(() => {
  vi.clearAllMocks();
});

describe('UC01: authenticateUser', () => {
  it('đăng nhập thành công trả token + mustChangePassword + public user', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(
      makeUser({ must_change_password: true }),
    );

    const result = await userService.authenticateUser('0900000001', PASSWORD);

    expect(result.token).toBeTruthy();
    expect(result.mustChangePassword).toBe(true); // BR-01
    expect(result.user.phoneNumber).toBe('0900000001');
    // Không bao giờ lộ password_hash
    expect(result.user).not.toHaveProperty('password_hash');
  });

  it('sai mật khẩu -> 401 MSG02', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeUser());

    await expect(
      userService.authenticateUser('0900000001', 'SaiMatKhau1'),
    ).rejects.toMatchObject({ status: 401 });
  });

  it('tài khoản INACTIVE -> 403 (BR-04)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(
      makeUser({ status: 'INACTIVE' }),
    );

    await expect(
      userService.authenticateUser('0900000001', PASSWORD),
    ).rejects.toMatchObject({ status: 403 });
  });

  it('SĐT không tồn tại -> 401 cùng message với sai mật khẩu (chống dò SĐT)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(null);

    await expect(
      userService.authenticateUser('0999999999', PASSWORD),
    ).rejects.toMatchObject({
      status: 401,
      message: 'Số điện thoại hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.',
    });
  });

  it('lưu FCM token khi login kèm fcmToken (BR-44)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeUser());

    await userService.authenticateUser('0900000001', PASSWORD, 'fcm-abc');

    expect(userRepo.saveDeviceToken).toHaveBeenCalledWith(1, 'fcm-abc');
  });

  it('khóa tạm sau 5 lần sai liên tiếp -> 429 (chống brute-force)', async () => {
    // Dùng SĐT riêng - bộ đếm brute-force là state module-level
    const phone = '0911111111';
    vi.mocked(userRepo.findByPhone).mockResolvedValue(
      makeUser({ phone_number: phone }),
    );

    for (let i = 0; i < 5; i++) {
      await expect(
        userService.authenticateUser(phone, 'SaiMatKhau1'),
      ).rejects.toMatchObject({ status: 401 });
    }
    // Lần 6: bị khóa tạm, kể cả khi nhập ĐÚNG mật khẩu
    await expect(
      userService.authenticateUser(phone, PASSWORD),
    ).rejects.toMatchObject({ status: 429 });
  });
});

describe('UC03: ensureAccountForPasswordReset / resetPasswordWithFirebase', () => {
  const ID_TOKEN = 'firebase-id-token';

  it('SĐT không có tài khoản -> 404 (không tốn SMS Firebase)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(null);

    await expect(
      userService.ensureAccountForPasswordReset('0999999999'),
    ).rejects.toMatchObject({ status: 404 });
  });

  it('tài khoản INACTIVE không được nhận OTP (BR-05)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(
      makeUser({ status: 'INACTIVE' }),
    );

    await expect(
      userService.ensureAccountForPasswordReset('0900000001'),
    ).rejects.toMatchObject({ status: 403 });
  });

  it('tài khoản ACTIVE -> pass (mobile được phép nhờ Firebase gửi SMS)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeUser());

    await expect(
      userService.ensureAccountForPasswordReset('0900000001'),
    ).resolves.toBeUndefined();
  });

  it('token Firebase giả/hết hạn -> 400, KHÔNG đổi mật khẩu', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeUser());
    vi.mocked(verifyPhoneIdToken).mockRejectedValue(new Error('id-token-expired'));

    await expect(
      userService.resetPasswordWithFirebase('0900000001', ID_TOKEN, 'MatKhauMoi1'),
    ).rejects.toMatchObject({ status: 400 });
    expect(userRepo.updatePasswordHash).not.toHaveBeenCalled();
  });

  it('SĐT trong token khác tài khoản cần reset -> 400 (chặn chiếm tài khoản khác)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeUser());
    vi.mocked(verifyPhoneIdToken).mockResolvedValue('+84888888888'); // số khác

    await expect(
      userService.resetPasswordWithFirebase('0900000001', ID_TOKEN, 'MatKhauMoi1'),
    ).rejects.toMatchObject({ status: 400 });
    expect(userRepo.updatePasswordHash).not.toHaveBeenCalled();
  });

  it('token hợp lệ + SĐT khớp (E.164 +84 <-> 0) -> đổi mật khẩu (BR-07)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeUser());
    // user.phone_number = '0900000001' <-> token '+84900000001'
    vi.mocked(verifyPhoneIdToken).mockResolvedValue('+84900000001');

    await userService.resetPasswordWithFirebase(
      '0900000001',
      ID_TOKEN,
      'MatKhauMoi1',
    );

    expect(userRepo.updatePasswordHash).toHaveBeenCalled();
  });

  it('tài khoản bị vô hiệu hóa giữa chừng -> 403 (BR-05 re-check)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(
      makeUser({ status: 'INACTIVE' }),
    );

    await expect(
      userService.resetPasswordWithFirebase('0900000001', ID_TOKEN, 'MatKhauMoi1'),
    ).rejects.toMatchObject({ status: 403 });
  });

  it('mật khẩu mới trùng mật khẩu hiện tại -> 400', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeUser());
    vi.mocked(verifyPhoneIdToken).mockResolvedValue('+84900000001');

    await expect(
      userService.resetPasswordWithFirebase('0900000001', ID_TOKEN, PASSWORD),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('mật khẩu mới yếu -> 400 (BR-09)', async () => {
    await expect(
      userService.resetPasswordWithFirebase('0900000001', ID_TOKEN, 'yeu'),
    ).rejects.toMatchObject({ status: 400 });
  });
});

describe('UC05: updateUserProfile', () => {
  it('đổi SĐT thiếu mật khẩu hiện tại -> 400', async () => {
    vi.mocked(userRepo.findById).mockResolvedValue(makeUser());

    await expect(
      userService.updateUserProfile(1, 'Nguyễn Văn A', '0988888888'),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('đổi SĐT sai mật khẩu hiện tại -> 400', async () => {
    vi.mocked(userRepo.findById).mockResolvedValue(makeUser());

    await expect(
      userService.updateUserProfile(
        1,
        'Nguyễn Văn A',
        '0988888888',
        undefined,
        'SaiMatKhau1',
      ),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('đổi SĐT đúng mật khẩu -> lưu + audit PROFILE_PHONE_CHANGE (BR-12)', async () => {
    vi.mocked(userRepo.findById).mockResolvedValue(makeUser());
    vi.mocked(userRepo.findByPhone).mockResolvedValue(null);
    vi.mocked(userRepo.updateProfileDetails).mockResolvedValue(
      makeUser({ phone_number: '0988888888' }),
    );

    const result = await userService.updateUserProfile(
      1,
      'Nguyễn Văn A',
      '0988888888',
      undefined,
      PASSWORD,
    );

    expect(result.phoneNumber).toBe('0988888888');
    expect(auditRepo.insertAuditLog).toHaveBeenCalledWith(
      1,
      1,
      'PROFILE_PHONE_CHANGE',
      { phone: '0900000001' },
      { phone: '0988888888' },
    );
  });

  it('SĐT mới đã tồn tại -> 409 (BR-02)', async () => {
    vi.mocked(userRepo.findById).mockResolvedValue(makeUser());
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeUser({ id: 2 }));

    await expect(
      userService.updateUserProfile(
        1,
        'Nguyễn Văn A',
        '0988888888',
        undefined,
        PASSWORD,
      ),
    ).rejects.toMatchObject({ status: 409 });
  });

  it('upload avatar lỗi -> vẫn lưu text, trả cờ avatarUploadFailed (AT3)', async () => {
    vi.mocked(userRepo.findById).mockResolvedValue(makeUser());
    vi.mocked(uploadImage).mockRejectedValue(new Error('Cloudinary lỗi'));
    vi.mocked(userRepo.updateProfileDetails).mockResolvedValue(makeUser());

    const result = await userService.updateUserProfile(
      1,
      'Nguyễn Văn A',
      '0900000001',
      Buffer.from('anh'),
    );

    expect(result.avatarUploadFailed).toBe(true);
    expect(userRepo.updateProfileDetails).toHaveBeenCalledWith(
      1,
      'Nguyễn Văn A',
      '0900000001',
      undefined,
    );
  });

  it('họ tên quá 100 ký tự -> 400 (khớp VARCHAR(100))', async () => {
    await expect(
      userService.updateUserProfile(1, 'A'.repeat(101), '0900000001'),
    ).rejects.toMatchObject({ status: 400 });
  });
});

describe('changePassword (flow BR-01)', () => {
  it('mật khẩu cũ sai -> 400 (không phải 401 để mobile không auto-logout)', async () => {
    vi.mocked(userRepo.findById).mockResolvedValue(makeUser());

    await expect(
      userService.changePassword(1, 'SaiMatKhau1', 'MatKhauMoi1'),
    ).rejects.toBeInstanceOf(HttpError);
    await expect(
      userService.changePassword(1, 'SaiMatKhau1', 'MatKhauMoi1'),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('mật khẩu mới trùng mật khẩu cũ -> 400', async () => {
    vi.mocked(userRepo.findById).mockResolvedValue(makeUser());

    await expect(
      userService.changePassword(1, PASSWORD, PASSWORD),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('đổi thành công -> trả JWT mới ký với token_version mới (BR-07)', async () => {
    vi.mocked(userRepo.findById).mockResolvedValue(makeUser());
    vi.mocked(userRepo.updatePasswordById).mockResolvedValue(1);

    const { token } = await userService.changePassword(1, PASSWORD, 'MatKhauMoi1');

    expect(token).toBeTruthy();
    expect(userRepo.updatePasswordById).toHaveBeenCalled();
  });
});
