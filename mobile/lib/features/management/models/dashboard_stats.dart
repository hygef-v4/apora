/// Model đại diện cho số liệu thống kê Dashboard (UC35).
class DashboardStats {
  final double totalRevenue;
  final double collectedRevenue;
  final int unpaidBillsCount;
  final int unresolvedTicketsCount;

  DashboardStats({
    required this.totalRevenue,
    required this.collectedRevenue,
    required this.unpaidBillsCount,
    required this.unresolvedTicketsCount,
  });

  /// Trả về DTO rỗng / an toàn khi không có dữ liệu (BR-09)
  factory DashboardStats.empty() {
    return DashboardStats(
      totalRevenue: 0.0,
      collectedRevenue: 0.0,
      unpaidBillsCount: 0,
      unresolvedTicketsCount: 0,
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      collectedRevenue: (json['collected_revenue'] as num?)?.toDouble() ?? 0.0,
      unpaidBillsCount: json['unpaid_bills_count'] as int? ?? 0,
      unresolvedTicketsCount: json['unresolved_tickets_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_revenue': totalRevenue,
      'collected_revenue': collectedRevenue,
      'unpaid_bills_count': unpaidBillsCount,
      'unresolved_tickets_count': unresolvedTicketsCount,
    };
  }

  /// Tỷ lệ nợ thu hồi (tiền đã thu / tổng tiền phải thu)
  double get collectionRate {
    if (totalRevenue <= 0.0) return 1.0;
    return collectedRevenue / totalRevenue;
  }

  /// Số tiền còn nợ chưa thu
  double get unpaidRevenue {
    final diff = totalRevenue - collectedRevenue;
    return diff > 0 ? diff : 0.0;
  }
}
