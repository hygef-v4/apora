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
import '../../home/screens/task_board_screen.dart';

/// UC22 - Thân danh sách công việc (theo màn FID-22), nhúng dưới header
/// của TaskBoardScreen. Backend tự phân luồng: staff thấy việc của mình
/// (BR-42), Manager/Landlord thấy tất cả (BR-39).
class TaskListBody extends ConsumerStatefulWidget {
  const TaskListBody({super.key});

  @override
  ConsumerState<TaskListBody> createState() => _TaskListBodyState();
}

class _TaskListBodyState extends ConsumerState<TaskListBody> {
  /// Filter tabs: Tất cả / Đang chờ / Đang làm / Đã xong.
  static const List<({String? value, String label})> _filters = [
    (value: null, label: 'Tất cả'),
    (value: 'ASSIGNED', label: 'Đang chờ'),
    (value: 'IN_PROGRESS', label: 'Đang làm'),
    (value: 'COMPLETED', label: 'Đã xong'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).fetchTasks());
  }

  List<TaskItem> _applyFilter(List<TaskItem> all, String? currentFilter) {
    if (currentFilter == null) return all;
    return all.where((t) => t.status == currentFilter).toList();
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
    
    final nav = ref.watch(staffTabProvider);
    final currentFilter = nav.filter;

    final waitingCount = state.tasks.where((t) => t.status == 'ASSIGNED').length;
    final processingCount = state.tasks.where((t) => t.status == 'IN_PROGRESS').length;
    final completedCount = state.tasks.where((t) => t.status == 'COMPLETED').length;

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
              final selected = currentFilter == f.value;

              int count = 0;
              if (f.value == 'ASSIGNED') {
                count = waitingCount;
              } else if (f.value == 'IN_PROGRESS') {
                count = processingCount;
              } else if (f.value == 'COMPLETED') {
                count = completedCount;
              }

              final label = count > 0 ? '${f.label} ($count)' : f.label;

              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => ref.read(staffTabProvider.notifier).setFilter(f.value),
                selectedColor: AppColors.navy,
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
        Expanded(child: _buildBody(state, notifier, currentFilter)),
      ],
    );
  }

  Widget _buildBody(TaskListState state, TaskNotifier notifier, String? currentFilter) {
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
    final visible = _applyFilter(state.tasks, currentFilter);
    if (visible.isEmpty) {
      // AT1/AT2: trạng thái rỗng theo filter đang chọn
      return _emptyOrError(
        icon: Icons.assignment_outlined,
        message: currentFilter == null
            ? 'Chưa có công việc nào được giao cho bạn.'
            : 'Không có công việc "${currentFilter == 'ASSIGNED' ? 'Đang chờ' : currentFilter == 'IN_PROGRESS' ? 'Đang làm' : 'Đã xong'}".',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.fetchTasks(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: visible.length,
        itemBuilder: (_, i) => _taskCard(visible[i]),
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
          ref.read(taskProvider.notifier).fetchTasks();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dòng 1: Số phòng · loại bên trái và status bên phải
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Phòng ${t.unitNumber} · ${t.category}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(t.status),
              ],
            ),
            const SizedBox(height: 8),
            // Dòng 2: Tên công việc
            Text(
              t.title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            // Dòng 3: Người giao và Ngày giao
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
                const Icon(Icons.schedule,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  isCompleted && t.completedAt != null
                      ? _formatDate(t.completedAt!)
                      : _formatDate(t.assignedAt),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (t.status == 'ASSIGNED') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ref.read(taskDetailProvider.notifier).updateProgress(
                            t.id,
                            status: 'IN_PROGRESS',
                          );
                          ref.read(taskProvider.notifier).fetchTasks();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Bắt đầu',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await context.push(AppRoutes.taskDetailPath(t.id));
                        if (!mounted) return;
                        ref.read(taskProvider.notifier).fetchTasks();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text(
                        'Hoàn thành',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (t.status == 'IN_PROGRESS') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await context.push(AppRoutes.taskDetailPath(t.id));
                    if (!mounted) return;
                    ref.read(taskProvider.notifier).fetchTasks();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Hoàn thành',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
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
