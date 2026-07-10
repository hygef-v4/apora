import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../../../core/network/dio_client.dart';

final communicationRepositoryProvider = Provider((ref) {
  return CommunicationRepository(ref.read(dioClientProvider));
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
      formData.files.add(MapEntry(
        'banner',
        await MultipartFile.fromFile(bannerImage.path),
      ));
    }

    await _dio.post('/notifications/announce', data: formData);
  }

  Future<List<NotificationModel>> getNotifications({int limit = 20, int offset = 0}) async {
    final response = await _dio.get('/notifications', queryParameters: {
      'limit': limit,
      'offset': offset,
    });
    
    final data = response.data['data'] as List;
    return data.map((json) => NotificationModel.fromJson(json)).toList();
  }

  Future<void> markAsRead(int notificationId) async {
    await _dio.patch('/notifications/$notificationId/read');
  }
}
