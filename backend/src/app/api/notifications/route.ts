import { NextRequest } from 'next/server';
import { requireAuth, jsonSuccess, jsonError } from '@/lib/middleware';
import { getUserNotifications } from '@/services/notification.service';

/**
 * GET /api/notifications
 * 
 * Lấy danh sách thông báo của user hiện tại (UC25).
 * Query Params:
 *  - limit: Số lượng tối đa (default 20)
 *  - offset: Vị trí bắt đầu (default 0)
 */
export async function GET(req: NextRequest) {
  try {
    // 1. Kiểm tra xác thực (Không truyền array roles => Ai có tài khoản cũng truy cập được)
    const session = await requireAuth(req);
    const userId = session.userId;

    // 2. Lấy params
    const { searchParams } = new URL(req.url);
    const limit = parseInt(searchParams.get('limit') || '20', 10);
    const offset = parseInt(searchParams.get('offset') || '0', 10);

    // 3. Truy xuất DB
    const notifications = await getUserNotifications(userId, limit, offset);

    return jsonSuccess(notifications);
  } catch (error) {
    return jsonError(error);
  }
}
