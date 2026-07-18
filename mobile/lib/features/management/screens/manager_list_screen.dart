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
      ref.read(managerDirectoryProvider.notifier).setSearch(keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(managerDirectoryProvider);
    final notifier = ref.read(managerDirectoryProvider.notifier);
    final stats = directory.value?.stats ?? ManagerStats.empty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            title: 'Quản lý',
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
                tooltip: 'Thêm quản lý',
                onTap: () => context.push(AppRoutes.managerCreate),
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
                  label: 'Vô hiệu hóa (${stats.inactive})',
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

class _ManagerCard extends StatelessWidget {
  const _ManagerCard({required this.member, required this.onTap});

  final ManagerMember member;
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

  Color _getManagerColor(ManagerMember member) {
    if (!member.isActive) return const Color(0xFF94A3B8); // Slate grey cho tài khoản nghỉ/vô hiệu
    return const Color(0xFF4F46E5); // Indigo cho active manager
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(member.fullName);
    final prefixColor = _getManagerColor(member);

    late final StatusBadge statusBadge;
    if (member.isActive) {
      statusBadge = StatusBadge.success('Hoạt động');
    } else {
      statusBadge = const StatusBadge(
        text: 'Vô hiệu hóa',
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
                  'Ban quản lý · ${member.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
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
