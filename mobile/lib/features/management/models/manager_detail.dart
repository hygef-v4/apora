import 'manager_member.dart';

/// A single entry in the Manager's management history timeline (UC42).
///
/// Sourced from the `audit_logs` table where the Manager is the actor.
/// Displays action type, affected user, reason, and timestamp.
class ManagementHistoryItem {
  const ManagementHistoryItem({
    required this.id,
    required this.action,
    required this.createdAt,
    this.targetUserName,
    this.reason,
  });

  final int id;

  /// The audit action code, e.g. 'STAFF_CREATE', 'STAFF_DEACTIVATE'.
  final String action;

  /// Full name of the affected user (if applicable).
  final String? targetUserName;

  /// Optional reason provided for the action.
  final String? reason;

  final DateTime createdAt;

  factory ManagementHistoryItem.fromJson(Map<String, dynamic> json) {
    return ManagementHistoryItem(
      id: json['id'] as int,
      action: json['action'] as String,
      targetUserName: json['targetUserName'] as String?,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Returns a human-readable English label for an audit action code.
String actionLabel(String action) {
  switch (action) {
    case 'STAFF_CREATE':
      return 'Created staff account';
    case 'STAFF_UPDATE':
      return 'Updated staff profile';
    case 'STAFF_DEACTIVATE':
      return 'Deactivated staff account';
    case 'STAFF_RESET_PASSWORD':
      return 'Reset staff password';
    case 'MANAGER_CREATE':
      return 'Created manager account';
    case 'MANAGER_UPDATE':
      return 'Updated manager profile';
    case 'MANAGER_DEACTIVATE':
      return 'Deactivated manager account';
    case 'PROFILE_PHONE_CHANGE':
      return 'Changed phone number';
    default:
      return action;
  }
}

/// Detailed profile of a Manager account (UC42).
///
/// Includes the basic [ManagerMember] profile, plus management history
/// from audit_logs. BR-08: no sensitive data is included.
class ManagerDetail {
  const ManagerDetail({
    required this.member,
    required this.managementHistory,
  });

  final ManagerMember member;

  /// Recent management activities performed by this Manager.
  final List<ManagementHistoryItem> managementHistory;

  /// Deserializes from the `GET /api/managers/:id` response.
  factory ManagerDetail.fromJson(Map<String, dynamic> json) {
    return ManagerDetail(
      member: ManagerMember.fromJson(json),
      managementHistory:
          (json['managementHistory'] as List<dynamic>? ?? const [])
              .map((e) =>
                  ManagementHistoryItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}
