/// Model User phía client (theo Software Design Module 1).
/// Khớp PublicUser trả về từ backend: không bao giờ chứa password.
class User {
  const User({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.roles,
    this.avatarUrl,
  });

  final int id;
  final String phoneNumber;
  final String fullName;
  final String? avatarUrl;
  final List<String> roles;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      phoneNumber: json['phoneNumber'] as String,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      roles: (json['roles'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'roles': roles,
      };

  bool get isResident => roles.contains('RESIDENT');
  bool get isManagement => roles.contains('LANDLORD') || roles.contains('MANAGER');
  bool get isStaff =>
      roles.contains('SECURITY_GUARD') ||
      roles.contains('JANITOR') ||
      roles.contains('TECHNICIAN');
}
