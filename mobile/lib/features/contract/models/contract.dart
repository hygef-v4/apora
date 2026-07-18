/// Model Module 2: Hợp đồng & Gia hạn lưu trú (UC06-UC09).
/// Khớp DTO MyContractResponse / StayExtensionListItem / StayExtensionDetail.
library;

/// Thông tin căn hộ gắn với hợp đồng (UC06 - FID-09 field 1-3).
class ApartmentSummary {
  final int id;
  final String unitNumber;
  final String floor;
  final String status; // EMPTY | OCCUPIED | INACTIVE

  ApartmentSummary({
    required this.id,
    required this.unitNumber,
    required this.floor,
    required this.status,
  });

  factory ApartmentSummary.fromJson(Map<String, dynamic> json) {
    return ApartmentSummary(
      id: json['id'] as int,
      unitNumber: json['unitNumber'] as String,
      floor: json['floor'] as String,
      status: json['status'] as String,
    );
  }
}

/// Hợp đồng thuê của chính user (UC06 - FID-09 field 4-9).
class ContractInfo {
  final int id;
  final DateTime startDate;
  final DateTime endDate;
  final num baseRent;
  final String status; // ACTIVE | EXPIRED
  /// BR-13: backend tính động; null khi hợp đồng EXPIRED (BR-12).
  final int? remainingDays;
  /// Yêu cầu gia hạn PENDING đang chờ duyệt (nếu có) - để khóa nút gửi thêm.
  final int? pendingExtensionId;

  ContractInfo({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.baseRent,
    required this.status,
    this.remainingDays,
    this.pendingExtensionId,
  });

  bool get isActive => status == 'ACTIVE';

  /// Tỷ lệ thời gian đã trôi qua (0..1) cho progress bar FID-09 field 8.
  double get elapsedRatio {
    final total = endDate.difference(startDate).inDays;
    if (total <= 0) return 1;
    final elapsed = DateTime.now().difference(startDate).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  factory ContractInfo.fromJson(Map<String, dynamic> json) {
    return ContractInfo(
      id: json['id'] as int,
      startDate: DateTime.parse(json['startDate'] as String).toLocal(),
      endDate: DateTime.parse(json['endDate'] as String).toLocal(),
      baseRent: json['baseRent'] as num,
      status: json['status'] as String,
      remainingDays: json['remainingDays'] as int?,
      pendingExtensionId: json['pendingExtensionId'] as int?,
    );
  }
}

/// Response UC06: apartment/contract có thể null (AT2 - chưa có hợp đồng).
class MyContract {
  final ApartmentSummary? apartment;
  final ContractInfo? contract;

  MyContract({this.apartment, this.contract});

  factory MyContract.fromJson(Map<String, dynamic> json) {
    return MyContract(
      apartment: json['apartment'] == null
          ? null
          : ApartmentSummary.fromJson(json['apartment'] as Map<String, dynamic>),
      contract: json['contract'] == null
          ? null
          : ContractInfo.fromJson(json['contract'] as Map<String, dynamic>),
    );
  }
}

/// 1 dòng trong danh sách TẤT CẢ hợp đồng cho Manager (màn Hợp đồng).
/// Khớp DTO ContractListItem của backend.
class ContractListItem {
  final int id;
  final String unitNumber;
  final String floor;
  final String residentName;
  final DateTime startDate;
  final DateTime endDate;
  final num baseRent;
  final String status; // ACTIVE | EXPIRED
  /// BR-13: số ngày còn lại; null khi hợp đồng EXPIRED.
  final int? remainingDays;
  /// Yêu cầu gia hạn PENDING đang chờ duyệt (nếu có) -> nút "Duyệt gia hạn".
  final int? pendingExtensionId;

  ContractListItem({
    required this.id,
    required this.unitNumber,
    required this.floor,
    required this.residentName,
    required this.startDate,
    required this.endDate,
    required this.baseRent,
    required this.status,
    this.remainingDays,
    this.pendingExtensionId,
  });

  /// Ngưỡng "sắp hết hạn": hợp đồng ACTIVE còn <= 30 ngày.
  static const int expiringSoonDays = 30;

  /// Nhóm hiển thị cho tab: ACTIVE (Hiệu lực) / EXPIRING (Sắp HH) / EXPIRED (Hết hạn).
  String get bucket {
    if (status != 'ACTIVE') return 'EXPIRED';
    if ((remainingDays ?? 0) <= expiringSoonDays) return 'EXPIRING';
    return 'ACTIVE';
  }

  factory ContractListItem.fromJson(Map<String, dynamic> json) {
    return ContractListItem(
      id: json['id'] as int,
      unitNumber: json['unitNumber'] as String,
      floor: json['floor'] as String,
      residentName: json['residentName'] as String,
      startDate: DateTime.parse(json['startDate'] as String).toLocal(),
      endDate: DateTime.parse(json['endDate'] as String).toLocal(),
      baseRent: json['baseRent'] as num,
      status: json['status'] as String,
      remainingDays: json['remainingDays'] as int?,
      pendingExtensionId: json['pendingExtensionId'] as int?,
    );
  }
}

/// 1 dòng yêu cầu gia hạn trong danh sách (UC08 - FID-11).
class StayExtension {
  final int id;
  final String residentName;
  final String unitNumber;
  final String floor;
  final DateTime currentEndDate;
  final DateTime requestedEndDate;
  final String status; // PENDING | APPROVED | REJECTED
  final DateTime createdAt;
  final DateTime? reviewedAt;

  StayExtension({
    required this.id,
    required this.residentName,
    required this.unitNumber,
    required this.floor,
    required this.currentEndDate,
    required this.requestedEndDate,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
  });

  /// FID-11 field 6: số ngày được cộng thêm nếu duyệt (vd "+181 ngày").
  int get extensionDays => requestedEndDate.difference(currentEndDate).inDays;

  factory StayExtension.fromJson(Map<String, dynamic> json) {
    return StayExtension(
      id: json['id'] as int,
      residentName: json['residentName'] as String,
      unitNumber: json['unitNumber'] as String,
      floor: json['floor'] as String,
      currentEndDate: DateTime.parse(json['currentEndDate'] as String).toLocal(),
      requestedEndDate:
          DateTime.parse(json['requestedEndDate'] as String).toLocal(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String).toLocal(),
    );
  }
}

/// Chi tiết yêu cầu gia hạn cho màn duyệt (UC09 - FID-12).
class StayExtensionDetail extends StayExtension {
  final int contractId;
  final String residentPhone;
  final DateTime contractStartDate;
  final DateTime contractEndDate;
  final String contractStatus;
  final num baseRent;
  final String? reason;
  final String? rejectReason;
  final String? reviewedByName;

  StayExtensionDetail({
    required super.id,
    required super.residentName,
    required super.unitNumber,
    required super.floor,
    required super.currentEndDate,
    required super.requestedEndDate,
    required super.status,
    required super.createdAt,
    super.reviewedAt,
    required this.contractId,
    required this.residentPhone,
    required this.contractStartDate,
    required this.contractEndDate,
    required this.contractStatus,
    required this.baseRent,
    this.reason,
    this.rejectReason,
    this.reviewedByName,
  });

  bool get isPending => status == 'PENDING';

  factory StayExtensionDetail.fromJson(Map<String, dynamic> json) {
    final base = StayExtension.fromJson(json);
    return StayExtensionDetail(
      id: base.id,
      residentName: base.residentName,
      unitNumber: base.unitNumber,
      floor: base.floor,
      currentEndDate: base.currentEndDate,
      requestedEndDate: base.requestedEndDate,
      status: base.status,
      createdAt: base.createdAt,
      reviewedAt: base.reviewedAt,
      contractId: json['contractId'] as int,
      residentPhone: json['residentPhone'] as String,
      contractStartDate:
          DateTime.parse(json['contractStartDate'] as String).toLocal(),
      contractEndDate:
          DateTime.parse(json['contractEndDate'] as String).toLocal(),
      contractStatus: json['contractStatus'] as String,
      baseRent: json['baseRent'] as num,
      reason: json['reason'] as String?,
      rejectReason: json['rejectReason'] as String?,
      reviewedByName: json['reviewedByName'] as String?,
    );
  }
}

/// Nhãn tiếng Việt cho trạng thái hợp đồng (FID-09 field 4).
const Map<String, String> kContractStatusLabels = {
  'ACTIVE': 'Hiệu lực',
  'EXPIRED': 'Hết hạn',
};

/// Nhãn tiếng Việt cho trạng thái yêu cầu gia hạn (FID-11 field 4).
const Map<String, String> kExtensionStatusLabels = {
  'PENDING': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt',
  'REJECTED': 'Từ chối',
};
