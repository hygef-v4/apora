/// Model sự cố (Module 4 - UC18).
/// Khớp DTO TicketListItem của backend (camelCase).
class Ticket {
  final int id;
  final String category;
  final String description;
  final List<String> beforeImages;
  final String status; // PENDING | ASSIGNED | PROCESSING | RESOLVED | CANCELLED
  final String unitNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ticket({
    required this.id,
    required this.category,
    required this.description,
    required this.beforeImages,
    required this.status,
    required this.unitNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as int,
      category: json['category'] as String,
      description: json['description'] as String,
      beforeImages:
          (json['beforeImages'] as List?)?.map((e) => e as String).toList() ?? const [],
      status: json['status'] as String,
      unitNumber: json['unitNumber'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Nhãn tiếng Việt cho từng trạng thái sự cố (dùng cho badge/hiển thị).
const Map<String, String> kTicketStatusLabels = {
  'PENDING': 'Chờ xử lý',
  'ASSIGNED': 'Đã phân công',
  'PROCESSING': 'Đang xử lý',
  'RESOLVED': 'Đã xong',
  'CANCELLED': 'Đã hủy',
};
