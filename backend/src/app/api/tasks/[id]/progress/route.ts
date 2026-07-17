/**
 * PUT /api/tasks/:id/progress - UC23: Cập nhật tiến độ công việc
 *   Body multipart: { status (IN_PROGRESS|COMPLETED), progressNotes?,
 *   images[] (ảnh nghiệm thu - bắt buộc ≥1 khi COMPLETED theo BR-43,
 *   tối đa 3, JPG/PNG ≤5MB theo BR-37) }
 *   Chỉ nhân viên vận hành, và phải là người được giao task (BR-42).
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import { readImageUploads } from '@/lib/upload';
import * as taskService from '@/services/task.service';

function parseTaskId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Mã công việc không hợp lệ.');
  }
  return id;
}

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const auth = await requireAuth(req, ['SECURITY_GUARD', 'JANITOR', 'TECHNICIAN']);
    const { id } = await params;

    const form = await req.formData().catch(() => {
      throw new HttpError(400, 'Dữ liệu gửi lên không hợp lệ (yêu cầu multipart/form-data).');
    });
    // BR-37: tối đa 3 ảnh, validate loại/kích thước tại đây trước khi vào service
    const imageBuffers = await readImageUploads(form, 'images', 3);

    const data = await taskService.updateTaskProgress(
      auth.id,
      parseTaskId(id),
      {
        status: form.get('status')?.toString(),
        progressNotes: form.get('progressNotes')?.toString(),
      },
      imageBuffers,
    );
    return jsonSuccess('Cập nhật tiến độ công việc thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
