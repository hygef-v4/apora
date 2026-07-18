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
import '../models/staff_member.dart';
import '../models/staff_stats.dart';
import '../providers/staff_notifier.dart';

/// UC36 (FID-35): Danh sách nhân viên vận hành — style theo màn 04 "Cư dân":
/// header gradient chứa title + search bar, filter pills, card avatar gradient.
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String keyword) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(staffDirectoryProvider.notifier).setSearch(keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(staffDirectoryProvider);
    final notifier = ref.read(staffDirectoryProvider.notifier);
    final stats = directory.value?.stats ?? StaffStats.empty;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Nhân viên',
            subtitle: '${stats.active} đang làm việc · ${stats.inactive} đã nghỉ',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.person_add_alt_1,
                tooltip: 'Thêm nhân viên',
                onTap: () => context.push(AppRoutes.staffCreate),
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
                  label: 'Đang làm việc (${stats.active})',
                  color: AppColors.success,
                ),
                FilterPill(
                  value: 'INACTIVE',
                  label: 'Đã nghỉ (${stats.inactive})',
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
                            label: 'Việc mở',
                            value: '${result.stats.openTasks}',
                            valueColor: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (result.staff.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            (notifier.searchKeyword != null ||
                                    notifier.statusFilter != null)
                                ? AppStrings.msgStaffNoMatch
                                : AppStrings.msgStaffEmpty,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...result.staff.map(
                        (member) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StaffCard(
                            member: member,
                            onTap: () => context.push(
                              AppRoutes.staffDetailPath(member.id),
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

/// Card nhân viên theo màn 04: avatar tròn gradient + tên + phụ đề + badges.
class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member, required this.onTap});

  final StaffMember member;
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
                  '${staffRoleLabel(member.role)} · ${member.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (member.openTaskCount > 0) ...[
                  const SizedBox(height: 4),
                  StatusBadge.warning('${member.openTaskCount} việc đang mở'),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          member.isActive
              ? StatusBadge.success('Đang làm việc')
              : StatusBadge.muted('Đã nghỉ'),
        ],
      ),
    );
  }
}
