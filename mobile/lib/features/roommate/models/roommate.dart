import '../../../core/utils/mask_utils.dart';

class Roommate {
  final int id;
  final int apartmentId;
  final String fullName;
  final String? phoneNumber;
  final String cccdNumber;

  /// Số CCCD đã được mask theo BR-08 (ví dụ: `********5678`)
  String get maskedCccdNumber => maskCccdNumber(cccdNumber);
  final String? cccdFrontUrl;
  final String? cccdBackUrl;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final DateTime createdAt;
  final String? unitNumber; // Trả về thêm ở danh sách chờ duyệt của quản lý
  final String? rejectionReason; // Lý do từ chối lấy từ audit logs

  Roommate({
    required this.id,
    required this.apartmentId,
    required this.fullName,
    this.phoneNumber,
    required this.cccdNumber,
    this.cccdFrontUrl,
    this.cccdBackUrl,
    required this.status,
    required this.createdAt,
    this.unitNumber,
    this.rejectionReason,
  });

  factory Roommate.fromJson(Map<String, dynamic> json) {
    return Roommate(
      id: json['id'] as int? ?? 0,
      apartmentId: json['apartment_id'] as int? ?? 0,
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      cccdNumber: json['cccd_number'] as String? ?? '',
      cccdFrontUrl: json['cccd_front_url'] as String?,
      cccdBackUrl: json['cccd_back_url'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unitNumber: json['unit_number'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartment_id': apartmentId,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'cccd_number': cccdNumber,
      'cccd_front_url': cccdFrontUrl,
      'cccd_back_url': cccdBackUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'unit_number': unitNumber,
      'rejection_reason': rejectionReason,
    };
  }
}
