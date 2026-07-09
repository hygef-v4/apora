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

  if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
    throw new HttpError(400, 'Ảnh không hợp lệ. Chỉ chấp nhận định dạng JPG hoặc PNG.');
  }
  if (file.size > MAX_IMAGE_SIZE_BYTES) {
    throw new HttpError(400, 'Ảnh quá lớn. Kích thước tối đa là 5MB.');
  }

  return Buffer.from(await file.arrayBuffer());
}
