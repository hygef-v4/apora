class ChatSessionModel {
  final int residentId;
  final String residentName;
  final String lastMessage;
  final bool isLastMessageImage;
  final int unreadCount;
  final DateTime updatedAt;

  ChatSessionModel({
    required this.residentId,
    required this.residentName,
    required this.lastMessage,
    this.isLastMessageImage = false,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory ChatSessionModel.fromJson(Map<String, dynamic> json) {
    return ChatSessionModel(
      residentId: json['resident_id'],
      residentName: json['resident_name'],
      lastMessage: json['last_message'],
      isLastMessageImage: json['is_last_message_image'] ?? false,
      unreadCount: json['unread_count'] ?? 0,
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  ChatSessionModel copyWith({
    int? residentId,
    String? residentName,
    String? lastMessage,
    bool? isLastMessageImage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return ChatSessionModel(
      residentId: residentId ?? this.residentId,
      residentName: residentName ?? this.residentName,
      lastMessage: lastMessage ?? this.lastMessage,
      isLastMessageImage: isLastMessageImage ?? this.isLastMessageImage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resident_id': residentId,
      'resident_name': residentName,
      'last_message': lastMessage,
      'is_last_message_image': isLastMessageImage,
      'unread_count': unreadCount,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
