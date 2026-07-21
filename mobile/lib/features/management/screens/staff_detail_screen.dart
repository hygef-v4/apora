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
import '../models/staff_detail.dart';
import '../models/staff_member.dart';
import '../providers/staff_notifier.dart';
import '../widgets/deactivate_staff_dialog.dart';

/// UC37 (FID-36): Staff Detail — layout theo wireframe (header chỉ có tiêu đề,
/// khối hồ sơ căn giữa với avatar/tên/SĐT/trạng thái, 2 ô Role + Joined Date,
/// ô tổng số việc đang mở, danh sách ticket được giao, cuối cùng là nút hành
/// động kèm ghi chú BR-50). Giao diện dùng design system Apora.
/// Read-only (BR-03 UC37) + UC40 vô hiệu hóa tài khoản.
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
    final result = await showDeactivateStaffDialog(context);
    if (result == null) return;
    try {
      await ref.read(staffDirectoryProvider.notifier).deactivateStaff(
            widget.staffId,
            reason: result.reason,
          );
      _showMessage('Staff account deactivated.');
      await ref.read(staffDetailProvider.notifier).fetch(widget.staffId);
    } catch (e) {
      // 409 khi vi phạm BR-50 - message từ backend
      _showMessage(mapDioError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(staffDetailProvider);
    // staffDetailProvider dùng chung cho mọi nhân viên nên có thể còn giữ dữ
    // liệu người xem trước đó khi fetch id này đang chạy hoặc lỗi. Chỉ nhận
    // dữ liệu đúng nhân viên đang mở, tránh hiện nhầm tên/ảnh người khác.
    final data =
        detail.value?.member.id == widget.staffId ? detail.value : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Staff Detail', showBack: true),
          Expanded(
            child: detail.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        mapDioError(error),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref
                            .read(staffDetailProvider.notifier)
                            .fetch(widget.staffId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) {
                // Dữ liệu của nhân viên khác (hoặc chưa fetch xong) -> chờ.
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _DetailBody(
                  data: data,
                  onEdit: () => context.push(AppRoutes.staffEditPath(data.member.id)),
                  onDeactivate: _confirmDeactivate,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.data,
    required this.onEdit,
    required this.onDeactivate,
  });

  final StaffDetail data;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) {
    final member = data.member;
    final openCount = data.openTasks.length;
    final hasOpenTasks = openCount > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _ProfileCard(member: member),
        const SizedBox(height: 12),
        // IntrinsicHeight để 2 ô cao bằng nhau; stretch trần trong ListView sẽ
        // cho ràng buộc chiều cao vô hạn.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FactCard(
                  label: 'Role',
                  value: staffRoleLabel(member.role).toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FactCard(
                  label: 'Joined Date',
                  value: data.createdAt != null
                      ? _formatDate(data.createdAt!)
                      : '—',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _OpenTicketsSummary(count: member.openTaskCount),

        if (hasOpenTasks) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Open Assigned Tickets',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$openCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final task in data.openTasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TicketCard(task: task),
            ),
        ],

        const SizedBox(height: 20),
        // UC39: sửa hồ sơ - không cho sửa tài khoản đã vô hiệu hóa.
        FilledButton.icon(
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit Profile'),
          onPressed: member.isActive ? onEdit : null,
        ),
        const SizedBox(height: 10),
        // UC40/BR-50: còn task mở -> chặn, nhãn nút nói rõ phải phân công lại.
        OutlinedButton.icon(
          icon: Icon(
            hasOpenTasks ? Icons.swap_horiz : Icons.block,
            size: 18,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(
              color: AppColors.error.withValues(alpha: .4),
              width: 1.5,
            ),
          ),
          label: Text(
            !member.isActive
                ? 'Account Deactivated'
                : hasOpenTasks
                    ? 'Reassign Tickets First'
                    : 'Deactivate Account',
          ),
          onPressed: data.canDeactivate ? onDeactivate : null,
        ),
        if (hasOpenTasks) ...[
          const SizedBox(height: 10),
          const Text(
            AppStrings.msgStaffHasOpenTasks,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ],
    );
  }
}

/// Khối hồ sơ căn giữa: avatar lớn, tên, SĐT, badge trạng thái (wireframe).
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          InitialsAvatar(
            name: member.fullName,
            imageUrl: member.avatarUrl,
            size: 84,
          ),
          const SizedBox(height: 14),
          Text(
            member.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            member.phoneNumber,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          member.isActive
              ? StatusBadge.success('ACTIVE')
              : const StatusBadge(
                  text: 'INACTIVE',
                  color: AppColors.error,
                  backgroundColor: AppColors.errorBg,
                ),
        ],
      ),
    );
  }
}

/// Ô thông tin nhỏ (Role / Joined Date) — label trên, giá trị dưới.
class _FactCard extends StatelessWidget {
  const _FactCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô tổng hợp số việc đang mở (wireframe) — tint cam khi còn việc.
class _OpenTicketsSummary extends StatelessWidget {
  const _OpenTicketsSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final hasOpen = count > 0;
    final accent = hasOpen ? AppColors.warning : AppColors.textSecondary;
    final label = count == 1
        ? '1 open assigned ticket'
        : '$count open assigned tickets';

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Open Assigned Tickets',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: hasOpen ? AppColors.warningBg : AppColors.divider,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment, size: 18, color: accent),
          ),
        ],
      ),
    );
  }
}

/// Card 1 ticket được giao: mã task, tiêu đề, hạng mục + badge trạng thái.
class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.task});

  final StaffOpenTask task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#TASK-${task.id}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              task.status == 'ASSIGNED'
                  ? StatusBadge.info('ASSIGNED')
                  : StatusBadge.warning('PROCESSING'),
            ],
          ),
          if (task.category != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.build_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Text(
                  task.category!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
