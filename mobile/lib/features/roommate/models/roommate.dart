class Roommate {
  final int id;
  final int apartmentId;
  final String fullName;
  final String? phoneNumber;
  final String cccdNumber;
  final String? cccdFrontUrl;
  final String? cccdBackUrl;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final DateTime createdAt;
  final String? unitNumber; // Trả về thêm ở danh sách chờ duyệt của quản lý

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
  });

  factory Roommate.fromJson(Map<String, dynamic> json) {
    return Roommate(
      id: json['id'] as int,
      apartmentId: json['apartment_id'] as int,
      fullName: json['full_name'] as String,
      phoneNumber: json['phone_number'] as String?,
      cccdNumber: json['cccd_number'] as String,
      cccdFrontUrl: json['cccd_front_url'] as String?,
      cccdBackUrl: json['cccd_back_url'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      unitNumber: json['unit_number'] as String?,
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
    };
  }
}
