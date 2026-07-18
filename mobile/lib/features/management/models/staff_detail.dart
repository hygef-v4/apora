import 'staff_member.dart';

/// 1 task đang mở của nhân viên (UC37 - Open Assigned Tickets List).
class StaffOpenTask {
  const StaffOpenTask({
    required this.id,
    required this.title,
    required this.status,
    this.category,
  });

  final int id;
  final String title;
  final String status;
  final String? category;

  factory StaffOpenTask.fromJson(Map<String, dynamic> json) {
    return StaffOpenTask(
      id: json['id'] as int,
      title: json['title'] as String,
      status: json['status'] as String,
      category: json['category'] as String?,
    );
  }
}

/// Chi tiết nhân viên (UC37) = hồ sơ + task đang mở + cờ được phép deactivate (BR-50).
class StaffDetail {
  const StaffDetail({
    required this.member,
    required this.canDeactivate,
    required this.openTasks,
    this.createdAt,
  });

  final StaffMember member;
  final bool canDeactivate;
  final List<StaffOpenTask> openTasks;
  final DateTime? createdAt;

  factory StaffDetail.fromJson(Map<String, dynamic> json) {
    return StaffDetail(
      member: StaffMember.fromJson(json),
      canDeactivate: (json['canDeactivate'] as bool?) ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      openTasks: (json['openTasks'] as List<dynamic>? ?? const [])
          .map((e) => StaffOpenTask.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
