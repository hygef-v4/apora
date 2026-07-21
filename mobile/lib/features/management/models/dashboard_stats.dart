class TicketStatusCounts {
  final int pending;
  final int processing;
  final int waitingRating;
  final int closed;

  TicketStatusCounts({
    required this.pending,
    required this.processing,
    required this.waitingRating,
    required this.closed,
  });

  factory TicketStatusCounts.empty() => TicketStatusCounts(
        pending: 0,
        processing: 0,
        waitingRating: 0,
        closed: 0,
      );

  factory TicketStatusCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return TicketStatusCounts.empty();
    return TicketStatusCounts(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      processing: (json['processing'] as num?)?.toInt() ?? 0,
      waitingRating: (json['waiting_rating'] as num?)?.toInt() ?? 0,
      closed: (json['closed'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecentActivityItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String createdAt;

  RecentActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });

  factory RecentActivityItem.fromJson(Map<String, dynamic> json) {
    return RecentActivityItem(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'TICKET',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Model đại diện cho số liệu thống kê Dashboard (UC35).
class DashboardStats {
  final double totalRevenue;
  final double collectedRevenue;
  final int unpaidBillsCount;
  final int unresolvedTicketsCount;
  final TicketStatusCounts? _ticketStatusCounts;
  final List<RecentActivityItem>? _recentActivities;

  DashboardStats({
    required this.totalRevenue,
    required this.collectedRevenue,
    required this.unpaidBillsCount,
    required this.unresolvedTicketsCount,
    TicketStatusCounts? ticketStatusCounts,
    List<RecentActivityItem>? recentActivities,
  })  : _ticketStatusCounts = ticketStatusCounts,
        _recentActivities = recentActivities;

  TicketStatusCounts get ticketStatusCounts =>
      _ticketStatusCounts ?? TicketStatusCounts.empty();

  List<RecentActivityItem> get recentActivities =>
      _recentActivities ?? const [];

  /// Trả về DTO rỗng / an toàn khi không có dữ liệu (BR-09)
  factory DashboardStats.empty() {
    return DashboardStats(
      totalRevenue: 0.0,
      collectedRevenue: 0.0,
      unpaidBillsCount: 0,
      unresolvedTicketsCount: 0,
      ticketStatusCounts: TicketStatusCounts.empty(),
      recentActivities: const [],
    );
  }

  factory DashboardStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DashboardStats.empty();
    return DashboardStats(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      collectedRevenue: (json['collected_revenue'] as num?)?.toDouble() ?? 0.0,
      unpaidBillsCount: json['unpaid_bills_count'] as int? ?? 0,
      unresolvedTicketsCount: json['unresolved_tickets_count'] as int? ?? 0,
      ticketStatusCounts: TicketStatusCounts.fromJson(
        json['ticket_status_counts'] as Map<String, dynamic>?,
      ),
      recentActivities: (json['recent_activities'] as List<dynamic>?)
              ?.map((e) => RecentActivityItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
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


