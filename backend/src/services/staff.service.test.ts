/**
 * Unit test StaffService (Module 8: UC36-UC40) - mock repository, không cần DB.
 * Phủ BR chính: BR-02 (phone unique), BR-09 (mật khẩu), BR-50 (chặn deactivate
 * khi còn task mở), BR-04 (audit log), BR-49/59 (soft-delete).
 */

import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import { hashPassword } from '@/lib/auth';
import * as auditRepo from '@/repositories/audit.repository';
import * as staffRepo from '@/repositories/staff.repository';
import * as userRepo from '@/repositories/user.repository';
import { User } from '@/types';
import * as staffService from '@/services/staff.service';

vi.mock('@/repositories/staff.repository');
vi.mock('@/repositories/user.repository');
vi.mock('@/repositories/audit.repository');
vi.mock('@/lib/cloudinary', () => ({
  uploadImage: vi.fn(),
}));
// Transaction giả: chạy thẳng callback với client rỗng - service vẫn phải
// truyền client xuống repository (assert bên dưới).
vi.mock('@/lib/db', () => ({
  query: vi.fn(),
  withTransaction: vi.fn(async (fn: (client: unknown) => Promise<unknown>) =>
    fn(FAKE_CLIENT),
  ),
}));

const FAKE_CLIENT = { query: vi.fn() };

let passwordHash: string;

function makeStaff(overrides: Partial<User> = {}): User {
  return {
    id: 4,
    phone_number: '0900000004',
    password_hash: passwordHash,
    full_name: 'Trần Văn Kỹ Thuật',
    avatar_url: null,
    roles: ['TECHNICIAN'],
    status: 'ACTIVE',
    must_change_password: false,
    token_version: 0,
    created_at: new Date(),
    ...overrides,
  };
}

beforeAll(async () => {
  passwordHash = await hashPassword('Apora@123');
});

beforeEach(() => {
  vi.clearAllMocks();
});

describe('UC38: registerStaffAccount', () => {
  const validInput = {
    fullName: 'Phạm Văn Lao Công',
    phone: '0900000006',
    password: 'Apora@123',
    role: 'JANITOR',
  };

  it('role không thuộc nhóm staff -> 400', async () => {
    await expect(
      staffService.registerStaffAccount(2, { ...validInput, role: 'MANAGER' }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('SĐT đã tồn tại -> 409 (BR-02)', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(makeStaff());

    await expect(
      staffService.registerStaffAccount(2, validInput),
    ).rejects.toMatchObject({ status: 409 });
  });

  it('mật khẩu yếu -> 400 (BR-09)', async () => {
    await expect(
      staffService.registerStaffAccount(2, { ...validInput, password: 'yeu' }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('họ tên quá 100 ký tự -> 400', async () => {
    await expect(
      staffService.registerStaffAccount(2, {
        ...validInput,
        fullName: 'A'.repeat(101),
      }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('tạo thành công: saveStaff + audit STAFF_CREATE trong cùng transaction', async () => {
    vi.mocked(userRepo.findByPhone).mockResolvedValue(null);
    vi.mocked(staffRepo.saveStaff).mockResolvedValue(
      makeStaff({ id: 6, phone_number: '0900000006', roles: ['JANITOR'] }),
    );

    const result = await staffService.registerStaffAccount(2, validInput);

    expect(result.id).toBe(6);
    // Cả 2 lệnh ghi đều nhận client của transaction (BR-04: có vết mới được tạo)
    expect(vi.mocked(staffRepo.saveStaff).mock.calls[0][4]).toBe(FAKE_CLIENT);
    const auditCall = vi.mocked(auditRepo.insertAuditLog).mock.calls[0];
    expect(auditCall[2]).toBe('STAFF_CREATE');
    expect(auditCall[6]).toBe(FAKE_CLIENT);
  });
});

describe('UC37: getStaffProfile', () => {
  it('canDeactivate = false khi còn task mở (BR-50)', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(makeStaff());
    vi.mocked(staffRepo.findOpenTasksByStaffId).mockResolvedValue([
      {
        id: 1,
        ticket_id: 1,
        assigned_to: 4,
        assigned_by: 2,
        title: 'Sửa điện',
        description: null,
        progress_notes: null,
        completion_images: [],
        status: 'ASSIGNED',
        assigned_at: new Date(),
        completed_at: null,
        ticket_category: 'Điện',
      } as never,
    ]);

    const profile = await staffService.getStaffProfile(4);

    expect(profile.openTaskCount).toBe(1);
    expect(profile.canDeactivate).toBe(false);
  });

  it('không tìm thấy staff -> 404', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(null);

    await expect(staffService.getStaffProfile(999)).rejects.toMatchObject({
      status: 404,
    });
  });
});

describe('UC40: disableStaffAccount', () => {
  it('đã INACTIVE -> 400 (AT2)', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(
      makeStaff({ status: 'INACTIVE' }),
    );

    await expect(
      staffService.disableStaffAccount(2, 4),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('còn task mở -> 409, KHÔNG đổi status (BR-50)', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(makeStaff());
    vi.mocked(staffRepo.countActiveAssignedTasks).mockResolvedValue(2);

    await expect(
      staffService.disableStaffAccount(2, 4),
    ).rejects.toMatchObject({ status: 409 });
    expect(staffRepo.updateStaffStatus).not.toHaveBeenCalled();
  });

  it('lý do quá 250 ký tự -> 400', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(makeStaff());

    await expect(
      staffService.disableStaffAccount(2, 4, 'x'.repeat(251)),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('thành công: soft-delete + revoke token + audit, tất cả trong transaction', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(makeStaff());
    vi.mocked(staffRepo.countActiveAssignedTasks).mockResolvedValue(0);

    await staffService.disableStaffAccount(2, 4, 'Nghỉ việc');

    // BR-49/59: soft-delete (INACTIVE), không hard-delete
    expect(staffRepo.updateStaffStatus).toHaveBeenCalledWith(
      4,
      'INACTIVE',
      FAKE_CLIENT,
    );
    expect(staffRepo.revokeAllDeviceTokens).toHaveBeenCalledWith(4, FAKE_CLIENT);
    // BR-04: audit kèm reason, chạy cùng transaction
    const auditCall = vi.mocked(auditRepo.insertAuditLog).mock.calls[0];
    expect(auditCall[2]).toBe('STAFF_DEACTIVATE');
    expect(auditCall[5]).toBe('Nghỉ việc');
    expect(auditCall[6]).toBe(FAKE_CLIENT);
  });
});

describe('resetStaffPasswordByManager (UC39 - flow riêng)', () => {
  it('staff INACTIVE -> 400 (nhất quán UC40)', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(
      makeStaff({ status: 'INACTIVE' }),
    );

    await expect(
      staffService.resetStaffPasswordByManager(2, 4, 'MatKhauMoi1'),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('thành công: reset + audit KHÔNG chứa mật khẩu', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(makeStaff());

    await staffService.resetStaffPasswordByManager(2, 4, 'MatKhauMoi1');

    expect(staffRepo.resetStaffPassword).toHaveBeenCalled();
    const auditCall = vi.mocked(auditRepo.insertAuditLog).mock.calls[0];
    expect(auditCall[2]).toBe('STAFF_RESET_PASSWORD');
    expect(auditCall[3]).toBeNull();
    expect(auditCall[4]).toBeNull();
  });
});

describe('UC39: modifyStaffAccount', () => {
  it('đổi phone/role -> audit STAFF_UPDATE với old/new value (BR-04)', async () => {
    vi.mocked(staffRepo.findStaffById).mockResolvedValue(makeStaff());
    vi.mocked(userRepo.findByPhone).mockResolvedValue(null);
    vi.mocked(staffRepo.updateStaffDetails).mockResolvedValue(
      makeStaff({ phone_number: '0988888888', roles: ['JANITOR'] }),
    );

    await staffService.modifyStaffAccount(2, 4, {
      fullName: 'Trần Văn Kỹ Thuật',
      phone: '0988888888',
      role: 'JANITOR',
    });

    const auditCall = vi.mocked(auditRepo.insertAuditLog).mock.calls[0];
    expect(auditCall[2]).toBe('STAFF_UPDATE');
    expect(auditCall[3]).toEqual({
      phone: '0900000004',
      roles: ['TECHNICIAN'],
    });
  });
});
