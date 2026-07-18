/**
 * StaffRepository - Data Access Layer cho Module 8: Operational Staff Management
 *
 * Thao tác trên bảng users (role staff), tasks (workload BR-41/BR-50)
 * và device_tokens. Audit log ghi qua audit.repository (dùng chung).
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 8 (StaffRepository)
 */

import { Queryable, query } from '@/lib/db';
import { StaffRole, StaffStats, Task, User, UserStatus } from '@/types';

/** Điều kiện SQL nhận diện tài khoản staff (BR-02 UC36: loại RESIDENT/MANAGER/LANDLORD). */
const STAFF_ROLES_SQL = `ARRAY['SECURITY_GUARD','JANITOR','TECHNICIAN']::text[]`;

/**
 * Điều kiện SQL "task đang mở" theo BR-50: chỉ ASSIGNED/IN_PROGRESS.
 * Không dùng `<> 'COMPLETED'` kẻo tính nhầm cả task CANCELLED
 * (và để query khớp partial index idx_tasks_assigned_open).
 */
const OPEN_TASK_SQL = `status IN ('ASSIGNED', 'IN_PROGRESS')`;

export interface StaffRow extends User {
  open_task_count: number;
}

/**
 * Danh sách staff kèm số task đang mở của từng người (1 query, tránh N+1).
 * Sort mặc định theo tên (BR-03 UC36).
 */
export async function findStaffByRole(
  statusFilter?: UserStatus,
  search?: string,
  roleFilter?: StaffRole,
): Promise<StaffRow[]> {
  const conditions: string[] = [`u.roles && ${STAFF_ROLES_SQL}`];
  const params: unknown[] = [];

  if (statusFilter) {
    params.push(statusFilter);
    conditions.push(`u.status = $${params.length}`);
  }
  if (roleFilter) {
    params.push(roleFilter);
    conditions.push(`$${params.length} = ANY(u.roles)`);
  }
  if (search?.trim()) {
    // Escape ký tự wildcard của LIKE để user gõ % / _ được hiểu là ký tự thường
    const escaped = search.trim().replace(/[\\%_]/g, '\\$&');
    params.push(`%${escaped}%`);
    conditions.push(
      `(u.full_name ILIKE $${params.length} OR u.phone_number ILIKE $${params.length})`,
    );
  }

  const result = await query(
    `SELECT u.*, COALESCE(t.open_count, 0)::int AS open_task_count
     FROM users u
     LEFT JOIN LATERAL (
       SELECT COUNT(*) AS open_count
       FROM tasks
       WHERE tasks.assigned_to = u.id AND tasks.${OPEN_TASK_SQL}
     ) t ON TRUE
     WHERE ${conditions.join(' AND ')}
     ORDER BY u.full_name ASC`,
    params,
  );
  return result.rows;
}

/** Thống kê tổng quan (UC36 - Staff Statistics Summary). */
export async function getStaffStats(): Promise<StaffStats> {
  const result = await query(
    `SELECT
       COUNT(*)::int                                            AS total,
       COUNT(*) FILTER (WHERE u.status = 'ACTIVE')::int         AS active,
       COUNT(*) FILTER (WHERE u.status = 'INACTIVE')::int       AS inactive,
       COALESCE(SUM(t.open_count), 0)::int                      AS open_tasks
     FROM users u
     LEFT JOIN LATERAL (
       SELECT COUNT(*) AS open_count
       FROM tasks
       WHERE tasks.assigned_to = u.id AND tasks.${OPEN_TASK_SQL}
     ) t ON TRUE
     WHERE u.roles && ${STAFF_ROLES_SQL}`,
  );
  const row = result.rows[0];
  return {
    total: row.total,
    active: row.active,
    inactive: row.inactive,
    openTasks: row.open_tasks,
  };
}

/** Tìm user theo id, chỉ trả về nếu là tài khoản staff. */
export async function findStaffById(id: number): Promise<User | null> {
  const result = await query(
    `SELECT * FROM users WHERE id = $1 AND roles && ${STAFF_ROLES_SQL}`,
    [id],
  );
  return result.rows[0] ?? null;
}

/** Task đang mở (ASSIGNED/IN_PROGRESS) của 1 staff, kèm category từ ticket (UC37). */
export async function findOpenTasksByStaffId(
  staffId: number,
): Promise<(Task & { ticket_category: string | null })[]> {
  const result = await query(
    `SELECT t.*, rt.category AS ticket_category
     FROM tasks t
     LEFT JOIN repair_tickets rt ON rt.id = t.ticket_id
     WHERE t.assigned_to = $1 AND t.${OPEN_TASK_SQL}
     ORDER BY t.assigned_at DESC`,
    [staffId],
  );
  return result.rows;
}

/** BR-50: đếm task đang mở (ASSIGNED/IN_PROGRESS) - chặn deactivate khi > 0. */
export async function countActiveAssignedTasks(
  staffId: number,
  client?: Queryable,
): Promise<number> {
  const result = await (client ?? { query }).query(
    `SELECT COUNT(*)::int AS count
     FROM tasks
     WHERE assigned_to = $1 AND ${OPEN_TASK_SQL}`,
    [staffId],
  );
  return result.rows[0].count;
}

/** UC38: tạo tài khoản staff mới (ACTIVE, phải đổi mật khẩu lần đầu - BR-01). */
export async function saveStaff(
  phone: string,
  passwordHash: string,
  fullName: string,
  role: StaffRole,
  client?: Queryable,
): Promise<User> {
  const result = await (client ?? { query }).query(
    `INSERT INTO users (phone_number, password_hash, full_name, roles, status, must_change_password)
     VALUES ($1, $2, $3, ARRAY[$4]::text[], 'ACTIVE', TRUE)
     RETURNING *`,
    [phone, passwordHash, fullName, role],
  );
  return result.rows[0];
}

/** UC39: cập nhật hồ sơ staff (tên, SĐT, role, avatar). */
export async function updateStaffDetails(
  id: number,
  fullName: string,
  phone: string,
  role: StaffRole,
  avatarUrl?: string,
): Promise<User> {
  const result = await query(
    `UPDATE users
     SET full_name = $2, phone_number = $3, roles = ARRAY[$4]::text[],
         avatar_url = COALESCE($5, avatar_url)
     WHERE id = $1
     RETURNING *`,
    [id, fullName, phone, role, avatarUrl ?? null],
  );
  return result.rows[0];
}

/**
 * UC40: vô hiệu hóa tài khoản. Bump token_version để mọi JWT đang hoạt động
 * mất hiệu lực ngay (đá khỏi mọi thiết bị - UC40 bước 4).
 */
export async function updateStaffStatus(
  id: number,
  status: UserStatus,
  client?: Queryable,
): Promise<void> {
  await (client ?? { query }).query(
    `UPDATE users SET status = $2, token_version = token_version + 1 WHERE id = $1`,
    [id, status],
  );
}

/** Manager đặt lại mật khẩu cho staff: buộc đổi lại ở lần login sau (BR-01). */
export async function resetStaffPassword(id: number, hash: string): Promise<void> {
  await query(
    `UPDATE users
     SET password_hash = $2, must_change_password = TRUE, token_version = token_version + 1
     WHERE id = $1`,
    [id, hash],
  );
}

/** Revoke toàn bộ FCM token khi deactivate (tinh thần BR-44 - ngừng gửi noti). */
export async function revokeAllDeviceTokens(
  userId: number,
  client?: Queryable,
): Promise<void> {
  await (client ?? { query }).query(
    `UPDATE device_tokens SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`,
    [userId],
  );
}
