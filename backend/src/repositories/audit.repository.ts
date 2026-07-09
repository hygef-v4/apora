/**
 * AuditRepository - Data Access Layer cho bảng audit_logs
 *
 * Dùng chung cho mọi module cần ghi vết thao tác nhạy cảm:
 * - Module 8/9: quản lý nhân sự (UC39/UC40 BR-04) - STAFF_CREATE/UPDATE/DEACTIVATE...
 * - Module 1: đổi số điện thoại đăng nhập (BR-12) - PROFILE_PHONE_CHANGE
 *
 * ⚠️ KHÔNG BAO GIỜ ghi mật khẩu (kể cả hash) vào old_value/new_value.
 */

import { query } from '@/lib/db';

export async function insertAuditLog(
  actorId: number,
  targetUserId: number | null,
  action: string,
  oldValue: Record<string, unknown> | null,
  newValue: Record<string, unknown> | null,
  reason?: string,
): Promise<void> {
  await query(
    `INSERT INTO audit_logs (actor_id, target_user_id, action, old_value, new_value, reason)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [actorId, targetUserId, action, oldValue, newValue, reason ?? null],
  );
}
