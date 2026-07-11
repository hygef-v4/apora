import { query } from '@/lib/db';

/**
 * Lấy tất cả user IDs (gửi announcement cho toàn bộ user)
 */
export async function getAllUserIdsToNotify(): Promise<number[]> {
  const result = await query(
    `SELECT id FROM users WHERE status = 'ACTIVE'`
  );
  return result.rows.map((row) => row.id);
}

/**
 * Bulk insert thông báo cho nhiều users.
 * Sử dụng UNNEST để insert hiệu quả với 1 query duy nhất.
 */
export async function createNotificationsBulk(
  userIds: number[],
  title: string,
  body: string,
  type: string,
  referenceId: number | null
): Promise<void> {
  if (userIds.length === 0) return;

  await query(
    `INSERT INTO notifications (user_id, title, body, type, reference_id)
     SELECT unnest($1::int[]), $2, $3, $4, $5`,
    [userIds, title, body, type, referenceId]
  );
}

/**
 * Lấy danh sách device_tokens đang ACTIVE của các users để gửi FCM.
 */
export async function getActiveDeviceTokens(userIds: number[]): Promise<string[]> {
  if (userIds.length === 0) return [];

  const result = await query(
    `SELECT token FROM device_tokens 
     WHERE status = 'ACTIVE' 
       AND revoked_at IS NULL 
       AND user_id = ANY($1::int[])`,
    [userIds]
  );

  return result.rows.map((row) => row.token);
}

/**
 * Lấy danh sách thông báo của 1 user, phân trang.
 */
export async function getUserNotifications(userId: number, limit: number, offset: number): Promise<any[]> {
  const result = await query(
    `SELECT * FROM notifications 
     WHERE user_id = $1 
     ORDER BY created_at DESC 
     LIMIT $2 OFFSET $3`,
    [userId, limit, offset]
  );
  return result.rows;
}

/**
 * Đánh dấu một thông báo là đã đọc.
 */
export async function markAsRead(notificationId: number, userId: number): Promise<boolean> {
  const result = await query(
    `UPDATE notifications 
     SET is_read = true, read_at = CURRENT_TIMESTAMP 
     WHERE id = $1 AND user_id = $2 AND is_read = false
     RETURNING id`,
    [notificationId, userId]
  );

  // Trả về true nếu có dòng được update, false nếu không tìm thấy hoặc đã đọc rồi
  return (result.rowCount ?? 0) > 0;
}
