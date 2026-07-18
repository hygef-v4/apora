/// Thống kê tổng quan nhân sự (UC36 - Staff Statistics Summary).
class StaffStats {
  const StaffStats({
    required this.total,
    required this.active,
    required this.inactive,
    required this.openTasks,
  });

  final int total;
  final int active;
  final int inactive;
  final int openTasks;

  factory StaffStats.fromJson(Map<String, dynamic> json) {
    return StaffStats(
      total: json['total'] as int,
      active: json['active'] as int,
      inactive: json['inactive'] as int,
      openTasks: json['openTasks'] as int,
    );
  }

  static const empty = StaffStats(total: 0, active: 0, inactive: 0, openTasks: 0);
}
