/**
 * Upload Helpers - đọc & validate file ảnh từ multipart/form-data
 *
 * BR-10: mobile đã nén < 500KB trước khi gửi, nhưng server vẫn phải
 * validate phòng thủ (không tin client): đúng định dạng JPG/PNG và
 * không vượt trần 5MB (theo tinh thần BR-37).
 */

import { HttpError } from '@/lib/middleware';

const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png'];

/** Validate 1 file ảnh (loại + kích thước), ném HttpError 400 nếu sai (BR-37). */
function assertValidImage(file: File): void {
  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    throw new HttpError(400, 'Invalid image. Only JPG or PNG files are accepted.');
  }
  if (file.size > MAX_IMAGE_SIZE_BYTES) {
    throw new HttpError(400, 'Image is too large. The maximum size is 5MB.');
  }
}

/**
 * Đọc field ảnh từ FormData thành Buffer, kèm validate loại/kích thước.
 * @returns undefined nếu field không được gửi lên (không bắt buộc).
 * @throws HttpError 400 nếu file sai định dạng hoặc quá lớn.
 */
export async function readImageUpload(
  form: FormData,
  field: string,
): Promise<Buffer | undefined> {
  const file = form.get(field);
  if (!(file instanceof File) || file.size === 0) return undefined;

  assertValidImage(file);
  return Buffer.from(await file.arrayBuffer());
}

/**
 * Đọc NHIỀU ảnh cùng field (form.getAll) thành mảng Buffer.
 * Dùng cho ảnh sự cố (UC19) / ảnh nghiệm thu (UC23).
 * @throws HttpError 400 nếu vượt maxCount hoặc bất kỳ ảnh nào sai định dạng/kích thước.
 */
export async function readImageUploads(
  form: FormData,
  field: string,
  maxCount: number,
): Promise<Buffer[]> {
  const files = form
    .getAll(field)
    .filter((f): f is File => f instanceof File && f.size > 0);

  if (files.length > maxCount) {
    throw new HttpError(400, `You can attach at most ${maxCount} image(s).`);
  }

  const buffers: Buffer[] = [];
  for (const file of files) {
    assertValidImage(file);
    buffers.push(Buffer.from(await file.arrayBuffer()));
  }
  return buffers;
}
