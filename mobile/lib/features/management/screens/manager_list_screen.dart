import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/manager_member.dart';
import '../models/manager_stats.dart';
import '../providers/manager_notifier.dart';

/// UC41 (FID-41): Manager Management List Screen.
///
/// Displays a centralized list of all Manager accounts with:
/// - Gradient header with search bar (search by name/phone)
/// - Filter pills (All / Active / Inactive) with dynamic counts
/// - Summary stat cards (Total / Active / Inactive)
/// - Scrollable list of Manager cards with avatar, name, phone, status badge
/// - Tap card → navigate to Manager Detail (UC42)
///
/// Access: LANDLORD only (BR-60).
class ManagerListScreen extends ConsumerStatefulWidget {
  const ManagerListScreen({super.key});

  @override
  ConsumerState<ManagerListScreen> createState() => _ManagerListScreenState();
}

class _ManagerListScreenState extends ConsumerState<ManagerListScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Debounces search input to avoid excessive API calls (400ms delay).
  void _onSearchChanged(String keyword) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(managerDirectoryProvider.notifier).setSearch(keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(managerDirectoryProvider);
    final notifier = ref.read(managerDirectoryProvider.notifier);
    final stats = directory.value?.stats ?? ManagerStats.empty;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Quản lý',
            subtitle:
                '${stats.active} đang hoạt động · ${stats.inactive} đã vô hiệu',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.person_add_alt_1,
                tooltip: 'Thêm quản lý',
                onTap: () => context.push(AppRoutes.managerCreate),
              ),
            ],
            bottom: HeaderSearchBar(
              hint: 'Tìm tên, số điện thoại...',
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: FilterPills<String?>(
              pills: [
                FilterPill(value: null, label: 'Tất cả (${stats.total})'),
                FilterPill(
                  value: 'ACTIVE',
                  label: 'Đang hoạt động (${stats.active})',
                  color: AppColors.success,
                ),
                FilterPill(
                  value: 'INACTIVE',
                  label: 'Đã vô hiệu (${stats.inactive})',
                  color: AppColors.warning,
                ),
              ],
              selected: notifier.statusFilter,
              onSelected: notifier.setStatusFilter,
            ),
          ),
          Expanded(
            child: directory.when(
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
                        onPressed: notifier.refresh,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (result) => RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  children: [
                    // Summary stat cards
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Tổng số',
                            value: '${result.stats.total}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Đang hoạt động',
                            value: '${result.stats.active}',
                            valueColor: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Đã vô hiệu',
                            value: '${result.stats.inactive}',
                            valueColor: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Empty state or manager card list
                    if (result.managers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            (notifier.searchKeyword != null ||
                                    notifier.statusFilter != null)
                                ? AppStrings.msgManagerNoMatch
                                : AppStrings.msgManagerEmpty,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...result.managers.map(
                        (member) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ManagerCard(
                            member: member,
                            onTap: () => context.push(
                              AppRoutes.managerDetailPath(member.id),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual Manager account card in the list.
///
/// Displays avatar (with initials fallback), full name, phone number,
/// and an Active/Inactive status badge. Tappable to navigate to detail.
class _ManagerCard extends StatelessWidget {
  const _ManagerCard({required this.member, required this.onTap});

  final ManagerMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          InitialsAvatar(
            name: member.fullName,
            imageUrl: member.avatarUrl,
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.fullName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quản lý · ${member.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          member.isActive
              ? StatusBadge.success('Đang hoạt động')
              : StatusBadge.muted('Đã vô hiệu'),
        ],
      ),
    );
  }
}
