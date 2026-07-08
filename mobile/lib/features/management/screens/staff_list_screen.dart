import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../models/staff_member.dart';
import '../models/staff_stats.dart';
import '../providers/staff_notifier.dart';

/// UC36 (FID-35): Danh sách nhân viên vận hành.
/// Stats cards + search (debounce) + tab lọc trạng thái + list card.
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

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý nhân viên')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.staffCreate),
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm nhân viên'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên hoặc số điện thoại...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String?>(
              segments: const [
                ButtonSegment(value: null, label: Text('Tất cả')),
                ButtonSegment(value: 'ACTIVE', label: Text('Đang làm việc')),
                ButtonSegment(value: 'INACTIVE', label: Text('Đã nghỉ')),
              ],
              selected: {notifier.statusFilter},
              onSelectionChanged: (selection) =>
                  notifier.setStatusFilter(selection.first),
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StatsRow(stats: result.stats),
                    const SizedBox(height: 16),
                    if (result.staff.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            (notifier.searchKeyword != null ||
                                    notifier.statusFilter != null)
                                ? AppStrings.msgStaffNoMatch
                                : AppStrings.msgStaffEmpty,
                          ),
                        ),
                      )
                    else
                      ...result.staff.map(
                        (member) => _StaffCard(
                          member: member,
                          onTap: () => context.push(
                            AppRoutes.staffDetailPath(member.id),
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

/// UC36: Staff Statistics Summary - 4 chỉ số tổng quan.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final StaffStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(label: 'Tổng số', value: stats.total, color: AppColors.primary),
        _StatCard(label: 'Đang làm', value: stats.active, color: Colors.green),
        _StatCard(label: 'Đã nghỉ', value: stats.inactive, color: Colors.grey),
        _StatCard(label: 'Việc mở', value: stats.openTasks, color: Colors.orange),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member, required this.onTap});

  final StaffMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage:
              member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
          child: member.avatarUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(member.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member.phoneNumber),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                _Badge(text: staffRoleLabel(member.role), color: AppColors.primary),
                _Badge(
                  text: member.isActive ? 'Đang làm việc' : 'Đã nghỉ',
                  color: member.isActive ? Colors.green : Colors.grey,
                ),
                if (member.openTaskCount > 0)
                  _Badge(
                    text: '${member.openTaskCount} việc đang mở',
                    color: Colors.orange,
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}
