/// Aggregate statistics for Manager accounts (UC41 - Summary Cards).
///
/// Maps to the `ManagerStats` DTO returned alongside the manager list
/// from `GET /api/managers`.
class ManagerStats {
  const ManagerStats({
    required this.total,
    required this.active,
    required this.inactive,
  });

  final int total;
  final int active;
  final int inactive;

  /// Deserializes from the API response JSON.
  factory ManagerStats.fromJson(Map<String, dynamic> json) {
    return ManagerStats(
      total: json['total'] as int,
      active: json['active'] as int,
      inactive: json['inactive'] as int,
    );
  }

  /// Empty placeholder used when data is still loading.
  static const empty = ManagerStats(total: 0, active: 0, inactive: 0);
}
