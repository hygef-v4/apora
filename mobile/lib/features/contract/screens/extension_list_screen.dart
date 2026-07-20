import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';

/// UC08 - Extension Requests (bố cục theo wireframe FID-11 trong SRS).
/// Chỉ MANAGER/LANDLORD (BR-16). Tab lọc theo TRẠNG THÁI ĐƠN
/// (All / Pending / Approved / Rejected); bấm card mở màn duyệt (UC09).
class ExtensionListScreen extends ConsumerStatefulWidget {
  const ExtensionListScreen({super.key});

  @override
  ConsumerState<ExtensionListScreen> createState() =>
      _ExtensionListScreenState();
}

class _ExtensionListScreenState extends ConsumerState<ExtensionListScreen> {
  /// null = All; ngược lại PENDING / APPROVED / REJECTED.
  String? _filter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(extensionListProvider.notifier).fetch());
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatFloor(String floor) {
    final n = int.tryParse(floor.trim());
    if (n == null) return floor;
    final suffix = (n % 100 >= 11 && n % 100 <= 13)
        ? 'th'
        : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
    return '$n$suffix Floor';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(extensionListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Extension Requests',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.filter_list,
                tooltip: 'Filter',
                onTap: () => ref.read(extensionListProvider.notifier).fetch(),
              ),
            ],
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        e.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(extensionListProvider.notifier).fetch(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (all) => _buildList(all),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<StayExtension> all) {
    final pendingCount = all.where((e) => e.status == 'PENDING').length;
    final filtered =
        _filter == null ? all : all.where((e) => e.status == _filter).toList();

    return Column(
      children: [
        // Thanh tab theo trạng thái đơn (wireframe: All / Pending (n) /
        // Approved / Rejected)
        Container(
          color: AppColors.surface,
          child: Row(
            children: [
              _TabItem(
                label: 'All',
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              _TabItem(
                label: 'Pending',
                badgeCount: pendingCount,
                selected: _filter == 'PENDING',
                onTap: () => setState(() => _filter = 'PENDING'),
              ),
              _TabItem(
                label: 'Approved',
                selected: _filter == 'APPROVED',
                onTap: () => setState(() => _filter = 'APPROVED'),
              ),
              _TabItem(
                label: 'Rejected',
                selected: _filter == 'REJECTED',
                onTap: () => setState(() => _filter = 'REJECTED'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              // AT1 (FID-11): danh sách rỗng
              ? const Center(
                  child: Text(
                    'No extension requests found.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(extensionListProvider.notifier).fetch(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildCard(filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(StayExtension ext) {
    final badge = switch (ext.status) {
      'APPROVED' => StatusBadge.success('APPROVED'),
      'REJECTED' => const StatusBadge(
          text: 'REJECTED',
          color: AppColors.error,
          backgroundColor: AppColors.errorBg,
        ),
      _ => StatusBadge.warning('PENDING'),
    };

    // Dòng chân card: đơn chờ duyệt hiện ngày gửi, đơn đã xử lý hiện ngày duyệt
    final footer = ext.reviewedAt != null
        ? 'Reviewed: ${_formatDate(ext.reviewedAt!)}'
        : 'Submitted: ${_formatDate(ext.createdAt)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final reviewed =
                await context.push<bool>(AppRoutes.extensionDetailPath(ext.id));
            if (reviewed == true && mounted) {
              ref.read(extensionListProvider.notifier).fetch();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(name: ext.residentName, seed: ext.id),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ext.residentName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Room ${ext.unitNumber} — ${_formatFloor(ext.floor)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    badge,
                  ],
                ),
                const SizedBox(height: 12),
                // FID-11 field 5-6: mốc ngày và số ngày cộng thêm
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_formatDate(ext.currentEndDate)} → '
                        '${_formatDate(ext.requestedEndDate)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '(+${ext.extensionDays} days)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  footer,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tab chữ có gạch chân khi đang chọn (theo wireframe).
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              if (badgeCount != null)
                Text(
                  '($badgeCount)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ô vuông chữ cái đầu của tên cư dân, gradient xoay vòng theo thiết kế.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.seed});

  final String name;
  final int seed;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final gradient =
        AppColors.avatarGradients[seed % AppColors.avatarGradients.length];
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
