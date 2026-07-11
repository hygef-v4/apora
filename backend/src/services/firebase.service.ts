import { initializeApp, getApps, cert, applicationDefault } from 'firebase-admin/app';
import { getMessaging, MulticastMessage } from 'firebase-admin/messaging';
import path from 'path';
import fs from 'fs';

// Khởi tạo Firebase Admin SDK (Singleton)
if (!getApps().length) {
  try {
    // Để chạy thật, bạn tạo file `serviceAccountKey.json` ở thư mục gốc của backend (cùng cấp với package.json)
    const serviceAccountPath = path.resolve(process.cwd(), process.env.FIREBASE_SERVICE_ACCOUNT_KEY || 'serviceAccountKey.json');
    
    if (fs.existsSync(serviceAccountPath)) {
      const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf-8'));
      
      initializeApp({
        credential: cert(serviceAccount),
      });
      console.log('[Firebase] Đã khởi tạo Firebase Admin SDK thành công từ cấu hình.');
    } else {
      console.warn('[Firebase] CẢNH BÁO: Không tìm thấy file JSON. Đang khởi tạo bằng môi trường mặc định (Application Default Credentials).');
      initializeApp({
        credential: applicationDefault(),
      });
    }
  } catch (error) {
    console.error('[Firebase] Lỗi khởi tạo Firebase Admin SDK:', error);
  }
}

/**
 * Gửi Push Notification tới nhiều thiết bị thông qua FCM
 */
export async function sendPushNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;

  try {
    // Sử dụng thư viện firebase-admin mới cài để tạo payload
    const message: MulticastMessage = {
      notification: {
        title,
        body,
      },
      data, // Custom data gửi kèm (ví dụ type, url, ID, bannerUrl...)
      tokens, // Danh sách FCM tokens
    };

    const response = await getMessaging().sendEachForMulticast(message);
    
    console.log(`[FCM] Đã gửi ${response.successCount} thành công, ${response.failureCount} thất bại.`);
    
    // Xử lý các token thất bại (Tùy chọn: Xóa các token chết khỏi DB nếu cần)
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`[FCM] Lỗi gửi token ${tokens[idx]}:`, resp.error);
          // Gợi ý: Nếu resp.error?.code === 'messaging/registration-token-not-registered' thì xóa token đó khỏi DB
        }
      });
    }
  } catch (error) {
    console.error('[FCM] Lỗi khi gọi sendEachForMulticast:', error);
  }
}
