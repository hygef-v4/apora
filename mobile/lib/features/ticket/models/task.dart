/// 1 dòng công việc của nhân viên (UC22) - khớp DTO TaskListItem.
class TaskItem {
  final int id;
  final int ticketId;
  final String title;
  final String? description;
  final String status; // ASSIGNED | IN_PROGRESS | COMPLETED | CANCELLED
  final String category;
  final String unitNumber;
  final String assignedByName;
  final DateTime assignedAt;
  final DateTime? completedAt;

  TaskItem({
    required this.id,
    required this.ticketId,
    required this.title,
    this.description,
    required this.status,
    required this.category,
    required this.unitNumber,
    required this.assignedByName,
    required this.assignedAt,
    this.completedAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as int,
      ticketId: json['ticketId'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      category: json['category'] as String,
      unitNumber: json['unitNumber'] as String,
      assignedByName: json['assignedByName'] as String,
      assignedAt: DateTime.parse(json['assignedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
    );
  }
}

/// Chi tiết công việc (UC23) - kèm ngữ cảnh sự cố cha. Khớp DTO TaskDetail.
class TaskDetail extends TaskItem {
  final String ticketDescription;
  final List<String> ticketBeforeImages;
  final String residentName;
  final String? progressNotes;
  final List<String> completionImages;

  TaskDetail({
    required super.id,
    required super.ticketId,
    required super.title,
    super.description,
    required super.status,
    required super.category,
    required super.unitNumber,
    required super.assignedByName,
    required super.assignedAt,
    super.completedAt,
    required this.ticketDescription,
    required this.ticketBeforeImages,
    required this.residentName,
    this.progressNotes,
    required this.completionImages,
  });

  factory TaskDetail.fromJson(Map<String, dynamic> json) {
    final base = TaskItem.fromJson(json);
    return TaskDetail(
      id: base.id,
      ticketId: base.ticketId,
      title: base.title,
      description: base.description,
      status: base.status,
      category: base.category,
      unitNumber: base.unitNumber,
      assignedByName: base.assignedByName,
      assignedAt: base.assignedAt,
      completedAt: base.completedAt,
      ticketDescription: json['ticketDescription'] as String,
      ticketBeforeImages: (json['ticketBeforeImages'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      residentName: json['residentName'] as String,
      progressNotes: json['progressNotes'] as String?,
      completionImages: (json['completionImages'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Task còn thao tác được không (PRE-02 UC23).
  bool get isOpen => status == 'ASSIGNED' || status == 'IN_PROGRESS';
}

/// 1 nhân viên trong bảng phân công (UC21) - khớp DTO StaffWorkloadItem.
class StaffWorkload {
  final int id;
  final String fullName;
  final List<String> roles;
  final int openTaskCount;

  StaffWorkload({
    required this.id,
    required this.fullName,
    required this.roles,
    required this.openTaskCount,
  });

  factory StaffWorkload.fromJson(Map<String, dynamic> json) {
    return StaffWorkload(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      roles: (json['roles'] as List).map((e) => e as String).toList(),
      openTaskCount: json['openTaskCount'] as int,
    );
  }

  bool get isAvailable => openTaskCount == 0;
}

/// Nhãn tiếng Việt cho role nhân viên vận hành (hiển thị ở màn phân công).
const Map<String, String> kStaffRoleLabels = {
  'SECURITY_GUARD': 'Security Guard',
  'JANITOR': 'Janitor',
  'TECHNICIAN': 'Technician',
};
