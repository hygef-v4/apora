import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';

/// UC08 - Màn danh sách yêu cầu gia hạn (theo màn FID-11).
/// Chỉ MANAGER/LANDLORD (BR-16). Tab lọc theo trạng thái, tab "Chờ duyệt"
/// hiển thị số lượng; card bấm vào mở màn duyệt (UC09).
class ExtensionListScreen extends ConsumerStatefulWidget {
  const ExtensionListScreen({super.key});

  @override
  ConsumerState<ExtensionListScreen> createState() =>
      _ExtensionListScreenState();
}

class _ExtensionListScreenState extends ConsumerState<ExtensionListScreen> {
  /// null = Tất cả; ngược lại 1 trong PENDING/APPROVED/REJECTED.
  String? _filter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(extensionListProvider.notifier).fetch());
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(extensionListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Yêu Cầu Gia Hạn',
            subtitle: 'Duyệt gia hạn lưu trú của cư dân',
            showBack: true,
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
                      Text(e.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () =>
                            ref.read(extensionListProvider.notifier).fetch(),
                        child: const Text('Thử lại'),
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
    final filtered = _filter == null
        ? all
        : all.where((e) => e.status == _filter).toList();

    return Column(
      children: [
        // 1. Tab lọc (FID-11 field 1) - tab Chờ duyệt kèm số lượng
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tất cả',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                _FilterChip(
                  label: pendingCount > 0
                      ? 'Chờ duyệt ($pendingCount)'
                      : 'Chờ duyệt',
                  selected: _filter == 'PENDING',
                  onTap: () => setState(() => _filter = 'PENDING'),
                ),
                _FilterChip(
                  label: 'Đã duyệt',
                  selected: _filter == 'APPROVED',
                  onTap: () => setState(() => _filter = 'APPROVED'),
                ),
                _FilterChip(
                  label: 'Từ chối',
                  selected: _filter == 'REJECTED',
                  onTap: () => setState(() => _filter = 'REJECTED'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              // AT1/AT2: empty state theo tab đang chọn
              ? Center(
                  child: Text(
                    _filter == null
                        ? 'Chưa có yêu cầu gia hạn nào.'
                        : 'Không có yêu cầu "${kExtensionStatusLabels[_filter]}" nào.',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(extensionListProvider.notifier).fetch(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildCard(filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }

  /// 1 card yêu cầu (FID-11 field 2-9).
  Widget _buildCard(StayExtension ext) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () async {
          // Bấm card -> màn duyệt UC09; duyệt xong quay lại thì refresh
          final reviewed = await context
              .push<bool>(AppRoutes.extensionDetailPath(ext.id));
          if (reviewed == true && mounted) {
            ref.read(extensionListProvider.notifier).fetch();
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ext.residentName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                ),
                _statusBadge(ext.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Phòng ${ext.unitNumber} · Tầng ${ext.floor}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            // Khoảng ngày + số ngày cộng thêm (FID-11 field 5-6)
            Row(
              children: [
                const Icon(Icons.event, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  '${_formatDate(ext.currentEndDate)}  →  ${_formatDate(ext.requestedEndDate)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(width: 8),
                Text(
                  '+${ext.extensionDays} ngày',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // FID-11 field 7-8: PENDING hiện ngày gửi, còn lại hiện ngày duyệt
            Text(
              ext.status == 'PENDING' || ext.reviewedAt == null
                  ? 'Gửi ngày ${_formatDate(ext.createdAt)}'
                  : 'Đã xử lý ngày ${_formatDate(ext.reviewedAt!)}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final label = kExtensionStatusLabels[status] ?? status;
    switch (status) {
      case 'PENDING':
        return StatusBadge.warning(label);
      case 'APPROVED':
        return StatusBadge.success(label);
      default:
        return const StatusBadge(
          text: 'Từ chối',
          color: AppColors.error,
          backgroundColor: AppColors.errorBg,
        );
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
