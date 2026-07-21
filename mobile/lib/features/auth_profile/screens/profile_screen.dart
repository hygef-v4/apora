import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../providers/profile_notifier.dart';
import '../widgets/logout_confirm.dart';

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
        return 'Landlord';
      case 'MANAGER':
        return 'Manager';
      case 'RESIDENT':
        return 'Resident';
      case 'SECURITY_GUARD':
        return 'Security Guard';
      case 'JANITOR':
        return 'Janitor';
      case 'TECHNICIAN':
        return 'Technician';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header: back trái + tiêu đề căn giữa (layout wireframe)
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.residentGradient,
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Row(
              children: [
                HeaderIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Text(
                    'Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Giữ tiêu đề cân giữa so với nút back
                const SizedBox(width: 36),
              ],
            ),
          ),
          Expanded(
            child: profile.when(
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
                        onPressed: () => ref
                            .read(profileNotifierProvider.notifier)
                            .fetchProfile(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  children: [
                    // Avatar tròn + tên + vai trò, căn giữa (layout wireframe)
                    Center(
                      child: InitialsAvatar(
                        name: data.fullName,
                        imageUrl: data.avatarUrl,
                        size: 96,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      data.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.roles.map(_roleLabel).join(' · '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Các trường read-only theo BR trong SRS (sửa phải qua UC05)
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.badge,
                            label: 'Full Name',
                            value: data.fullName,
                          ),
                          const Divider(height: 1, indent: 56),
                          _InfoRow(
                            icon: Icons.phone,
                            label: 'Phone Number (login)',
                            value: data.phoneNumber,
                          ),
                          const Divider(height: 1, indent: 56),
                          _InfoRow(
                            icon: Icons.verified_user,
                            label: 'Role',
                            value: data.roles.map(_roleLabel).join(', '),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nhóm điều hướng dạng hàng có mũi tên (layout wireframe)
                    if (data.roles.contains('RESIDENT')) ...[
                      _NavRow(
                        icon: Icons.people,
                        label: 'My Roommates',
                        onTap: () => context.push(AppRoutes.roommates),
                      ),
                      const SizedBox(height: 12),
                      _NavRow(
                        icon: Icons.description,
                        label: 'My Contract',
                        onTap: () => context.push(AppRoutes.myContract),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _NavRow(
                      icon: Icons.lock_reset,
                      label: 'Change Password',
                      onTap: () => context.push(AppRoutes.changePassword),
                    ),
                    const SizedBox(height: 24),

                    // Hành động chính / phụ ở cuối màn (layout wireframe)
                    FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.profileEdit),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Profile'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      // UC02: hỏi xác nhận trước khi đăng xuất (FID-02)
                      onPressed: () => confirmAndLogout(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Hàng điều hướng: icon + nhãn + mũi tên (theo wireframe).
class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.infoBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
