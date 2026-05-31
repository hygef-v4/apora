/**
 * Cloudinary Configuration
 *
 * Quản lý upload/xóa hình ảnh:
 * - Avatar user (UC03)
 * - Ảnh CCCD người ở ghép (UC04)
 * - Ảnh hiện trường sự cố (UC09)
 * - Ảnh nghiệm thu Staff (UC11)
 *
 * ⚠️ LƯU Ý:
 * - Khi Checkout (UC18), phải gọi API destroy() để xóa vĩnh viễn ảnh CCCD
 * - Mobile App PHẢI nén ảnh < 500KB trước khi upload
 *
 * @see PRM393 - Mục "Tối ưu dung lượng hình ảnh"
 */

// TODO: Implement
// import { v2 as cloudinary } from 'cloudinary';
//
// cloudinary.config({
//   cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
//   api_key: process.env.CLOUDINARY_API_KEY,
//   api_secret: process.env.CLOUDINARY_API_SECRET,
// });
//
// export default cloudinary;

export {};
