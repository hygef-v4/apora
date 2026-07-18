class ChatMessageModel {
  final int id;
  final int senderId;
  final int? receiverId; // null means sent to Management Team (for resident's message) or to Resident (from Management)
  final String content;
  final bool isImage;
  final bool isRead;
  final DateTime createdAt;
  final String? senderName;
  final String? senderRole;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    this.receiverId,
    required this.content,
    this.isImage = false,
    this.isRead = false,
    required this.createdAt,
    this.senderName,
    this.senderRole,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      isImage: json['is_image'] ?? false,
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      senderName: json['sender_name'],
      senderRole: json['sender_role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'is_image': isImage,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'sender_name': senderName,
      'sender_role': senderRole,
    };
  }

  ChatMessageModel copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    String? content,
    bool? isImage,
    bool? isRead,
    DateTime? createdAt,
    String? senderName,
    String? senderRole,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      isImage: isImage ?? this.isImage,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
    );
  }
}
