/**
 * GET /api/tasks - UC22: Danh sách công việc
 *   Query: ?status=ASSIGNED|IN_PROGRESS|COMPLETED|CANCELLED|ACTIVE
 *   (ACTIVE = ASSIGNED + IN_PROGRESS - tab "Đang làm" trên mobile)
 *   - Staff (SECURITY_GUARD/JANITOR/TECHNICIAN): task của chính mình (BR-42).
 *   - MANAGER/LANDLORD: toàn bộ task (BR-39, chỉ đọc).
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as taskService from '@/services/task.service';

export async function GET(req: NextRequest) {
  try {
    const auth = await requireAuth(req, [
      'SECURITY_GUARD',
      'JANITOR',
      'TECHNICIAN',
      'MANAGER',
      'LANDLORD',
    ]);
    const { searchParams } = req.nextUrl;
    const data = await taskService.getTasks(auth.id, auth.roles, {
      status: searchParams.get('status') ?? undefined,
    });
    return jsonSuccess('Lấy danh sách công việc thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
