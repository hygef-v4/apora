import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth_profile/providers/auth_notifier.dart';

/// Placeholder danh sách công việc cho Staff (Bảo vệ / Lao công / Kỹ thuật).
/// Module 4 (Incident & Task) sẽ thay nội dung thật vào đây.
class TaskBoardScreen extends ConsumerWidget {
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Hồ sơ cá nhân',
            onPressed: () => context.push(AppRoutes.profile),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Xin chào, ${user?.fullName ?? 'Nhân viên'}!\n(Danh sách công việc sẽ bổ sung ở Module 4)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
