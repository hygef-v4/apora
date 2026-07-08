/**
 * Cloudinary Configuration
 *
 * Quản lý upload/xóa hình ảnh:
 * - Avatar user (UC05)
 * - Ảnh CCCD người ở ghép, ảnh sự cố, ảnh nghiệm thu (module sau)
 *
 * ⚠️ LƯU Ý:
 * - Mobile App PHẢI nén ảnh < 500KB trước khi upload (BR-10)
 * - Khi Checkout phải gọi deleteImagesBatch() xóa vĩnh viễn ảnh CCCD (BR-20)
 */

import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

/** Upload 1 ảnh từ buffer, trả về secure URL. */
export function uploadImage(buffer: Buffer, folder: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder: `apora/${folder}`, resource_type: 'image' },
      (error, result?: UploadApiResponse) => {
        if (error || !result) {
          reject(error ?? new Error('Upload Cloudinary thất bại'));
        } else {
          resolve(result.secure_url);
        }
      },
    );
    stream.end(buffer);
  });
}

/** Xóa vĩnh viễn một loạt ảnh theo URL (BR-20, BR-38). */
export async function deleteImagesBatch(urls: string[]): Promise<void> {
  const publicIds = urls
    .map((url) => {
      // URL dạng .../upload/v123/apora/<folder>/<id>.<ext>
      const match = url.match(/\/upload\/(?:v\d+\/)?(.+)\.\w+$/);
      return match ? match[1] : null;
    })
    .filter((id): id is string => id !== null);

  if (publicIds.length > 0) {
    await cloudinary.api.delete_resources(publicIds);
  }
}

export default cloudinary;
