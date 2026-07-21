import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/manager_detail.dart';
import '../models/manager_member.dart';
import '../providers/manager_notifier.dart';

/// UC42 (FID-42): Manager Detail Screen.
class ManagerDetailScreen extends ConsumerStatefulWidget {
  const ManagerDetailScreen({super.key, required this.managerId});

  final int managerId;

  @override
  ConsumerState<ManagerDetailScreen> createState() =>
      _ManagerDetailScreenState();
}

class _ManagerDetailScreenState extends ConsumerState<ManagerDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(managerDetailProvider.notifier).fetch(widget.managerId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(managerDetailProvider);
    final currentUser = ref.watch(authNotifierProvider).user;


    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            showBack: true,
            title: 'Manager Detail',
          ),
          Expanded(
            child: detail.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(mapDioError(error), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref
                            .read(managerDetailProvider.notifier)
                            .fetch(widget.managerId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final m = data.member;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                  children: [
                    // 1. Top Profile Summary Card (Wireframe Header Card)
                    _buildProfileHeaderCard(m),
                    const SizedBox(height: 14),

                    // 2. Contact Information Card
                    _buildContactCard(m),
                    const SizedBox(height: 14),

                    // 3. Account Details Card (Dynamic from DB)
                    _buildAccountDetailsCard(m, data.managementHistory),
                    const SizedBox(height: 14),


                    // 4. Assigned Permissions Card
                    _buildPermissionsCard(),
                    const SizedBox(height: 14),

                    // 5. Management History Timeline Card
                    _buildManagementHistoryCard(data.managementHistory),
                    const SizedBox(height: 20),

                    // 6. Action Buttons Bar (Edit Manager & Deactivate/Activate Account)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text(
                              'Edit Manager',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: m.isActive
                                ? () => context.push('/managers/${m.id}/edit', extra: m)
                                : null,
                          ),
                        ),
                        if (currentUser?.id != m.id) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: m.isActive ? AppColors.error : AppColors.primary,
                                side: BorderSide(
                                  color: m.isActive ? AppColors.error : AppColors.primary,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(
                                m.isActive ? Icons.person_off_outlined : Icons.check_circle_outline,
                                size: 18,
                              ),
                              label: Text(
                                m.isActive ? 'Deactivate Account' : 'Activate Account',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => _onToggleStatus(context, m.isActive),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard(ManagerMember member) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          InitialsAvatar(
            name: member.fullName,
            imageUrl: member.avatarUrl,
            size: 72,
          ),
          const SizedBox(height: 12),
          Text(
            member.fullName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Manager',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: member.isActive ? AppColors.successBg : AppColors.errorBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: member.isActive ? AppColors.success : AppColors.error,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  member.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: member.isActive ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(ManagerMember member) {
    final emailStr = '${member.fullName.toLowerCase().replaceAll(' ', '.')}@apora.com';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTACT INFORMATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: member.phoneNumber,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: emailStr,
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Address',
            value: 'Block B, Level 2, Apora Office',
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsCard(
    ManagerMember member,
    List<ManagementHistoryItem> history,
  ) {
    final createdStr = member.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(member.createdAt!.toLocal())
        : 'N/A';

    final lastActiveStr = history.isNotEmpty
        ? DateFormat('dd/MM/yyyy HH:mm').format(history.first.createdAt.toLocal())
        : (member.createdAt != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(member.createdAt!.toLocal())
            : 'N/A');

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACCOUNT DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          _buildTextLabelValue(
            label: 'Manager ID',
            value: 'MA-${member.id.toString().padLeft(4, '0')}',
            isBold: true,
          ),
          const SizedBox(height: 10),
          _buildTextLabelValue(
            label: 'Created Date',
            value: createdStr,
          ),
          const SizedBox(height: 10),
          _buildTextLabelValue(
            label: 'Last Login',
            value: lastActiveStr,
          ),
        ],
      ),
    );
  }


  Widget _buildPermissionsCard() {
    final permissions = [
      {'icon': Icons.receipt_outlined, 'title': 'Billing Management'},
      {'icon': Icons.apartment_outlined, 'title': 'Apartment Management'},
      {'icon': Icons.confirmation_number_outlined, 'title': 'Ticket Management'},
      {'icon': Icons.campaign_outlined, 'title': 'Announcement Management'},
    ];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSIGNED PERMISSIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Column(
            children: permissions.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        p['icon'] as IconData,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        p['title'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementHistoryCard(List<ManagementHistoryItem> history) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MANAGEMENT HISTORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No management history recorded.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Column(
              children: history.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final isLast = idx == history.length - 1;
                final formattedDate =
                    DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: AppColors.textPrimary,
                                width: 2,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: AppColors.border,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                actionLabel(item.action),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textPrimary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextLabelValue({
    required String label,
    required String value,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _onToggleStatus(BuildContext context, bool isActive) async {
    final member = ref.read(managerDetailProvider).value?.member;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => PremiumActionDialog(
        title: isActive ? 'Deactivate Account?' : 'Restore Account?',
        targetName: member?.fullName ?? 'Unknown',
        targetIdentifier: member?.phoneNumber ?? 'No Phone Number',
        avatarUrl: member?.avatarUrl,
        description: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF374151),
              height: 1.45,
            ),
            children: isActive
                ? const [
                    TextSpan(
                      text: 'Are you sure you want to deactivate this admin account? They will be ',
                    ),
                    TextSpan(
                      text: 'instantly logged out',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                    TextSpan(
                      text: ' and lose all access to the system. Their historical data will be preserved.',
                    ),
                  ]
                : const [
                    TextSpan(
                      text: 'Are you sure you want to restore this admin account? They will ',
                    ),
                    TextSpan(
                      text: 'regain access',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                    TextSpan(
                      text: ' to the system immediately.',
                    ),
                  ],
          ),
        ),
        confirmLabel: isActive ? 'Deactivate' : 'Restore',
        confirmGradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        icon: isActive ? Icons.block_outlined : Icons.check_circle_outline,
        isDestructive: isActive,
      ),
    );

    if (confirm != true) return;

    if (!context.mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await ref.read(managerDetailProvider.notifier).toggleManagerStatus();

      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Account deactivated successfully.' : 'Account restored successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapDioError(e))),
      );
    }
  }
}

/// A premium, highly polished modern dialog for critical actions.
class PremiumActionDialog extends StatelessWidget {
  const PremiumActionDialog({
    super.key,
    required this.title,
    required this.targetName,
    required this.targetIdentifier,
    required this.avatarUrl,
    required this.description,
    required this.confirmLabel,
    required this.confirmGradient,
    required this.icon,
    required this.isDestructive,
  });

  final String title;
  final String targetName;
  final String targetIdentifier;
  final String? avatarUrl;
  final Widget description;
  final String confirmLabel;
  final LinearGradient confirmGradient;
  final IconData icon;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final statusColor = isDestructive ? AppColors.error : AppColors.primary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row with Warning Icon next to it
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: statusColor,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Target Account premium card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        InitialsAvatar(
                          name: targetName,
                          imageUrl: avatarUrl,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TARGET ACCOUNT',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textTertiary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                targetName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.phone_outlined,
                                    size: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    targetIdentifier,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Warning/Info Description Banner
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? const Color(0xFFFFF5F5)
                          : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDestructive
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFDCFCE7),
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isDestructive ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                          color: statusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: description),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: confirmGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDestructive ? Icons.delete_outline_rounded : Icons.check_circle_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            confirmLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Cancel button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(false),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


