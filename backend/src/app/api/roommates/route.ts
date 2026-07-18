import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as roommateService from '@/services/roommate.service';
import { readImageUpload } from '@/lib/upload';
import { uploadImage } from '@/lib/cloudinary';

/**
 * GET /api/roommates - UC10: Cư dân xem danh sách thành viên phòng
 * Roles: RESIDENT
 */
export async function GET(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['RESIDENT']);
    const roommates = await roommateService.getRoommatesForResident(auth.id);
    return jsonSuccess('Lấy danh sách thành viên phòng thành công.', roommates);
  } catch (error) {
    return jsonError(error);
  }
}

/**
 * POST /api/roommates - UC11: Cư dân đăng ký thành viên phòng mới
 * Roles: RESIDENT
 * Body: MultipartFormData { fullName, phoneNumber, cccdNumber, cccdFront, cccdBack }
 */
export async function POST(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['RESIDENT']);
    const form = await req.formData();
    const fullName = form.get('fullName');
    const phoneNumber = form.get('phoneNumber');
    const cccdNumber = form.get('cccdNumber');

    if (!fullName || !cccdNumber) {
      return jsonError({ status: 400, message: 'Họ tên và Số CCCD là bắt buộc.' });
    }

    const cccdFrontBuffer = await readImageUpload(form, 'cccdFront');
    const cccdBackBuffer = await readImageUpload(form, 'cccdBack');

    let cccdFrontUrl: string | null = null;
    let cccdBackUrl: string | null = null;

    if (cccdFrontBuffer) {
      cccdFrontUrl = await uploadImage(cccdFrontBuffer, 'roommates');
    }
    if (cccdBackBuffer) {
      cccdBackUrl = await uploadImage(cccdBackBuffer, 'roommates');
    }

    const roommate = await roommateService.registerRoommate(auth.id, {
      fullName: String(fullName),
      phoneNumber: phoneNumber ? String(phoneNumber) : null,
      cccdNumber: String(cccdNumber),
      cccdFrontUrl,
      cccdBackUrl,
    });

    return jsonSuccess('Đăng ký thành viên mới thành công, đang chờ Quản lý duyệt.', roommate, 201);
  } catch (error) {
    return jsonError(error);
  }
}
