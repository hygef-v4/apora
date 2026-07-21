/// Model nhân viên vận hành trong danh sách (UC36).
class StaffMember {
  const StaffMember({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.status,
    required this.openTaskCount,
    this.avatarUrl,
  });

  final int id;
  final String fullName;
  final String phoneNumber;
  final String? avatarUrl;

  /// Staff giữ 1 role: SECURITY_GUARD | JANITOR | TECHNICIAN.
  final String role;
  final String status; // ACTIVE | INACTIVE
  final int openTaskCount;

  bool get isActive => status == 'ACTIVE';

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>?)?.cast<String>() ?? const [];
    return StaffMember(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      role: roles.isNotEmpty ? roles.first : '',
      status: json['status'] as String,
      openTaskCount: (json['openTaskCount'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl,
        'roles': [role],
        'status': status,
        'openTaskCount': openTaskCount,
      };
}

/// Nhãn hiển thị cho role nhân viên (tiếng Anh theo wireframe).
String staffRoleLabel(String role) {
  switch (role) {
    case 'SECURITY_GUARD':
      return 'Security';
    case 'JANITOR':
      return 'Janitor';
    case 'TECHNICIAN':
      return 'Technician';
    default:
      return role;
  }
}

/// 3 role staff cho dropdown (UC38/UC39).
const List<String> kStaffRoles = ['SECURITY_GUARD', 'JANITOR', 'TECHNICIAN'];
