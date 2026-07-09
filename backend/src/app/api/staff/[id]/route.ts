/**
 * GET /api/staff/:id - UC37: Chi tiết nhân viên + danh sách task đang mở
 * PUT /api/staff/:id - UC39: Cập nhật hồ sơ nhân viên (multipart/form-data)
 *   Fields: fullName, phone, role, avatar? (đã nén < 500KB - BR-10)
 * Chỉ MANAGER / LANDLORD.
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import { readImageUpload } from '@/lib/upload';
import * as staffService from '@/services/staff.service';

function parseId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Mã nhân viên không hợp lệ.');
  }
  return id;
}

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { id } = await params;
    const data = await staffService.getStaffProfile(parseId(id));
    return jsonSuccess('Lấy thông tin nhân viên thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const auth = await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { id } = await params;

    const form = await req.formData().catch(() => {
      throw new HttpError(400, 'Dữ liệu gửi lên không hợp lệ (yêu cầu multipart/form-data).');
    });

    const avatarBuffer = await readImageUpload(form, 'avatar');

    const data = await staffService.modifyStaffAccount(auth.id, parseId(id), {
      fullName: String(form.get('fullName') ?? ''),
      phone: String(form.get('phone') ?? ''),
      role: String(form.get('role') ?? ''),
      avatarBuffer,
    });
    return jsonSuccess('Cập nhật hồ sơ nhân viên thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
