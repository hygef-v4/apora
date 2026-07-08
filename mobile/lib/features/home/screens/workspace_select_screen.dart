import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth_profile/providers/auth_notifier.dart';

/// Màn chọn workspace khi user giữ nhiều nhóm role
/// (vd: vừa Landlord vừa Resident - theo Software Design 1.1.2.A).
class WorkspaceSelectScreen extends ConsumerWidget {
  const WorkspaceSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn không gian làm việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (user?.isManagement ?? false)
            _WorkspaceCard(
              icon: Icons.dashboard,
              title: 'Quản lý tòa nhà',
              subtitle: 'Dashboard, căn hộ, nhân sự',
              onTap: () => context.go(AppRoutes.dashboard),
            ),
          if (user?.isResident ?? false)
            _WorkspaceCard(
              icon: Icons.home,
              title: 'Cư dân',
              subtitle: 'Hóa đơn, sự cố, bảng tin',
              onTap: () => context.go(AppRoutes.residentHome),
            ),
          if (user?.isStaff ?? false)
            _WorkspaceCard(
              icon: Icons.handyman,
              title: 'Nhân viên vận hành',
              subtitle: 'Công việc được giao',
              onTap: () => context.go(AppRoutes.tasks),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
