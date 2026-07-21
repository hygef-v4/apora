/// Model representing a Manager account in the list view (UC41).
///
/// Maps to the `ManagerListItem` DTO returned by `GET /api/managers`.
/// Only contains public-safe fields — password_hash is never exposed (BR-08).
class ManagerMember {
  const ManagerMember({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.status,
    this.avatarUrl,
    this.createdAt,
    this.managedRecordsCount = 0,
  });

  final int id;
  final String fullName;
  final String phoneNumber;
  final String? avatarUrl;

  /// Account status: 'ACTIVE' | 'INACTIVE'.
  final String status;
  final DateTime? createdAt;
  final int managedRecordsCount;

  bool get isActive => status == 'ACTIVE';

  /// Deserializes from the API response JSON (camelCase keys).
  factory ManagerMember.fromJson(Map<String, dynamic> json) {
    return ManagerMember(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      status: json['status'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      managedRecordsCount: json['managedRecordsCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl,
        'status': status,
        'createdAt': createdAt?.toIso8601String(),
        'managedRecordsCount': managedRecordsCount,
      };
}
