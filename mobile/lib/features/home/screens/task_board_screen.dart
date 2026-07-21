import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../../ticket/screens/task_list_screen.dart';

/// Khung danh sách công việc cho Staff — theo màn 19 trong thiết kế.
/// Thân danh sách là TaskListBody (UC22 - Module 4).
class TaskBoardScreen extends ConsumerWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            titleWidget: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operations Staff',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: .6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Hello, ${user?.fullName ?? 'Staff'} 👋',
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
                  child: InitialsAvatar(
                    name: user?.fullName ?? '?',
                    imageUrl: user?.avatarUrl,
                    size: 44,
                    square: true,
                  ),
                ),
              ],
            ),
            actions: [
              HeaderIconButton(
                icon: Icons.logout,
                tooltip: 'Log out',
                onTap: () => ref.read(authNotifierProvider.notifier).logout(),
              ),
            ],
          ),
          // UC22: danh sách công việc được giao (filter + pull-to-refresh)
          const Expanded(child: TaskListBody()),
        ],
      ),
    );
  }
}
