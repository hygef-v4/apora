import { NextRequest } from 'next/server';
import { requireAuth, jsonSuccess, jsonError, HttpError } from '@/lib/middleware';
import { readImageUpload } from '@/lib/upload';
import { uploadImage } from '@/lib/cloudinary';
import { publishAnnouncement } from '@/services/notification.service';

/**
 * POST /api/notifications/announce
 * 
 * Đăng thông báo chung tới tất cả người dùng (UC24)
 * Yêu cầu: LANDLORD hoặc MANAGER
 * Body (FormData):
 *  - title: string
 *  - body: string
 *  - banner: (file ảnh) - Optional
 */
export async function POST(req: NextRequest) {
  try {
    // 1. Kiểm tra quyền
    await requireAuth(req, ['LANDLORD', 'MANAGER']);

    // 2. Parse FormData
    const formData = await req.formData();
    const title = formData.get('title');
    const body = formData.get('body');

    if (!title || typeof title !== 'string' || title.trim() === '') {
      throw new HttpError(400, 'Tiêu đề thông báo không hợp lệ.');
    }
    if (!body || typeof body !== 'string' || body.trim() === '') {
      throw new HttpError(400, 'Nội dung thông báo không hợp lệ.');
    }

    // 3. Xử lý ảnh banner (nếu có)
    let bannerUrl: string | undefined;
    const bannerBuffer = await readImageUpload(formData, 'banner');
    
    if (bannerBuffer) {
      bannerUrl = await uploadImage(bannerBuffer, 'announcements');
    }

    // 4. Gọi Service thực thi logic
    await publishAnnouncement(title.trim(), body.trim(), bannerUrl);

    return jsonSuccess('Đăng thông báo thành công.');
  } catch (error) {
    return jsonError(error);
  }
}
