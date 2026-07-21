import 'package:flutter/foundation.dart';

class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String type;
  final int? referenceId;
  final bool isRead;
  final DateTime createdAt;
  final String? imageUrl;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
    this.imageUrl,
  });

  NotificationModel copyWith({
    int? id,
    String? title,
    String? body,
    String? type,
    int? referenceId,
    bool? isRead,
    DateTime? createdAt,
    String? imageUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    try {
      return NotificationModel(
        id: json['id'] as int? ?? 0,
        title: json['title'] as String? ?? 'Không có tiêu đề',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? 'NEWS',
        referenceId: json['reference_id'] as int?,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'].toString()) 
            : DateTime.now(),
        imageUrl: json['image_url'] as String?,
      );
    } catch (e) {
      debugPrint('Error parsing NotificationModel: $e');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }
}
