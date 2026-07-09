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

const MSG_PHONE_EXISTS = 'Số điện thoại đã tồn tại. Vui lòng nhập số khác.';
const MSG_STAFF_NOT_FOUND = 'Không tìm thấy tài khoản nhân viên.';
const MSG_INVALID_ROLE = 'Vai trò không hợp lệ. Vui lòng chọn Bảo vệ, Lao công hoặc Kỹ thuật viên.';

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
    throw new HttpError(400, 'Trường bắt buộc không được để trống.');
  }
  assertStaffRole(data.role);

  const phoneError = validatePhoneNumber(data.phone.trim()); // BR-02
  if (phoneError) throw new HttpError(400, phoneError);

  const complexityError = validatePasswordComplexity(data.password); // BR-09
  if (complexityError) throw new HttpError(400, complexityError);

  // BR-02: phone unique toàn hệ thống (mọi loại tài khoản)
  const existed = await userRepo.findByPhone(data.phone.trim());
  if (existed) throw new HttpError(409, MSG_PHONE_EXISTS);

  const hash = await hashPassword(data.password); // BR-03
  const created = await staffRepo.saveStaff(
    data.phone.trim(),
    hash,
    data.fullName.trim(),
    data.role,
  );

  await auditRepo.insertAuditLog(actorId, created.id, 'STAFF_CREATE', null, {
    fullName: created.full_name,
    phone: created.phone_number,
    role: data.role,
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
    throw new HttpError(400, 'Trường bắt buộc không được để trống.');
  }
  assertStaffRole(data.role);

  const phoneError = validatePhoneNumber(data.phone.trim()); // BR-02
  if (phoneError) throw new HttpError(400, phoneError);

  const current = await staffRepo.findStaffById(staffId);
  if (!current) throw new HttpError(404, MSG_STAFF_NOT_FOUND);

  // BR-02: phone unique
  if (data.phone.trim() !== current.phone_number) {
    const existed = await userRepo.findByPhone(data.phone.trim());
    if (existed) throw new HttpError(409, MSG_PHONE_EXISTS);
  }

  // AT3 (UC39): avatar upload lỗi -> vẫn lưu các field text, giữ avatar cũ
  let avatarUrl: string | undefined;
  if (data.avatarBuffer) {
    try {
      avatarUrl = await uploadImage(data.avatarBuffer, 'avatars');
    } catch (error) {
      console.error('[StaffService] Upload avatar thất bại, giữ avatar cũ:', error);
    }
  }

  const updated = await staffRepo.updateStaffDetails(
    staffId,
    data.fullName.trim(),
    data.phone.trim(),
    data.role,
    avatarUrl,
  );

  // BR-04 (UC39): audit khi đổi field quan trọng (phone / role)
  const phoneChanged = current.phone_number !== updated.phone_number;
  const roleChanged = current.roles.join(',') !== updated.roles.join(',');
  if (phoneChanged || roleChanged) {
    await auditRepo.insertAuditLog(
      actorId,
      staffId,
      'STAFF_UPDATE',
      { phone: current.phone_number, roles: current.roles },
      { phone: updated.phone_number, roles: updated.roles },
    );
  }

  return {
    id: updated.id,
    phoneNumber: updated.phone_number,
    fullName: updated.full_name,
    avatarUrl: updated.avatar_url,
    roles: updated.roles,
    status: updated.status,
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
    throw new HttpError(400, 'Tài khoản này đã bị vô hiệu hóa từ trước.');
  }

  // BR-50: còn task đang mở -> chặn, yêu cầu phân công lại trước
  const openCount = await staffRepo.countActiveAssignedTasks(staffId);
  if (openCount > 0) {
    throw new HttpError(
      409,
      `Nhân viên còn ${openCount} công việc chưa xử lý. Vui lòng phân công lại trước khi vô hiệu hóa.`,
    );
  }

  if (reason && reason.length > 250) {
    throw new HttpError(400, 'Lý do vô hiệu hóa tối đa 250 ký tự.');
  }

  // BR-49/BR-59: soft-delete - chỉ đổi status, giữ toàn bộ lịch sử
  await staffRepo.updateStaffStatus(staffId, 'INACTIVE'); // kèm bump token_version
  await staffRepo.revokeAllDeviceTokens(staffId);

  // BR-04 (UC40): audit log bắt buộc
  await auditRepo.insertAuditLog(
    actorId,
    staffId,
    'STAFF_DEACTIVATE',
    { status: 'ACTIVE' },
    { status: 'INACTIVE' },
    reason?.trim() || undefined,
  );
}
