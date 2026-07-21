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
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/staff_member.dart';
import '../models/staff_stats.dart';
import '../providers/staff_notifier.dart';
import '../repositories/staff_api_service.dart';

/// UC36 (FID-35): Staff Management — layout theo wireframe (header back + tiêu đề,
/// hàng "Staff Directory" + nút "Add Staff", lưới 4 ô thống kê, ô tìm kiếm,
/// pill All/Active/Inactive, card nhân viên có badge role + trạng thái và
/// hàng dưới "N open assigned tickets" · "Details").
/// Giao diện dùng lại design system Apora: GradientHeader, StatCard, AppCard,
/// FilterPills, StatusBadge.
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  Timer? _debounce;
  final _searchController = TextEditingController();

  /// Giữ lại số liệu lần tải gần nhất để lưới thống kê không nháy về 0
  /// trong lúc refresh (AsyncLoading không mang theo value cũ).
  StaffStats _lastStats = StaffStats.empty;

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
    final stats = directory.value?.stats;
    if (stats != null) _lastStats = stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Staff Management', showBack: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: notifier.refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                children: [
                  _DirectoryHeader(
                    onAdd: () => context.push(AppRoutes.staffCreate),
                  ),
                  const SizedBox(height: 14),
                  _StatsGrid(stats: _lastStats),
                  const SizedBox(height: 14),
                  _SearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: 12),
                  // ListView cha đã có lề 14 -> pill không cần lề riêng.
                  FilterPills<String?>(
                    padding: EdgeInsets.zero,
                    pills: const [
                      FilterPill(value: null, label: 'All'),
                      FilterPill(
                        value: 'ACTIVE',
                        label: 'Active',
                        color: AppColors.success,
                      ),
                      FilterPill(
                        value: 'INACTIVE',
                        label: 'Inactive',
                        color: AppColors.error,
                      ),
                    ],
                    selected: notifier.statusFilter,
                    onSelected: notifier.setStatusFilter,
                  ),
                  const SizedBox(height: 14),
                  ..._buildListSection(context, directory, notifier),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Phần danh sách: loading / lỗi / rỗng / các card nhân viên.
  List<Widget> _buildListSection(
    BuildContext context,
    AsyncValue<StaffListResult> directory,
    StaffDirectoryNotifier notifier,
  ) {
    return [
      directory.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            children: [
              Text(
                mapDioError(error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: notifier.refresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (result) {
          if (result.staff.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  (notifier.searchKeyword != null ||
                          notifier.statusFilter != null)
                      ? AppStrings.msgStaffNoMatch
                      : AppStrings.msgStaffEmpty,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (final member in result.staff)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StaffCard(
                    member: member,
                    onTap: () =>
                        context.push(AppRoutes.staffDetailPath(member.id)),
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }
}

/// Hàng tiêu đề danh mục: "Staff Directory" + nút "Add Staff" (wireframe).
class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Staff Directory',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Staff'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lưới 2x2 thống kê nhân sự (wireframe: Total / Active / Inactive / Open tickets).
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final StaffStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Total Staff',
                value: '${stats.total}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Active',
                value: '${stats.active}',
                valueColor: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: 'Inactive',
                value: '${stats.inactive}',
                valueColor: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                label: 'Open Assigned Tickets',
                value: '${stats.openTasks}',
                valueColor: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Ô tìm kiếm luôn hiển thị trong thân trang (wireframe), thay cho nút search ở header.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: const InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 13),
          icon: Icon(Icons.search, size: 18, color: AppColors.textTertiary),
          hintText: 'Search staff name or phone',
          hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

/// Card nhân viên theo wireframe: avatar + tên/SĐT bên trái, badge role và
/// trạng thái xếp dọc bên phải, hàng dưới là số việc đang mở + link "Details".
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
    if (!member.isActive) return AppColors.textTertiary; // Nhân viên nghỉ việc
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

  /// Badge role: tint theo role, chuyển xám khi nhân viên đã nghỉ việc.
  StatusBadge _roleBadge() {
    final label = staffRoleLabel(member.role).toUpperCase();
    if (!member.isActive) return StatusBadge.muted(label);
    switch (member.role) {
      case 'SECURITY_GUARD':
        return StatusBadge.info(label);
      case 'JANITOR':
        return StatusBadge.success(label);
      case 'TECHNICIAN':
        return StatusBadge(
          text: label,
          color: AppColors.purple,
          backgroundColor: AppColors.purpleBg,
        );
      default:
        return StatusBadge.muted(label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOpenTasks = member.openTaskCount > 0;
    final taskLabel = member.openTaskCount == 1
        ? '1 open assigned ticket'
        : '${member.openTaskCount} open assigned tickets';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getStaffColor(member),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(member.fullName),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      member.phoneNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _roleBadge(),
                  const SizedBox(height: 5),
                  member.isActive
                      ? StatusBadge.success('ACTIVE')
                      : const StatusBadge(
                          text: 'INACTIVE',
                          color: AppColors.error,
                          backgroundColor: AppColors.errorBg,
                        ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 14,
                color: hasOpenTasks ? AppColors.warning : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  taskLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: hasOpenTasks ? FontWeight.w600 : FontWeight.w400,
                    color: hasOpenTasks
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const Text(
                'Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
