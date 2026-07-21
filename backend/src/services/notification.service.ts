import * as NotificationRepo from '../repositories/notification.repository';
import { sendPushNotification } from './firebase.service';

/**
 * Đăng thông báo chung (UC24).
 * Sẽ gửi cho tất cả users.
 */
export async function publishAnnouncement(
  senderId: number,
  title: string,
  body: string,
  bannerUrl?: string
): Promise<void> {
  // 1. Lưu tin tức trước và lấy id bài đăng
  const newsId = await NotificationRepo.createNews(
    senderId,
    title,
    body,
    bannerUrl || null
  );

  // 2. Lấy danh sách tất cả user để lưu vào DB (để ai cũng xem được trên app)
  const allUserIds = await NotificationRepo.getAllUserIdsToNotify();
  
  // 3. Lưu thông báo vào database cho TẤT CẢ mọi người với reference_id trỏ đến bài tin tức
  if (allUserIds.length > 0) {
    await NotificationRepo.createNotificationsBulk(
      allUserIds,
      title,
      body,
      'NEWS',
      newsId
    );

    // Đánh dấu là đã đọc luôn cho người gửi để không bị nhảy số đếm thông báo
    await NotificationRepo.markSenderAnnouncementsAsRead(senderId);
  }

  // 3. Lấy device tokens của NHỮNG NGƯỜI LÀ CƯ DÂN để gửi Push (không gửi cho staff/admin/owner)
  const residentIds = await NotificationRepo.getResidentUserIdsToNotify();
  
  if (residentIds.length > 0) {
    let tokens = await NotificationRepo.getActiveDeviceTokens(residentIds);

    // BẮT BUỘC: Lấy các device tokens của chính người gửi, và loại bỏ chúng khỏi danh sách tokens.
    // Điều này ngăn chặn lỗi "admin vẫn nhận được push notification" nếu token của admin vô tình bị trùng/lưu cho 1 tài khoản cư dân (do login trên cùng 1 máy).
    const senderTokens = await NotificationRepo.getActiveDeviceTokens([senderId]);
    if (senderTokens.length > 0) {
      tokens = tokens.filter(t => !senderTokens.includes(t));
    }

    // 4. Gửi push notification bất đồng bộ
    if (tokens.length > 0) {
      sendPushNotification(tokens, title, body, {
        type: 'NEWS',
        bannerUrl: bannerUrl || '',
        referenceId: String(newsId),
      }).catch((err) => {
        console.error('Lỗi khi gửi Push Notification:', err);
      });
    }
  }
}

/**
 * Lấy danh sách thông báo của 1 user (UC25).
 */
export async function getUserNotifications(
  userId: number,
  limit: number = 20,
  offset: number = 0
): Promise<any[]> {
  return await NotificationRepo.getUserNotifications(userId, limit, offset);
}

/**
 * Đánh dấu thông báo là đã đọc (UC27).
 */
export async function markNotificationAsRead(
  notificationId: number,
  userId: number
): Promise<boolean> {
  return await NotificationRepo.markAsRead(notificationId, userId);
}
