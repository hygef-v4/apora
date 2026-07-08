import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth_profile/providers/auth_notifier.dart';

/// Placeholder trang chủ Cư dân (UC01 bước 4: Resident -> Resident Home).
/// Các module Billing / Ticket / Communication sẽ gắn vào đây sau.
class ResidentHomeScreen extends ConsumerWidget {
  const ResidentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ Cư dân'),
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
          'Xin chào, ${user?.fullName ?? 'Cư dân'}!\n(Các tính năng sẽ bổ sung theo từng module)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
