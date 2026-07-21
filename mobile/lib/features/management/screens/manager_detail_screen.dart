import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/manager_detail.dart';
import '../providers/manager_notifier.dart';

/// UC42 (FID-42): Manager Detail Screen — read-only (BR-62).
///
/// Displays the detailed profile of a selected Manager account:
/// - Header: avatar, full name, role badge, status badge
/// - Contact Information: phone number
/// - Account Information: Manager ID, created date, status
/// - Management History: timeline of recent actions from audit_logs
///
/// BR-08: No sensitive data (password_hash) is ever displayed.
/// BR-62: Strictly read-only — no data modifications occur.
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
    final member = detail.value?.member;
    final currentUser = ref.watch(authNotifierProvider).user;

    return Scaffold(
      body: Column(
        children: [
          // Header with Manager avatar, name, and status
          GradientHeader(
            showBack: true,
            titleWidget: member == null
                ? const Text(
                    'Chi tiết quản lý',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    children: [
                      InitialsAvatar(
                        name: member.fullName,
                        imageUrl: member.avatarUrl,
                        size: 56,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Quản lý · ${member.phoneNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: .6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      member.isActive
                          ? StatusBadge.success('Hoạt động')
                          : const StatusBadge(
                              text: 'Vô hiệu hóa',
                              color: AppColors.error,
                              backgroundColor: AppColors.errorBg,
                            ),
                    ],
                  ),
            actions: const [],
          ),

          // Body content
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
                        child: const Text('Thử lại'),
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 1. Account Information (leaving only "Ngày tạo" card, no section title)
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.calendar_today,
                            label: 'Ngày tạo',
                            value: m.createdAt != null
                                ? DateFormat('dd/MM/yyyy').format(m.createdAt!)
                                : '—',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 2. Management History section
                    _SectionTitle(title: 'Lịch sử quản lý'),
                    const SizedBox(height: 8),
                    if (data.managementHistory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: Text(
                            'Chưa có lịch sử quản lý.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...data.managementHistory.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _HistoryCard(item: item),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // 3. Action Buttons (Edit and Toggle Status)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Chỉnh sửa hồ sơ'),
                        onPressed: m.isActive
                            ? () => context.push('/managers/${m.id}/edit', extra: m)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (currentUser?.id != m.id) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: m.isActive ? AppColors.error : AppColors.primary,
                            side: BorderSide(color: m.isActive ? AppColors.error : AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(m.isActive ? Icons.block : Icons.check_circle_outline),
                          label: Text(m.isActive ? 'Vô hiệu hóa tài khoản' : 'Khôi phục tài khoản'),
                          onPressed: () => _onToggleStatus(context, m.isActive),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
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

/// Section title widget used to label content groups.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// A single row displaying an icon, label, and value — used in info cards.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single management history entry card with icon, action label,
/// affected user name, and timestamp.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final ManagementHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.history,
              size: 17,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionLabel(item.action),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.targetUserName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.targetUserName!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (item.reason != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Lý do: ${item.reason}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
