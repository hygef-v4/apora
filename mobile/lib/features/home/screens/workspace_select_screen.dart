import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../../auth_profile/widgets/logout_confirm.dart';

/// Màn chọn workspace khi user giữ nhiều nhóm role
/// (vd: vừa Landlord vừa Resident - theo Software Design 1.1.2.A).
class WorkspaceSelectScreen extends ConsumerWidget {
  const WorkspaceSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Select Workspace',
            subtitle: 'Your account has multiple roles',
            actions: [
              HeaderIconButton(
                icon: Icons.logout,
                tooltip: 'Logout',
                onTap: () => confirmAndLogout(context, ref),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (user?.isManagement ?? false)
                  _WorkspaceCard(
                    icon: Icons.dashboard,
                    iconBg: AppColors.infoBg,
                    iconColor: AppColors.primary,
                    title: 'Building Management',
                    subtitle: 'Dashboard, apartments, staff',
                    onTap: () => context.go(AppRoutes.dashboard),
                  ),
                if (user?.isResident ?? false)
                  _WorkspaceCard(
                    icon: Icons.home,
                    iconBg: AppColors.successBg,
                    iconColor: AppColors.success,
                    title: 'Resident',
                    subtitle: 'Bills, issues, announcements',
                    onTap: () => context.go(AppRoutes.residentHome),
                  ),
                if (user?.isStaff ?? false)
                  _WorkspaceCard(
                    icon: Icons.handyman,
                    iconBg: AppColors.warningBg,
                    iconColor: AppColors.warning,
                    title: 'Operations Staff',
                    subtitle: 'Assigned tasks',
                    onTap: () => context.go(AppRoutes.tasks),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
