import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth_profile/providers/auth_notifier.dart';

/// Placeholder Dashboard cho Landlord / Manager (UC01 bước 4).
/// Module 7 (Statistics & Dashboard) sẽ thay nội dung thật vào đây.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Xin chào, ${user?.fullName ?? 'Quản lý'}!',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.groups, size: 36),
              title: const Text('Quản lý nhân viên'),
              subtitle: const Text('Bảo vệ, lao công, kỹ thuật viên (UC36-UC40)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.staffList),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.bar_chart, size: 36),
              title: Text('Thống kê & Dashboard'),
              subtitle: Text('Sẽ bổ sung ở Module 7'),
              enabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
