/**
 * StaffService - Business Logic cho Module 8: Operational Staff Management (UC36-UC40)
 *
 * Business Rules chính:
 * - Access control MANAGER/LANDLORD (check ở route qua requireAuth)
 * - UC36: chỉ role staff, không lộ password_hash, sort theo tên
 * - UC38: phone unique (BR-02), bcrypt (BR-03), BR-09, tạo ACTIVE + must_change_password
 * - UC39: phone unique, audit log khi đổi phone/role (BR-04)
 * - UC40 + BR-50: chặn deactivate khi còn task ASSIGNED/IN_PROGRESS;
 *   INACTIVE + vô hiệu JWT + revoke device tokens; audit log kèm reason
 * - BR-49/BR-59: không hard-delete
 */

import { hashPassword, validatePasswordComplexity, validatePhoneNumber } from '@/lib/auth';
import { uploadImage } from '@/lib/cloudinary';
import { withTransaction } from '@/lib/db';
import { HttpError } from '@/lib/middleware';
import * as auditRepo from '@/repositories/audit.repository';
import * as staffRepo from '@/repositories/staff.repository';
import * as userRepo from '@/repositories/user.repository';
import {
  STAFF_ROLES,
  StaffListItem,
  StaffRole,
  StaffStats,
  User,
  UserStatus,
} from '@/types';

const MSG_PHONE_EXISTS = 'This phone number already exists. Please use another one.';
const MSG_STAFF_NOT_FOUND = 'Staff account not found.';
const MSG_INVALID_ROLE = 'Invalid role. Please choose Security, Janitor or Technician.';

// Khớp VARCHAR(100) của cột users.full_name - validate sớm để trả 400 rõ ràng
// thay vì lỗi 22001 của Postgres rơi vào 500 chung chung.
const FULL_NAME_MAX = 100;

function assertFullNameLength(fullName: string): void {
  if (fullName.length > FULL_NAME_MAX) {
    throw new HttpError(400, `Full name must be at most ${FULL_NAME_MAX} characters.`);
  }
}

function toStaffListItem(row: staffRepo.StaffRow): StaffListItem {
  return {
    id: row.id,
    phoneNumber: row.phone_number,
    fullName: row.full_name,
    avatarUrl: row.avatar_url,
    roles: row.roles,
    status: row.status,
    openTaskCount: row.open_task_count,
    createdAt: row.created_at,
  };
}

function assertStaffRole(role: string): asserts role is StaffRole {
  if (!STAFF_ROLES.includes(role as StaffRole)) {
    throw new HttpError(400, MSG_INVALID_ROLE);
  }
}

// ==========================================
// UC36: View Staff List
// ==========================================

export async function getStaffAccounts(filter: {
  status?: string;
  search?: string;
  role?: string;
}): Promise<{ staff: StaffListItem[]; stats: StaffStats }> {
  let status: UserStatus | undefined;
  if (filter.status === 'ACTIVE' || filter.status === 'INACTIVE') {
    status = filter.status;
  }
  let role: StaffRole | undefined;
  if (filter.role) {
    assertStaffRole(filter.role);
    role = filter.role;
  }

  const [rows, stats] = await Promise.all([
    staffRepo.findStaffByRole(status, filter.search, role),
    staffRepo.getStaffStats(),
  ]);
  return { staff: rows.map(toStaffListItem), stats };
}

// ==========================================
// UC37: View Staff Detail
// ==========================================

export async function getStaffProfile(staffId: number) {
  const staff = await staffRepo.findStaffById(staffId);
  if (!staff) throw new HttpError(404, MSG_STAFF_NOT_FOUND);

  const openTasks = await staffRepo.findOpenTasksByStaffId(staffId);
  return {
    id: staff.id,
    phoneNumber: staff.phone_number,
    fullName: staff.full_name,
    avatarUrl: staff.avatar_url,
    roles: staff.roles,
    status: staff.status,
    createdAt: staff.created_at,
    openTaskCount: openTasks.length,
    // BR-50: chỉ được deactivate khi không còn task đang mở
    canDeactivate: staff.status === 'ACTIVE' && openTasks.length === 0,
    openTasks: openTasks.map((t) => ({
      id: t.id,
      title: t.title,
      status: t.status,
      category: t.ticket_category,
      assignedAt: t.assigned_at,
    })),
  };
}

// ==========================================
// UC38: Create Staff Account
// ==========================================

export async function registerStaffAccount(
  actorId: number,
  data: { fullName: string; phone: string; password: string; role: string },
): Promise<StaffListItem> {
  if (!data.fullName?.trim() || !data.phone?.trim() || !data.password || !data.role) {
    throw new HttpError(400, 'Required fields must not be empty.');
  }
  assertStaffRole(data.role);
  assertFullNameLength(data.fullName.trim());

  const phoneError = validatePhoneNumber(data.phone.trim()); // BR-02
  if (phoneError) throw new HttpError(400, phoneError);

  const complexityError = validatePasswordComplexity(data.password); // BR-09
  if (complexityError) throw new HttpError(400, complexityError);

  // BR-02: phone unique toàn hệ thống (mọi loại tài khoản)
  const existed = await userRepo.findByPhone(data.phone.trim());
  if (existed) throw new HttpError(409, MSG_PHONE_EXISTS);

  const hash = await hashPassword(data.password); // BR-03

  // Tạo user + audit log trong 1 transaction: BR-04 yêu cầu thao tác quản lý
  // nhân sự phải có vết audit - ghi vết lỗi thì không được tạo tài khoản.
  const role = data.role;
  const created = await withTransaction(async (client) => {
    const user = await staffRepo.saveStaff(
      data.phone.trim(),
      hash,
      data.fullName.trim(),
      role,
      client,
    );
    await auditRepo.insertAuditLog(
      actorId,
      user.id,
      'STAFF_CREATE',
      null,
      { fullName: user.full_name, phone: user.phone_number, role },
      undefined,
      client,
    );
    return user;
  });

  return {
    id: created.id,
    phoneNumber: created.phone_number,
    fullName: created.full_name,
    avatarUrl: created.avatar_url,
    roles: created.roles,
    status: created.status,
    openTaskCount: 0,
    createdAt: created.created_at,
  };
}

// ==========================================
// UC39: Update Staff Account
// ==========================================

export async function modifyStaffAccount(
  actorId: number,
  staffId: number,
  data: { fullName: string; phone: string; role: string; avatarBuffer?: Buffer },
) {
  if (!data.fullName?.trim() || !data.phone?.trim() || !data.role) {
    throw new HttpError(400, 'Required fields must not be empty.');
  }
  assertStaffRole(data.role);
  assertFullNameLength(data.fullName.trim());
  // Giữ narrowing StaffRole khi dùng trong closure transaction bên dưới
  const role = data.role;

  const phoneError = validatePhoneNumber(data.phone.trim()); // BR-02
  if (phoneError) throw new HttpError(400, phoneError);

  const current = await staffRepo.findStaffById(staffId);
  if (!current) throw new HttpError(404, MSG_STAFF_NOT_FOUND);

  // BR-02: phone unique
  if (data.phone.trim() !== current.phone_number) {
    const existed = await userRepo.findByPhone(data.phone.trim());
    if (existed) throw new HttpError(409, MSG_PHONE_EXISTS);
  }

  // AT3 (UC39): avatar upload lỗi -> vẫn lưu các field text, giữ avatar cũ,
  // nhưng trả cờ avatarUploadFailed để UI báo cho người dùng biết.
  let avatarUrl: string | undefined;
  let avatarUploadFailed = false;
  if (data.avatarBuffer) {
    try {
      avatarUrl = await uploadImage(data.avatarBuffer, 'avatars');
    } catch (error) {
      avatarUploadFailed = true;
      console.error('[StaffService] Upload avatar thất bại, giữ avatar cũ:', error);
    }
  }

  // Update + audit trong 1 transaction (đồng bộ với UC38/UC40): BR-04 yêu cầu
  // đổi phone/role phải có vết audit - ghi vết lỗi thì không được lưu thay đổi.
  const updated = await withTransaction(async (client) => {
    const user = await staffRepo.updateStaffDetails(
      staffId,
      data.fullName.trim(),
      data.phone.trim(),
      role,
      avatarUrl,
      client,
    );

    // BR-04 (UC39): audit khi đổi field quan trọng (phone / role)
    const phoneChanged = current.phone_number !== user.phone_number;
    const roleChanged = current.roles.join(',') !== user.roles.join(',');
    if (phoneChanged || roleChanged) {
      // AT4 (UC39): đổi role khi còn task mở - client đã cảnh báo xác nhận;
      // server ghi nhận số task mở tại thời điểm đổi vào audit để truy vết
      // các task cần phân công lại.
      const openTasksAtChange = roleChanged
        ? await staffRepo.countActiveAssignedTasks(staffId, client)
        : undefined;
      await auditRepo.insertAuditLog(
        actorId,
        staffId,
        'STAFF_UPDATE',
        { phone: current.phone_number, roles: current.roles },
        {
          phone: user.phone_number,
          roles: user.roles,
          ...(openTasksAtChange !== undefined
            ? { openTasksAtRoleChange: openTasksAtChange }
            : {}),
        },
        undefined,
        client,
      );
    }
    return user;
  });

  return {
    id: updated.id,
    phoneNumber: updated.phone_number,
    fullName: updated.full_name,
    avatarUrl: updated.avatar_url,
    roles: updated.roles,
    status: updated.status,
    ...(avatarUploadFailed ? { avatarUploadFailed: true } : {}),
  };
}

// ==========================================
// Manager đặt lại mật khẩu cho staff (UC39 - flow riêng, khác UC03)
// ==========================================

export async function resetStaffPasswordByManager(
  actorId: number,
  staffId: number,
  newPassword: string,
): Promise<void> {
  const staff = await staffRepo.findStaffById(staffId);
  if (!staff) throw new HttpError(404, MSG_STAFF_NOT_FOUND);

  // Nhất quán với UC40: tài khoản đã vô hiệu hóa thì không thao tác gì thêm
  if (staff.status === 'INACTIVE') {
    throw new HttpError(400, 'This account is deactivated, its password cannot be reset.');
  }

  const complexityError = validatePasswordComplexity(newPassword); // BR-09
  if (complexityError) throw new HttpError(400, complexityError);

  const hash = await hashPassword(newPassword);
  await staffRepo.resetStaffPassword(staffId, hash);

  // KHÔNG ghi mật khẩu vào audit log
  await auditRepo.insertAuditLog(actorId, staffId, 'STAFF_RESET_PASSWORD', null, null);
}

// ==========================================
// UC40: Deactivate Staff Account
// ==========================================

export async function disableStaffAccount(
  actorId: number,
  staffId: number,
  reason?: string,
): Promise<void> {
  const staff = await staffRepo.findStaffById(staffId);
  if (!staff) throw new HttpError(404, MSG_STAFF_NOT_FOUND);

  // AT2: đã INACTIVE -> chặn deactivate lần 2
  if (staff.status === 'INACTIVE') {
    throw new HttpError(400, 'This account has already been deactivated.');
  }

  if (reason && reason.length > 250) {
    throw new HttpError(400, 'The deactivation reason must be at most 250 characters.');
  }

  // Toàn bộ deactivate chạy trong 1 transaction: check BR-50, đổi status,
  // revoke token và audit log (BR-04) phải cùng thành công hoặc cùng rollback -
  // không được vô hiệu hóa tài khoản mà thiếu vết audit.
  await withTransaction(async (client) => {
    // BR-50: còn task đang mở -> chặn, yêu cầu phân công lại trước
    // (check trong transaction để thu hẹp race với luồng phân công task)
    const openCount = await staffRepo.countActiveAssignedTasks(staffId, client);
    if (openCount > 0) {
      throw new HttpError(
        409,
        `Nhân viên còn ${openCount} công việc chưa xử lý. Vui lòng phân công lại trước khi vô hiệu hóa.`,
      );
    }

    // BR-49/BR-59: soft-delete - chỉ đổi status, giữ toàn bộ lịch sử
    await staffRepo.updateStaffStatus(staffId, 'INACTIVE', client); // kèm bump token_version
    await staffRepo.revokeAllDeviceTokens(staffId, client);

    // BR-04 (UC40): audit log bắt buộc
    await auditRepo.insertAuditLog(
      actorId,
      staffId,
      'STAFF_DEACTIVATE',
      { status: 'ACTIVE' },
      { status: 'INACTIVE' },
      reason?.trim() || undefined,
      client,
    );
  });
}
