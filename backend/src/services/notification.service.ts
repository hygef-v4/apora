import * as NotificationRepo from '../repositories/notification.repository';
import { sendPushNotification } from './firebase.service';

/**
 * Đăng thông báo chung (UC24).
 * Sẽ gửi cho tất cả users.
 */
export async function publishAnnouncement(
  title: string,
  body: string,
  bannerUrl?: string
): Promise<void> {
  // 1. Lấy danh sách tất cả người dùng để nhận thông báo
  const userIds = await NotificationRepo.getAllUserIdsToNotify();
  
  if (userIds.length === 0) {
    return;
  }

  // 2. Lưu thông báo vào database cho từng user
  await NotificationRepo.createNotificationsBulk(
    userIds,
    title,
    body,
    'NEWS',
    null // Không có reference cụ thể cho thông báo chung
  );

  // 3. Lấy device tokens của users
  const tokens = await NotificationRepo.getActiveDeviceTokens(userIds);

  // 4. Gửi push notification bất đồng bộ
  sendPushNotification(tokens, title, body, {
    type: 'NEWS',
    bannerUrl: bannerUrl || '',
  }).catch((err) => {
    console.error('Lỗi khi gửi Push Notification:', err);
  });
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
