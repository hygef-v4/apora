import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/status_badge.dart';
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
    final user = profile.value;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            showBack: true,
            titleWidget: user == null
                ? const Text(
                    'Hồ sơ cá nhân',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    children: [
                      InitialsAvatar(
                        name: user.fullName,
                        imageUrl: user.avatarUrl,
                        size: 56,
                        square: true,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: user.roles
                                  .map((r) => StatusBadge(
                                        text: _roleLabel(r),
                                        color: Colors.white,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: .2),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            actions: [
              HeaderIconButton(
                icon: Icons.edit,
                tooltip: 'Chỉnh sửa hồ sơ',
                onTap: () => context.push(AppRoutes.profileEdit),
              ),
              HeaderIconButton(
                icon: Icons.logout,
                tooltip: 'Đăng xuất',
                // UC02: hỏi xác nhận trước khi đăng xuất (FID-02)
                onTap: () => confirmAndLogout(context, ref),
              ),
            ],
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
                        child: const Text('Thử lại'),
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Các trường read-only theo BR trong SRS (sửa phải qua UC05)
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.badge,
                            label: 'Họ và tên',
                            value: data.fullName,
                          ),
                          const Divider(height: 1, indent: 56),
                          _InfoRow(
                            icon: Icons.phone,
                            label: 'Số điện thoại (đăng nhập)',
                            value: data.phoneNumber,
                          ),
                          const Divider(height: 1, indent: 56),
                          _InfoRow(
                            icon: Icons.verified_user,
                            label: 'Vai trò',
                            value: data.roles.map(_roleLabel).join(', '),
                          ),
                        ],
                      ),
                    ),
                    if (data.roles.contains('RESIDENT')) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        onTap: () => context.push(AppRoutes.roommates),
                        child: const Row(
                          children: [
                            Icon(Icons.people,
                                size: 20, color: AppColors.primary),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Thành viên phòng',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        onTap: () => context.push(AppRoutes.myContract),
                        child: const Row(
                          children: [
                            Icon(Icons.description,
                                size: 20, color: AppColors.primary),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Hợp đồng của tôi',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppCard(
                      onTap: () => context.push(AppRoutes.changePassword),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_reset,
                              size: 20, color: AppColors.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Đổi mật khẩu',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: AppColors.textTertiary),
                        ],
                      ),
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
