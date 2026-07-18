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
import '../../../core/widgets/status_badge.dart';
import '../models/staff_member.dart';
import '../models/staff_stats.dart';
import '../providers/staff_notifier.dart';

/// UC36 (FID-35): Danh sách nhân viên vận hành — style giống hệt trang Căn hộ:
/// header gradient chứa title + nút search toggle, filter pills, card chữ nhật bo góc 12px
/// với 2 status: "Hoạt động" màu xanh lá và "Nghỉ việc" màu đỏ.
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  Timer? _debounce;
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            title: 'Nhân viên',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.search,
                tooltip: 'Tìm kiếm',
                onTap: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      notifier.setSearch('');
                    }
                  });
                },
              ),
              HeaderIconButton(
                icon: Icons.add,
                tooltip: 'Thêm nhân viên',
                onTap: () => context.push(AppRoutes.staffCreate),
              ),
            ],
            bottom: _showSearch
                ? HeaderSearchBar(
                    hint: 'Tìm tên, số điện thoại...',
                    onChanged: _onSearchChanged,
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: FilterPills<String?>(
              pills: [
                FilterPill(value: null, label: 'Tất cả (${stats.total})'),
                FilterPill(
                  value: 'ACTIVE',
                  label: 'Hoạt động (${stats.active})',
                  color: AppColors.success,
                ),
                FilterPill(
                  value: 'INACTIVE',
                  label: 'Nghỉ việc (${stats.inactive})',
                  color: AppColors.error,
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

/// Card nhân viên: dùng box chữ nhật bo góc giống _ApartmentCard để làm giao diện đồng bộ.
class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member, required this.onTap});

  final StaffMember member;
  final VoidCallback onTap;

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      return '${parts[0][0]}${parts[1][0]}${parts[2][0]}'.toUpperCase();
    } else if (parts.length == 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.substring(0, parts.first.length.clamp(0, 3)).toUpperCase();
  }

  Color _getStaffColor(StaffMember member) {
    if (!member.isActive) return const Color(0xFF94A3B8); // Slate grey cho nhân viên nghỉ việc
    switch (member.role) {
      case 'SECURITY_GUARD':
        return const Color(0xFF3B82F6); // Xanh dương
      case 'JANITOR':
        return const Color(0xFF10B981); // Xanh lá Emerald
      case 'TECHNICIAN':
        return const Color(0xFF8B5CF6); // Tím
      default:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(member.fullName);
    final prefixColor = _getStaffColor(member);

    late final StatusBadge statusBadge;
    if (member.isActive) {
      statusBadge = StatusBadge.success('Hoạt động');
    } else {
      statusBadge = const StatusBadge(
        text: 'Nghỉ việc',
        color: AppColors.error,
        backgroundColor: AppColors.errorBg,
      );
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: prefixColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
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
                  Text(
                    '${member.openTaskCount} việc đang mở',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          statusBadge,
        ],
      ),
    );
  }
}
