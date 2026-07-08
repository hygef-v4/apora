import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../providers/profile_notifier.dart';

/// UC04: Xem hồ sơ cá nhân (FID-04) - read-only.
/// Muốn sửa phải bấm sang màn Update Profile (UC05).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(profileNotifierProvider.notifier).fetchProfile(),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'LANDLORD':
        return 'Chủ tòa nhà';
      case 'MANAGER':
        return 'Ban quản lý';
      case 'RESIDENT':
        return 'Cư dân';
      case 'SECURITY_GUARD':
        return 'Bảo vệ';
      case 'JANITOR':
        return 'Lao công';
      case 'TECHNICIAN':
        return 'Kỹ thuật viên';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa hồ sơ',
            onPressed: () => context.push(AppRoutes.profileEdit),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(mapDioError(error), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(profileNotifierProvider.notifier).fetchProfile(),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null
                      ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              // Các trường read-only theo BR trong SRS (sửa phải qua UC05)
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('Họ và tên'),
                subtitle: Text(user.fullName),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Số điện thoại'),
                subtitle: Text(user.phoneNumber),
              ),
              ListTile(
                leading: const Icon(Icons.verified_user),
                title: const Text('Vai trò'),
                subtitle: Text(user.roles.map(_roleLabel).join(', ')),
              ),
            ],
          );
        },
      ),
    );
  }
}
