import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/staff_member.dart';
import '../providers/staff_notifier.dart';

/// UC37 (FID-36): Chi tiết nhân viên - read-only (BR-03 UC37).
/// UC40 (FID-39): nút Vô hiệu hóa + confirm dialog; disabled khi còn task mở (BR-50).
class StaffDetailScreen extends ConsumerStatefulWidget {
  const StaffDetailScreen({super.key, required this.staffId});

  final int staffId;

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(staffDetailProvider.notifier).fetch(widget.staffId),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// UC40: confirm dialog + lý do (optional, <=250 ký tự) -> gọi API.
  Future<void> _confirmDeactivate() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vô hiệu hóa tài khoản'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppStrings.msgStaffDeactivateConfirm),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLength: 250,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do (không bắt buộc)',
                hintText: 'VD: Nghỉ việc, chấm dứt hợp đồng...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận vô hiệu hóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final reason = reasonController.text.trim();
      await ref.read(staffDirectoryProvider.notifier).deactivateStaff(
            widget.staffId,
            reason: reason.isEmpty ? null : reason,
          );
      _showMessage('Đã vô hiệu hóa tài khoản nhân viên.');
      await ref.read(staffDetailProvider.notifier).fetch(widget.staffId);
    } catch (e) {
      // 409 khi vi phạm BR-50 - message từ backend
      _showMessage(mapDioError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(staffDetailProvider);
    final member = detail.value?.member;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            showBack: true,
            titleWidget: member == null
                ? const Text(
                    'Chi tiết nhân viên',
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
                              '${staffRoleLabel(member.role)} · ${member.phoneNumber}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: .6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        text: member.isActive ? 'Đang làm việc' : 'Đã nghỉ',
                        color: Colors.white,
                        backgroundColor: member.isActive
                            ? Colors.white.withValues(alpha: .2)
                            : Colors.black.withValues(alpha: .2),
                      ),
                    ],
                  ),
            actions: member != null && member.isActive
                ? [
                    HeaderIconButton(
                      icon: Icons.edit,
                      tooltip: 'Chỉnh sửa hồ sơ',
                      onTap: () =>
                          context.push(AppRoutes.staffEditPath(member.id)),
                    ),
                  ]
                : const [],
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
                            .read(staffDetailProvider.notifier)
                            .fetch(widget.staffId),
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
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          if (data.createdAt != null) ...[
                            _InfoRow(
                              icon: Icons.calendar_today,
                              label: 'Ngày vào hệ thống',
                              value:
                                  '${data.createdAt!.day.toString().padLeft(2, '0')}/'
                                  '${data.createdAt!.month.toString().padLeft(2, '0')}/'
                                  '${data.createdAt!.year}',
                            ),
                            const Divider(height: 1, indent: 56),
                          ],
                          _InfoRow(
                            icon: Icons.assignment,
                            label: 'Công việc đang mở',
                            value: '${m.openTaskCount} công việc',
                          ),
                        ],
                      ),
                    ),

                    // UC37: list task đang mở (hiện khi > 0)
                    if (data.openTasks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Công việc được giao',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      ...data.openTasks.map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.infoBg,
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(Icons.build,
                                      size: 17, color: AppColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (task.category != null)
                                        Text(
                                          task.category!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                task.status == 'ASSIGNED'
                                    ? StatusBadge.info('Đã giao')
                                    : StatusBadge.warning('Đang xử lý'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Cảnh báo BR-50
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: AppColors.warning),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppStrings.msgStaffHasOpenTasks,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Chỉnh sửa hồ sơ'),
                      onPressed: m.isActive
                          ? () => context.push(AppRoutes.staffEditPath(m.id))
                          : null,
                    ),
                    const SizedBox(height: 8),
                    // UC40: disabled khi !canDeactivate (còn task mở hoặc đã INACTIVE)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.block, size: 18),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: .4),
                          width: 1.5,
                        ),
                      ),
                      label: Text(m.isActive
                          ? 'Vô hiệu hóa tài khoản'
                          : 'Tài khoản đã vô hiệu hóa'),
                      onPressed: data.canDeactivate ? _confirmDeactivate : null,
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
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

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
                      fontSize: 11, color: AppColors.textTertiary),
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
