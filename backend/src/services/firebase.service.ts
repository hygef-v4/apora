/**
 * Firebase Cloud Messaging (FCM) Service
 * 
 * Đây là cấu hình mẫu (dummy config) cho Push Notification.
 * Để chạy thật, bạn cần:
 * 1. Cài đặt package `firebase-admin`
 * 2. Tải file serviceAccountKey.json từ Firebase Console
 */

export async function sendPushNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;

  console.log(`[FCM Mock] Đang gửi thông báo tới ${tokens.length} thiết bị...`);
  console.log(`[FCM Mock] Title: ${title}`);
  console.log(`[FCM Mock] Body: ${body}`);
  if (data) console.log(`[FCM Mock] Data:`, data);
}
