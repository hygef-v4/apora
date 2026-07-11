class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String type;
  final int? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

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
      );
    } catch (e) {
      print('Error parsing NotificationModel: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}
