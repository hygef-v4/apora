/**
 * GET  /api/staff - UC36: Danh sách nhân viên + thống kê
 *   Query: ?status=ACTIVE|INACTIVE & search=<tên/SĐT> & role=<StaffRole>
 * POST /api/staff - UC38: Tạo tài khoản nhân viên
 *   Body: { fullName, phone, password, role }
 * Chỉ MANAGER / LANDLORD.
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as staffService from '@/services/staff.service';

export async function GET(req: NextRequest) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { searchParams } = req.nextUrl;
    const data = await staffService.getStaffAccounts({
      status: searchParams.get('status') ?? undefined,
      search: searchParams.get('search') ?? undefined,
      role: searchParams.get('role') ?? undefined,
    });
    return jsonSuccess('Lấy danh sách nhân viên thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}

export async function POST(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const body = await req.json();
    const data = await staffService.registerStaffAccount(auth.id, body);
    return jsonSuccess('Tạo tài khoản nhân viên thành công.', data, 201);
  } catch (error) {
    return jsonError(error);
  }
}
