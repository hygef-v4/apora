/**
 * GET /api/tasks/:id - UC23: Chi tiết công việc
 *   Kèm ngữ cảnh sự cố cha (mô tả, ảnh gốc, phòng, người báo).
 *   BR-42: chỉ nhân viên được giao hoặc MANAGER/LANDLORD.
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as taskService from '@/services/task.service';

function parseTaskId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Mã công việc không hợp lệ.');
  }
  return id;
}

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const auth = await requireAuth(req, [
      'SECURITY_GUARD',
      'JANITOR',
      'TECHNICIAN',
      'MANAGER',
      'LANDLORD',
    ]);
    const { id } = await params;
    const data = await taskService.getTaskDetail(auth.id, auth.roles, parseTaskId(id));
    return jsonSuccess('Lấy chi tiết công việc thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
