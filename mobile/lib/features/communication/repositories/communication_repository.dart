import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../../../core/network/dio_client.dart';

final communicationRepositoryProvider = Provider((ref) {
  return CommunicationRepository(ref.read(dioProvider));
});

class CommunicationRepository {
  final Dio _dio;

  CommunicationRepository(this._dio);

  Future<void> announceNotification({
    required String title,
    required String body,
    File? bannerImage,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      'body': body,
    });

    if (bannerImage != null) {
      final fileName = bannerImage.path.split(RegExp(r'[/\\]')).last;
      formData.files.add(MapEntry(
        'banner',
        await MultipartFile.fromFile(
          bannerImage.path,
          filename: fileName,
        ),
      ));
    }

    await _dio.post('/notifications/announce', data: formData);
  }

  Future<List<NotificationModel>> getNotifications({int limit = 20, int offset = 0}) async {
    final response = await _dio.get('/notifications', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    
    debugPrint('GET /notifications response: ${response.data}');
    
    if (response.data['status'] == 'error') {
      throw Exception(response.data['message'] ?? 'Lỗi từ server');
    }

    final data = response.data['data'];
    if (data == null) return [];
    
    final list = data as List;
    final notifications = list.map((json) => NotificationModel.fromJson(json)).toList();
    // Đảm bảo sắp xếp mới nhất lên đầu theo BR-52
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Future<void> markAsRead(int notificationId) async {
    await _dio.patch('/notifications/$notificationId/read');
  }
}
