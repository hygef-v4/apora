/**
 * ManagerService - Business Logic for Module 9: Manager Management (UC41-UC42)
 *
 * Business Rules:
 * - BR-60: Only LANDLORD can access Manager Management
 * - BR-61: List must display full name, contact, status from latest DB state
 * - BR-62: View operations are strictly read-only, no data modifications
 * - BR-08: Sensitive data (password_hash, token_version) must be masked/excluded
 * - BR-49: Inactive accounts remain visible (soft-delete only)
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 9 (ManagerService)
 */

import { withTransaction } from '@/lib/db';
import { HttpError } from '@/lib/middleware';
import * as auditRepo from '@/repositories/audit.repository';
import * as managerRepo from '@/repositories/manager.repository';
import * as userRepo from '@/repositories/user.repository';
import { hashPassword } from '@/lib/auth';
import {
  ManagementHistoryItem,
  ManagerListItem,
  ManagerStats,
  User,
} from '@/types';

const MSG_MANAGER_NOT_FOUND = 'Không tìm thấy tài khoản quản lý.';

/**
 * Maps a raw User DB row to a ManagerListItem DTO.
 * BR-08: Strips password_hash, token_version, must_change_password
 * before returning to the client.
 *
 * @param user - Raw user row from the database
 * @returns Sanitized ManagerListItem for API response
 */
function toManagerListItem(
  user: User & { managed_records_count?: number },
): ManagerListItem {
  return {
    id: user.id,
    phoneNumber: user.phone_number,
    fullName: user.full_name,
    avatarUrl: user.avatar_url,
    roles: user.roles,
    status: user.status,
    createdAt: user.created_at,
    managedRecordsCount: Number(user.managed_records_count ?? 0),
  };
}

// ==========================================
// UC41: View Manager List
// ==========================================

/**
 * Retrieves the list of Manager accounts with optional search/filter,
 * along with aggregate statistics for summary cards.
 *
 * @param filter - Optional search keyword and status filter
 * @param filter.status - 'ACTIVE' | 'INACTIVE' | undefined (all)
 * @param filter.search - Keyword to match against full_name or phone_number
 * @returns Object containing the filtered manager list and statistics
 */
export async function getManagerAccounts(filter: {
  status?: string;
  search?: string;
}): Promise<{ managers: ManagerListItem[]; stats: ManagerStats }> {
  // Validate status filter if provided
  let status: 'ACTIVE' | 'INACTIVE' | undefined;
  if (filter.status === 'ACTIVE' || filter.status === 'INACTIVE') {
    status = filter.status;
  }

  const [rows, stats] = await Promise.all([
    managerRepo.findManagersByRole(status, filter.search),
    managerRepo.getManagerStats(),
  ]);

  return { managers: rows.map(toManagerListItem), stats };
}

// ==========================================
// UC42: View Manager Detail
// ==========================================

/**
 * Retrieves the detailed profile of a specific Manager account,
 * including contact info, account status, assigned permissions,
 * and management history (from audit_logs).
 *
 * BR-08: password_hash and token_version are never exposed.
 * BR-62: Strictly read-only — no data is modified.
 *
 * @param managerId - The ID of the Manager account to retrieve
 * @returns Detailed Manager profile DTO
 * @throws HttpError 404 if the Manager account does not exist
 */
export async function getManagerProfile(managerId: number) {
  const manager = await managerRepo.findManagerById(managerId);
  if (!manager) throw new HttpError(404, MSG_MANAGER_NOT_FOUND);

  const historyRows = await managerRepo.findManagementHistory(managerId);

  const managementHistory: ManagementHistoryItem[] = historyRows.map((row) => ({
    id: row.id,
    action: row.action,
    targetUserName: row.target_user_name,
    reason: row.reason,
    createdAt: row.created_at,
  }));

  return {
    id: manager.id,
    phoneNumber: manager.phone_number,
    fullName: manager.full_name,
    avatarUrl: manager.avatar_url,
    roles: manager.roles,
    status: manager.status,
    createdAt: manager.created_at,
    managementHistory,
  };
}

// ==========================================
// UC43: Create Manager Account
// ==========================================

/**
 * Creates a new Manager account.
 * BR-02: Phone must be unique.
 * BR-03: Default password "Apora@123" is hashed.
 * BR-11: Audit log is recorded.
 *
 * @param actorId - The LANDLORD performing the action
 * @param payload - The Manager's details (fullName, phone)
 * @returns The newly created user data (without password hash)
 */
export async function createManagerAccount(
  actorId: number,
  payload: { fullName: string; phone: string },
) {
  // 1. Verify phone uniqueness
  const existingUser = await userRepo.findByPhone(payload.phone);
  if (existingUser) {
    throw new HttpError(400, 'Số điện thoại này đã được đăng ký cho tài khoản khác.');
  }

  // 2. Hash default password (BR-03)
  const defaultPassword = 'Apora@123';
  const hashed = await hashPassword(defaultPassword);

  // 3. Save to DB
  const newUser = await managerRepo.saveManager(
    payload.phone,
    hashed,
    payload.fullName,
  );

  // 4. Record audit log (BR-11)
  await auditRepo.insertAuditLog(
    actorId,
    newUser.id,
    'MANAGER_CREATE',
    null,
    { full_name: payload.fullName, phone_number: payload.phone },
  );

  return {
    id: newUser.id,
    fullName: newUser.full_name,
    phoneNumber: newUser.phone_number,
    roles: newUser.roles,
    status: newUser.status,
  };
}

// ==========================================
// UC44: Update Manager Account
// ==========================================

/**
 * Updates an existing Manager account.
 * BR-02: Phone must be unique.
 * BR-11: Audit log is recorded.
 *
 * @param actorId - The LANDLORD performing the action
 * @param targetId - The ID of the manager to update
 * @param payload - The updated details (fullName, phone)
 */
export async function updateManagerAccount(
  actorId: number,
  targetId: number,
  payload: { fullName: string; phone: string },
) {
  // 1. Verify existence of the manager
  const manager = await managerRepo.findManagerById(targetId);
  if (!manager) {
    throw new HttpError(404, MSG_MANAGER_NOT_FOUND);
  }

  // 2. Verify phone uniqueness if changed (BR-02)
  if (manager.phone_number !== payload.phone) {
    const existingUser = await userRepo.findByPhone(payload.phone);
    if (existingUser && existingUser.id !== targetId) {
      throw new HttpError(400, 'Số điện thoại này đã được đăng ký cho tài khoản khác.');
    }
  }

  // 3. Save to DB
  const updatedUser = await managerRepo.updateManager(targetId, payload.fullName, payload.phone);

  // 4. Record audit log (BR-11)
  const changes = [];
  if (manager.full_name !== payload.fullName) changes.push(`Tên: ${manager.full_name} -> ${payload.fullName}`);
  if (manager.phone_number !== payload.phone) changes.push(`SĐT: ${manager.phone_number} -> ${payload.phone}`);

  if (changes.length > 0) {
    await auditRepo.insertAuditLog(
      actorId,
      targetId,
      'MANAGER_UPDATE',
      { full_name: manager.full_name, phone_number: manager.phone_number },
      { full_name: payload.fullName, phone_number: payload.phone },
      changes.join(', ')
    );
  }

  return {
    id: updatedUser.id,
    fullName: updatedUser.full_name,
    phoneNumber: updatedUser.phone_number,
    roles: updatedUser.roles,
    status: updatedUser.status,
  };
}

// ==========================================
// UC45: Deactivate / Reactivate Manager Account
// ==========================================

/**
 * Updates the status (ACTIVE/INACTIVE) of a Manager account.
 * BR-05: If deactivated, invalidate sessions.
 * BR-11: Audit log is recorded.
 *
 * @param actorId - The LANDLORD performing the action
 * @param targetId - The ID of the manager to update
 * @param status - The new status ('ACTIVE' | 'INACTIVE')
 */
export async function updateManagerStatus(
  actorId: number,
  targetId: number,
  status: 'ACTIVE' | 'INACTIVE',
) {
  const manager = await managerRepo.findManagerById(targetId);
  if (!manager) {
    throw new HttpError(404, MSG_MANAGER_NOT_FOUND);
  }

  if (manager.status === status) {
    throw new HttpError(400, `Tài khoản đã ở trạng thái ${status}`);
  }

  // Đổi status + revoke FCM token + audit trong 1 transaction (đồng bộ hành vi
  // với Module 8 - UC40): vô hiệu hóa mà thiếu vết audit hoặc còn nhận push
  // là không chấp nhận được. updateManagerStatus tự bump token_version (BR-05).
  const actionType = status === 'ACTIVE' ? 'MANAGER_REACTIVATE' : 'MANAGER_DEACTIVATE';
  const reason = status === 'ACTIVE' ? 'Khôi phục tài khoản' : 'Vô hiệu hóa tài khoản';

  const updatedUser = await withTransaction(async (client) => {
    const user = await managerRepo.updateManagerStatus(targetId, status, client);

    // BR-05: ngừng gửi push notification cho tài khoản đã vô hiệu hóa
    if (status === 'INACTIVE') {
      await userRepo.revokeAllDeviceTokens(targetId, client);
    }

    // BR-11: Audit log
    await auditRepo.insertAuditLog(
      actorId,
      targetId,
      actionType,
      { status: status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE' },
      { status },
      reason,
      client,
    );
    return user;
  });

  return {
    id: updatedUser.id,
    status: updatedUser.status,
  };
}
