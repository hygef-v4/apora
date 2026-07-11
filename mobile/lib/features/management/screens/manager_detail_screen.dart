import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/status_badge.dart';
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
                      StatusBadge(
                        text: member.isActive ? 'Đang hoạt động' : 'Đã vô hiệu',
                        color: Colors.white,
                        backgroundColor: member.isActive
                            ? Colors.white.withValues(alpha: .2)
                            : Colors.black.withValues(alpha: .2),
                      ),
                    ],
                  ),
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
                    // Contact Information section
                    _SectionTitle(title: 'Thông tin liên hệ'),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.phone,
                            label: 'Số điện thoại',
                            value: m.phoneNumber,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Account Information section
                    _SectionTitle(title: 'Thông tin tài khoản'),
                    const SizedBox(height: 8),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.badge,
                            label: 'Mã tài khoản',
                            value: '#${m.id}',
                          ),
                          const Divider(height: 1, indent: 56),
                          _InfoRow(
                            icon: Icons.calendar_today,
                            label: 'Ngày tạo',
                            value: m.createdAt != null
                                ? DateFormat('dd/MM/yyyy').format(m.createdAt!)
                                : '—',
                          ),
                          const Divider(height: 1, indent: 56),
                          _InfoRow(
                            icon: Icons.circle,
                            label: 'Trạng thái',
                            value: m.isActive ? 'Đang hoạt động' : 'Đã vô hiệu',
                            valueColor: m.isActive
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Permissions section
                    _SectionTitle(title: 'Quyền hạn'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _PermissionChip(label: 'Quản lý nhân viên'),
                        _PermissionChip(label: 'Quản lý hóa đơn'),
                        _PermissionChip(label: 'Phân công sự cố'),
                        _PermissionChip(label: 'Duyệt yêu cầu'),
                        _PermissionChip(label: 'Đăng tin'),
                        _PermissionChip(label: 'Trò chuyện'),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Management History section
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
                  ],
                );
              },
            ),
          ),
        ],
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
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? AppColors.textPrimary,
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

/// Permission chip displaying an assigned module/capability.
class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: .2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
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
