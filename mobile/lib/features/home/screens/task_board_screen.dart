import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/coming_soon.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../auth_profile/providers/auth_notifier.dart';

/// Khung danh sách công việc cho Staff — theo màn 19 trong thiết kế.
/// Dữ liệu Task thật sẽ nối khi làm Module 4 (Incident & Task).
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
                        'Nhân viên vận hành',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: .6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Xin chào, ${user?.fullName ?? 'Nhân viên'} 👋',
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
                tooltip: 'Đăng xuất',
                onTap: () => ref.read(authNotifierProvider.notifier).logout(),
              ),
            ],
          ),
          const Expanded(
            child: ComingSoon(
              icon: Icons.assignment,
              title: 'Công việc của tôi',
              moduleNote:
                  'danh sách công việc được giao sẽ có ở Module 4 (Incident & Task)',
            ),
          ),
        ],
      ),
    );
  }
}
