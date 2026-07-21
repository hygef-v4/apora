import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../../auth_profile/widgets/logout_confirm.dart';
import '../../ticket/models/task.dart';
import '../../ticket/providers/task_provider.dart';
import '../../ticket/screens/task_list_screen.dart';

class StaffTabState {
  final int tabIndex;
  final String? filter;
  const StaffTabState(this.tabIndex, this.filter);
}

class StaffTabNotifier extends Notifier<StaffTabState> {
  @override
  StaffTabState build() => const StaffTabState(0, null);

  void setTab(int index, {String? filter}) {
    state = StaffTabState(index, filter ?? state.filter);
  }

  void setFilter(String? filter) {
    state = StaffTabState(state.tabIndex, filter);
  }
}

final staffTabProvider = NotifierProvider<StaffTabNotifier, StaffTabState>(
  StaffTabNotifier.new,
);

/// Màn hình chính quản lý công việc của nhân viên (Staff)
/// Chia làm 2 tab: Trang chủ (Home) và Công việc (Tasks list).
class TaskBoardScreen extends ConsumerWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nav = ref.watch(staffTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: nav.tabIndex,
        children: const [
          StaffHomeTab(),
          StaffTasksTab(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: const [
          AppBottomNavItem(icon: Icons.home, label: 'Home'),
          AppBottomNavItem(icon: Icons.build_outlined, label: 'Tasks'),
        ],
        currentIndex: nav.tabIndex,
        onTap: (index) {
          ref.read(staffTabProvider.notifier).setTab(index);
        },
      ),
    );
  }
}

/// Tab 1: Trang chủ của Nhân viên
class StaffHomeTab extends ConsumerStatefulWidget {
  const StaffHomeTab({super.key});

  @override
  ConsumerState<StaffHomeTab> createState() => _StaffHomeTabState();
}

class _StaffHomeTabState extends ConsumerState<StaffHomeTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(taskProvider.notifier).fetchTasks());
  }

  String _getFloorOf(String unit) {
    final digits = RegExp(r'\d+').stringMatch(unit) ?? '';
    if (digits.length >= 3) {
      return 'Tầng ${digits[0]}';
    }
    return '';
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year}';
  }

  String _getRoleLabel(List<String> roles) {
    if (roles.contains('TECHNICIAN')) return 'Kỹ thuật';
    if (roles.contains('SECURITY_GUARD')) return 'Bảo vệ';
    if (roles.contains('JANITOR')) return 'Lao công';
    return 'Nhân viên';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final state = ref.watch(taskProvider);

    final waitingCount = state.tasks.where((t) => t.status == 'ASSIGNED').length;
    final processingCount = state.tasks.where((t) => t.status == 'IN_PROGRESS').length;
    final completedCount = state.tasks.where((t) => t.status == 'COMPLETED').length;

    // Lọc công việc đang thực hiện (IN_PROGRESS) và đang chờ (ASSIGNED)
    final inProgressTasks = state.tasks.where((t) => t.status == 'IN_PROGRESS').toList();
    final waitingTasks = state.tasks.where((t) => t.status == 'ASSIGNED').toList();

    final firstName = user?.fullName.split(' ').last ?? 'Nhân viên';
    final roleLabel = _getRoleLabel(user?.roles ?? []);

    return Column(
      children: [
        GradientHeader(
          titleWidget: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$roleLabel · Chung cư Apora',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: .65),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Chào $firstName 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.profile),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: InitialsAvatar(
                      name: user?.fullName ?? '?',
                      imageUrl: user?.avatarUrl,
                      size: 40,
                      square: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottom: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => ref.read(staffTabProvider.notifier).setTab(1, filter: 'ASSIGNED'),
                  child: _buildStatBox('Đang chờ', waitingCount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => ref.read(staffTabProvider.notifier).setTab(1, filter: 'IN_PROGRESS'),
                  child: _buildStatBox('Đang làm', processingCount),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => ref.read(staffTabProvider.notifier).setTab(1, filter: 'COMPLETED'),
                  child: _buildStatBox('Đã xong', completedCount),
                ),
              ),
            ],
          ),
          actions: [
            HeaderIconButton(
              icon: Icons.logout,
              tooltip: 'Đăng xuất',
              onTap: () => confirmAndLogout(context, ref),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(taskProvider.notifier).fetchTasks(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'ĐANG LÀM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (inProgressTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: Text(
                        'Không có công việc đang làm.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...inProgressTasks.map((t) => _buildActiveTaskCard(t)),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'ĐANG CHỜ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (waitingTasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: Text(
                        'Không có công việc đang chờ.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  ...waitingTasks.map((t) => _buildActiveTaskCard(t)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTaskCard(TaskItem t) {
    final isAssigned = t.status == 'ASSIGNED';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () async {
          await context.push(AppRoutes.taskDetailPath(t.id));
          if (!mounted) return;
          ref.read(taskProvider.notifier).fetchTasks();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Phòng ${t.unitNumber} · ${_getFloorOf(t.unitNumber)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                StatusBadge(
                  text: isAssigned ? 'Đang chờ' : 'Đang làm',
                  color: isAssigned ? AppColors.primary : AppColors.warning,
                  backgroundColor: isAssigned ? AppColors.infoBg : AppColors.warningBg,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (t.description != null && t.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                t.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'Giao ngày ${_formatDate(t.assignedAt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  'Giao bởi: ${t.assignedByName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (isAssigned) ...[
              const SizedBox(height: 16),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Bắt đầu',
                        style: TextStyle(
                          fontSize: 14,
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Hoàn thành',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Hoàn thành',
                    style: TextStyle(
                      fontSize: 14,
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
}

/// Tab 2: Danh sách toàn bộ công việc và bộ lọc
class StaffTasksTab extends StatelessWidget {
  const StaffTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Công việc',
            subtitle: 'Danh sách công việc được giao',
          ),
          Expanded(child: TaskListBody()),
        ],
      ),
    );
  }
}
