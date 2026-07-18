import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatRepository(dio);
});

class ChatRepository {
  final Dio _dio;

  ChatRepository(this._dio);

  Future<List<ChatSessionModel>> getChatSessions({int limit = 20, int offset = 0}) async {
    try {
      final response = await _dio.get('/chat/sessions', queryParameters: {
        'limit': limit,
        'offset': offset,
      });

      if (response.data['status'] == 'error') {
        throw Exception(response.data['message']);
      }

      final data = response.data['data'] as List?;
      if (data == null) return [];

      return data.map((json) => ChatSessionModel.fromJson(json)).toList();
    } catch (e) {
      // Return empty or throw based on your requirement
      // throw Exception('Không thể tải danh sách cuộc trò chuyện: $e');
      return []; // Return empty list for now if backend is not ready
    }
  }

  Future<List<ChatMessageModel>> getMessages(int? partnerId, {int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get('/chat/messages', queryParameters: {
        'partner_id': ?partnerId,
        'limit': limit,
        'offset': offset,
      });

      if (response.data['status'] == 'error') {
        throw Exception(response.data['message']);
      }

      final data = response.data['data'] as List?;
      if (data == null) return [];

      final messages = data.map((json) => ChatMessageModel.fromJson(json)).toList();
      // Server should ideally sort by createdAt DESC, but we can enforce it here
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return messages;
    } catch (e) {
      return []; // Return empty list if backend is not ready
    }
  }

  Future<ChatMessageModel> sendMessage({
    int? receiverId,
    String? content,
    File? image,
  }) async {
    try {
      final formData = FormData();

      if (receiverId != null) {
        formData.fields.add(MapEntry('receiver_id', receiverId.toString()));
      }
      if (content != null && content.isNotEmpty) {
        formData.fields.add(MapEntry('content', content));
      }
      if (image != null) {
        formData.files.add(MapEntry(
          'image',
          await MultipartFile.fromFile(image.path),
        ));
      }

      final response = await _dio.post('/chat/messages', data: formData);

      if (response.data['status'] == 'error') {
        throw Exception(response.data['message']);
      }

      return ChatMessageModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('Lỗi khi gửi tin nhắn: $e');
    }
  }

  Future<void> markAsRead(int? partnerId) async {
    try {
      await _dio.patch('/chat/read', data: {
        'partner_id': ?partnerId,
      });
    } catch (e) {
      // Ignore errors for mark as read if backend not ready
    }
  }
}
