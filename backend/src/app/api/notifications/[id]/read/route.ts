import { NextRequest } from 'next/server';
import { requireAuth, jsonSuccess, jsonError, HttpError } from '@/lib/middleware';
import { markNotificationAsRead } from '@/services/notification.service';

/**
 * PATCH /api/notifications/[id]/read
 * 
 * Đánh dấu thông báo là đã đọc (UC27).
 */
export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    // 1. Kiểm tra xác thực
    const session = await requireAuth(req);
    const userId = session.id;
    
    // 2. Parse ID thông báo
    const notificationId = parseInt(id, 10);
    if (isNaN(notificationId)) {
      throw new HttpError(400, 'ID thông báo không hợp lệ.');
    }

    // 3. Thực thi update
    const updated = await markNotificationAsRead(notificationId, userId);

    if (!updated) {
      // Có thể do thông báo không tồn tại, hoặc đã được đọc rồi
      return jsonSuccess('Thông báo đã được đánh dấu đọc từ trước hoặc không tìm thấy.');
    }

    return jsonSuccess('Đã đánh dấu là đã đọc.');
  } catch (error) {
    return jsonError(error);
  }
}
