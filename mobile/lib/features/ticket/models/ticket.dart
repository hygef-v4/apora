/// Model sự cố (Module 4 - UC18).
/// Khớp DTO TicketListItem của backend (camelCase).
class Ticket {
  final int id;
  final String category;
  final String description;
  final List<String> beforeImages;
  final String status; // PENDING | ASSIGNED | PROCESSING | RESOLVED | CANCELLED
  final String unitNumber;
  /// FID-18 field 8: tên cư dân báo sự cố.
  final String reporterName;
  /// FID-18 field 9: nhân viên đang được giao; null khi chưa phân công.
  final String? assigneeName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ticket({
    required this.id,
    required this.category,
    required this.description,
    required this.beforeImages,
    required this.status,
    required this.unitNumber,
    required this.reporterName,
    this.assigneeName,
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
      reporterName: json['residentName'] as String? ?? '',
      assigneeName: json['assigneeName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Tóm tắt công việc gắn với sự cố (UC20/UC21) - khớp DTO TaskSummary.
class TaskSummary {
  final int id;
  final int assignedTo;
  final String assigneeName;
  final String? assigneePhone;
  final String title;
  final String status; // ASSIGNED | IN_PROGRESS | COMPLETED | CANCELLED
  final DateTime assignedAt;
  final DateTime? completedAt;

  TaskSummary({
    required this.id,
    required this.assignedTo,
    required this.assigneeName,
    this.assigneePhone,
    required this.title,
    required this.status,
    required this.assignedAt,
    this.completedAt,
  });

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    return TaskSummary(
      id: json['id'] as int,
      assignedTo: json['assignedTo'] as int,
      assigneeName: json['assigneeName'] as String,
      assigneePhone: json['assigneePhone'] as String?,
      title: json['title'] as String,
      status: json['status'] as String,
      assignedAt: DateTime.parse(json['assignedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );
  }
}

/// Chi tiết sự cố (UC20) - khớp DTO TicketDetail của backend.
/// internalNotes luôn null khi người xem là RESIDENT (backend ẩn - BR-39).
class TicketDetail extends Ticket {
  final int residentId;
  final String residentName;
  final String residentPhone;
  final String? internalNotes;
  final TaskSummary? assignedTask;

  TicketDetail({
    required super.id,
    required super.category,
    required super.description,
    required super.beforeImages,
    required super.status,
    required super.unitNumber,
    required super.reporterName,
    super.assigneeName,
    required super.createdAt,
    required super.updatedAt,
    required this.residentId,
    required this.residentName,
    required this.residentPhone,
    this.internalNotes,
    this.assignedTask,
  });

  factory TicketDetail.fromJson(Map<String, dynamic> json) {
    final base = Ticket.fromJson(json);
    return TicketDetail(
      id: base.id,
      category: base.category,
      description: base.description,
      beforeImages: base.beforeImages,
      status: base.status,
      unitNumber: base.unitNumber,
      reporterName: base.reporterName,
      assigneeName: base.assigneeName,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      residentId: json['residentId'] as int,
      residentName: json['residentName'] as String,
      residentPhone: json['residentPhone'] as String,
      internalNotes: json['internalNotes'] as String?,
      assignedTask: json['assignedTask'] == null
          ? null
          : TaskSummary.fromJson(json['assignedTask'] as Map<String, dynamic>),
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

/// Nhãn tiếng Việt cho trạng thái công việc của nhân viên (UC20/UC22).
const Map<String, String> kTaskStatusLabels = {
  'ASSIGNED': 'Đã phân công',
  'IN_PROGRESS': 'Đang làm',
  'COMPLETED': 'Hoàn thành',
  'CANCELLED': 'Đã hủy',
};

/// BR-40: các bước đổi trạng thái THỦ CÔNG hợp lệ ở dropdown UC20.
/// Lưu ý: PENDING -> ASSIGNED KHÔNG nằm ở đây vì "Đã phân công" chỉ được đặt
/// qua chức năng Phân công (UC21) - nơi task + người xử lý được tạo cùng lúc.
/// Cho ASSIGNED vào dropdown sẽ tạo ticket "đã phân công" mà không có ai làm.
const Map<String, List<String>> kTicketNextStatuses = {
  'PENDING': ['CANCELLED'],
  'ASSIGNED': ['PROCESSING'],
  'PROCESSING': ['RESOLVED'],
  'RESOLVED': [],
  'CANCELLED': [],
};
