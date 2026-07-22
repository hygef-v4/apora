import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/ticket_category.dart';

/// UC22 - My Tasks (bố cục theo wireframe FID-22 trong SRS), nhúng dưới header
/// của TaskBoardScreen. Backend tự phân luồng: staff thấy việc của mình
/// (BR-42), Manager/Landlord thấy tất cả (BR-39).
class TaskListBody extends ConsumerStatefulWidget {
  const TaskListBody({super.key});

  @override
  ConsumerState<TaskListBody> createState() => _TaskListBodyState();
}

class _TaskListBodyState extends ConsumerState<TaskListBody> {
  /// null = All; ACTIVE = đang làm (ASSIGNED/IN_PROGRESS); COMPLETED.
  String? _filter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).fetchTasks());
  }

  List<TaskItem> _applyFilter(List<TaskItem> all) {
    switch (_filter) {
      case 'ACTIVE':
        return all
            .where((t) => t.status == 'ASSIGNED' || t.status == 'IN_PROGRESS')
            .toList();
      case 'COMPLETED':
        return all.where((t) => t.status == 'COMPLETED').toList();
      default:
        return all;
    }
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'COMPLETED':
        return StatusBadge.success('COMPLETED');
      case 'IN_PROGRESS':
        return StatusBadge.warning('IN_PROGRESS');
      case 'CANCELLED':
        return StatusBadge.muted('CANCELLED');
      default: // ASSIGNED
        return const StatusBadge(
          text: 'ASSIGNED',
          color: AppColors.primary,
          backgroundColor: AppColors.infoBg,
        );
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
    // FID-22 field 1: số việc chưa xong hiện trên tab "Active"
    final activeCount = state.tasks
        .where((t) => t.status == 'ASSIGNED' || t.status == 'IN_PROGRESS')
        .length;

    return Column(
      children: [
        // Thanh tab chữ gạch chân theo wireframe
        Container(
          color: AppColors.surface,
          child: Row(
            children: [
              _TabItem(
                label: 'All',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              _TabItem(
                label: 'Active',
                badgeCount: activeCount,
                selected: _filter == 'ACTIVE',
                onTap: () => setState(() => _filter = 'ACTIVE'),
              ),
              _TabItem(
                label: 'Completed',
                selected: _filter == 'COMPLETED',
                onTap: () => setState(() => _filter = 'COMPLETED'),
              ),
            ],
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
        onRetry: () => notifier.fetchTasks(),
      );
    }
    final visible = _applyFilter(state.tasks);
    if (visible.isEmpty) {
      // AT1/AT2: trạng thái rỗng theo filter đang chọn
      return _emptyOrError(
        icon: Icons.assignment_outlined,
        message: _filter == null
            ? 'No tasks have been assigned to you yet.'
            : 'No ${_filter == 'ACTIVE' ? 'active' : 'completed'} tasks.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.fetchTasks(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        itemCount: visible.length,
        itemBuilder: (_, i) => _taskCard(visible[i]),
      ),
    );
  }

  Widget _taskCard(TaskItem t) {
    final isCompleted = t.status == 'COMPLETED';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // UC23 (TRG-01): bấm thẻ mở chi tiết / cập nhật tiến độ
          onTap: () async {
            await context.push(AppRoutes.taskDetailPath(t.id));
            if (!mounted) return;
            ref.read(taskProvider.notifier).fetchTasks();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'TASK-${t.id.toString().padLeft(3, '0')}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    _statusBadge(t.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  t.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _CategoryChip(category: t.category),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Room ${t.unitNumber}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 8),
                Text(
                  'Assigned by: ${t.assignedByName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // FID-22 field 8/9: xong hiện ngày hoàn thành, chưa xong hiện
                // ngày được giao
                Text(
                  isCompleted && t.completedAt != null
                      ? 'COMPLETED: ${_formatDate(t.completedAt!)}'
                      : 'ASSIGNED: ${_formatDate(t.assignedAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
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
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tab chữ có gạch chân khi đang chọn (theo wireframe).
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final showCount = badgeCount != null && badgeCount! > 0;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
          child: Text(
            showCount ? '$label ($badgeCount)' : label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip danh mục nền nhạt, viền, icon + nhãn tiếng Anh (theo wireframe).
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ticketCategoryIcon(category),
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            ticketCategoryLabel(category),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
