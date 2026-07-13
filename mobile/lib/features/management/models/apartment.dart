import '../../roommate/models/roommate.dart';

/// Model căn hộ phục vụ danh sách (UC29).
class Apartment {
  final int id;
  final String unitNumber;
  final String floor;
  final String status; // 'EMPTY' | 'OCCUPIED' | 'INACTIVE'
  final double areaSize;
  final double baseRent;
  final int? ownerId;
  final String? ownerName;
  final String? ownerPhone;
  final int unpaidInvoiceCount;
  final int unresolvedTicketCount;

  Apartment({
    required this.id,
    required this.unitNumber,
    required this.floor,
    required this.status,
    required this.areaSize,
    required this.baseRent,
    this.ownerId,
    this.ownerName,
    this.ownerPhone,
    required this.unpaidInvoiceCount,
    required this.unresolvedTicketCount,
  });

  factory Apartment.fromJson(Map<String, dynamic> json) {
    return Apartment(
      id: json['id'] as int,
      unitNumber: json['unit_number'] as String,
      floor: json['floor'] as String,
      status: json['status'] as String,
      areaSize: (json['area_size'] as num?)?.toDouble() ?? 0.0,
      baseRent: (json['base_rent'] as num?)?.toDouble() ?? 0.0,
      ownerId: json['owner_id'] as int?,
      ownerName: json['owner_name'] as String?,
      ownerPhone: json['owner_phone'] as String?,
      unpaidInvoiceCount: json['unpaid_invoice_count'] as int? ?? 0,
      unresolvedTicketCount: json['unresolved_ticket_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unit_number': unitNumber,
      'floor': floor,
      'status': status,
      'area_size': areaSize,
      'base_rent': baseRent,
      'owner_id': ownerId,
      'owner_name': ownerName,
      'owner_phone': ownerPhone,
      'unpaid_invoice_count': unpaidInvoiceCount,
      'unresolved_ticket_count': unresolvedTicketCount,
    };
  }
}

/// Model chi tiết căn hộ phục vụ UC30.
class ApartmentDetail {
  final int id;
  final String unitNumber;
  final String floor;
  final String status;
  final double areaSize;
  final double baseRent;
  final int? ownerId;
  final String? ownerName;
  final String? ownerPhone;
  final List<Roommate> roommates;
  final List<RecentBill>? recentBills; // null đối với Security Guard
  final List<RecentTicket> recentTickets;

  ApartmentDetail({
    required this.id,
    required this.unitNumber,
    required this.floor,
    required this.status,
    required this.areaSize,
    required this.baseRent,
    this.ownerId,
    this.ownerName,
    this.ownerPhone,
    required this.roommates,
    this.recentBills,
    required this.recentTickets,
  });

  factory ApartmentDetail.fromJson(Map<String, dynamic> json) {
    final roommatesList = (json['roommates'] as List<dynamic>?)
            ?.map((e) => Roommate.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    final billsList = json['recent_bills'] != null
        ? (json['recent_bills'] as List<dynamic>)
            .map((e) => RecentBill.fromJson(e as Map<String, dynamic>))
            .toList()
        : null;

    final ticketsList = (json['recent_tickets'] as List<dynamic>?)
            ?.map((e) => RecentTicket.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return ApartmentDetail(
      id: json['id'] as int,
      unitNumber: json['unit_number'] as String,
      floor: json['floor'] as String,
      status: json['status'] as String,
      areaSize: (json['area_size'] as num?)?.toDouble() ?? 0.0,
      baseRent: (json['base_rent'] as num?)?.toDouble() ?? 0.0,
      ownerId: json['owner_id'] as int?,
      ownerName: json['owner_name'] as String?,
      ownerPhone: json['owner_phone'] as String?,
      roommates: roommatesList,
      recentBills: billsList,
      recentTickets: ticketsList,
    );
  }
}

/// Model hoá đơn gần đây nhúng trong chi tiết căn hộ.
class RecentBill {
  final int id;
  final String monthYear;
  final double totalAmount;
  final String status;
  final DateTime createdAt;

  RecentBill({
    required this.id,
    required this.monthYear,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  factory RecentBill.fromJson(Map<String, dynamic> json) {
    return RecentBill(
      id: json['id'] as int,
      monthYear: json['month_year'] as String,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Model ticket gần đây nhúng trong chi tiết căn hộ.
class RecentTicket {
  final int id;
  final String category;
  final String description;
  final String status;
  final DateTime createdAt;

  RecentTicket({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory RecentTicket.fromJson(Map<String, dynamic> json) {
    return RecentTicket(
      id: json['id'] as int,
      category: json['category'] as String,
      description: json['description'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
