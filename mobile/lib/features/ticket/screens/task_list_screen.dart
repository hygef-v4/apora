import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/task.dart';
import '../models/ticket.dart';
import '../providers/task_provider.dart';

/// UC22 - Thân danh sách công việc (theo màn FID-22), nhúng dưới header
/// của TaskBoardScreen. Backend tự phân luồng: staff thấy việc của mình
/// (BR-42), Manager/Landlord thấy tất cả (BR-39).
class TaskListBody extends ConsumerStatefulWidget {
  const TaskListBody({super.key});

  @override
  ConsumerState<TaskListBody> createState() => _TaskListBodyState();
}

class _TaskListBodyState extends ConsumerState<TaskListBody> {
  /// Filter tabs theo FID-22 field 1: Tất cả / Đang làm / Hoàn thành.
  static const List<({String? value, String label})> _filters = [
    (value: null, label: 'Tất cả'),
    (value: 'ACTIVE', label: 'Đang làm'),
    (value: 'COMPLETED', label: 'Hoàn thành'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).fetchTasks());
  }

  StatusBadge _statusBadge(String status) {
    final label = kTaskStatusLabels[status] ?? status;
    switch (status) {
      case 'COMPLETED':
        return StatusBadge.success(label);
      case 'IN_PROGRESS':
        return StatusBadge.warning(label);
      case 'CANCELLED':
        return StatusBadge(
          text: label,
          color: AppColors.error,
          backgroundColor: AppColors.errorBg,
        );
      default: // ASSIGNED
        return StatusBadge.info(label);
    }
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    final notifier = ref.read(taskProvider.notifier);

    return Column(
      children: [
        // Thanh lọc trạng thái
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final selected = state.statusFilter == f.value;
              return ChoiceChip(
                label: Text(f.label),
                selected: selected,
                onSelected: (_) => notifier.fetchTasks(status: f.value),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.white,
                showCheckmark: false,
              );
            },
          ),
        ),
        Expanded(child: _buildBody(state, notifier)),
      ],
    );
  }

  Widget _buildBody(TaskListState state, TaskNotifier notifier) {
    if (state.isLoading && state.tasks.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state.errorMessage != null && state.tasks.isEmpty) {
      return _emptyOrError(
        icon: Icons.error_outline,
        message: state.errorMessage!,
        onRetry: () => notifier.fetchTasks(status: state.statusFilter),
      );
    }
    if (state.tasks.isEmpty) {
      // AT1/AT2: trạng thái rỗng theo filter đang chọn
      final f = state.statusFilter;
      return _emptyOrError(
        icon: Icons.assignment_outlined,
        message: f == null
            ? 'Chưa có công việc nào được giao cho bạn.'
            : 'Không có công việc "${f == 'ACTIVE' ? 'Đang làm' : 'Hoàn thành'}".',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.fetchTasks(status: state.statusFilter),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.tasks.length,
        itemBuilder: (_, i) => _taskCard(state.tasks[i]),
      ),
    );
  }

  Widget _taskCard(TaskItem t) {
    final isCompleted = t.status == 'COMPLETED';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        // UC23 (TRG-01): bấm thẻ mở chi tiết / cập nhật tiến độ
        onTap: () async {
          await context.push(AppRoutes.taskDetailPath(t.id));
          if (!mounted) return;
          final notifier = ref.read(taskProvider.notifier);
          notifier.fetchTasks(status: ref.read(taskProvider).statusFilter);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TASK-${t.id}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary),
                  ),
                ),
                _statusBadge(t.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              t.title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    t.category,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 2),
                Text('Phòng ${t.unitNumber}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Giao bởi: ${t.assignedByName}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  isCompleted ? Icons.check_circle_outline : Icons.schedule,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                // FID-22 field 8/9: task xong hiện ngày hoàn thành,
                // chưa xong hiện ngày được giao
                Text(
                  isCompleted && t.completedAt != null
                      ? _formatDate(t.completedAt!)
                      : _formatDate(t.assignedAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyOrError({
    required IconData icon,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}
