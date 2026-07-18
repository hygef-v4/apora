import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/apartment.dart';
import '../providers/apartment_notifier.dart';

/// UC29 (FID-29): Danh sách căn hộ.
/// Cho phép tìm kiếm theo số phòng hoặc tên chủ hộ.
/// Bộ lọc trạng thái: Tất cả, Trống, Đang ở, Nợ phí.
class ApartmentListScreen extends ConsumerStatefulWidget {
  const ApartmentListScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  ConsumerState<ApartmentListScreen> createState() => _ApartmentListScreenState();
}

class _ApartmentListScreenState extends ConsumerState<ApartmentListScreen> {
  Timer? _debounce;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String keyword) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(apartmentDirectoryProvider.notifier).setSearch(keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentDirectoryProvider);
    final notifier = ref.read(apartmentDirectoryProvider.notifier);
    final userRoles = ref.watch(authNotifierProvider).user?.roles ?? const [];
    final isLandlord = userRoles.contains('LANDLORD');

    // Tính toán thống kê nhanh từ danh sách dữ liệu thực tế
    final list = apartmentsAsync.value ?? [];
    final total = list.length;
    final empty = list.where((a) => a.status == 'EMPTY').length;
    final occupied = list.where((a) => a.status == 'OCCUPIED').length;
    final debt = list.where((a) => a.unpaidInvoiceCount > 0).length;

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Căn hộ',
            subtitle: '$occupied đang ở · $empty trống · $debt nợ phí',
            showBack: widget.showBack,
            actions: [
              if (isLandlord)
                HeaderIconButton(
                  icon: Icons.add_business,
                  tooltip: 'Thêm căn hộ',
                  onTap: () => context.push('/manager/apartments/create'),
                ),
            ],
            bottom: HeaderSearchBar(
              hint: 'Tìm số phòng, tên chủ hộ...',
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: FilterPills<String?>(
              pills: [
                FilterPill(value: null, label: 'Tất cả ($total)'),
                FilterPill(
                  value: 'EMPTY',
                  label: 'Phòng trống ($empty)',
                  color: AppColors.textSecondary,
                ),
                FilterPill(
                  value: 'OCCUPIED',
                  label: 'Đang ở ($occupied)',
                  color: AppColors.success,
                ),
                FilterPill(
                  value: 'HAS_DEBT',
                  label: 'Nợ phí ($debt)',
                  color: AppColors.warning,
                ),
              ],
              selected: notifier.statusFilter,
              onSelected: notifier.setStatusFilter,
            ),
          ),
          Expanded(
            child: apartmentsAsync.when(
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
                            label: 'Phòng Trống',
                            value: '$empty',
                            valueColor: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: StatCard(
                            label: 'Cần Thu Phí',
                            value: '$debt',
                            valueColor: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (result.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            'Không tìm thấy căn hộ nào khớp điều kiện.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...result.map(
                        (apt) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ApartmentCard(
                            apartment: apt,
                            onTap: () => context.push('/manager/apartments/${apt.id}'),
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

class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({required this.apartment, required this.onTap});

  final Apartment apartment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = apartment.status == 'OCCUPIED'
        ? 'Đang ở'
        : (apartment.status == 'EMPTY' ? 'Phòng trống' : 'Ngừng hoạt động');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: apartment.status == 'OCCUPIED'
                    ? [AppColors.success.withOpacity(0.2), AppColors.success.withOpacity(0.05)]
                    : [AppColors.textSecondary.withOpacity(0.2), AppColors.textSecondary.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.meeting_room,
              size: 22,
              color: apartment.status == 'OCCUPIED' ? AppColors.success : AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phòng ${apartment.unitNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tầng ${apartment.floor} · Diện tích: ${apartment.areaSize} m²',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (apartment.status == 'OCCUPIED' && apartment.ownerName != null) ...[
                  Text(
                    'Chủ hộ: ${apartment.ownerName}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Chưa có chủ hộ',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (apartment.unpaidInvoiceCount > 0 || apartment.unresolvedTicketCount > 0) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (apartment.unpaidInvoiceCount > 0)
                        StatusBadge.warning('${apartment.unpaidInvoiceCount} hoá đơn nợ'),
                      if (apartment.unresolvedTicketCount > 0)
                        StatusBadge.info('${apartment.unresolvedTicketCount} sự cố mở'),
                    ],
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 8),
          apartment.status == 'OCCUPIED'
              ? StatusBadge.success(statusLabel)
              : (apartment.status == 'EMPTY'
                  ? StatusBadge.muted(statusLabel)
                  : StatusBadge.warning(statusLabel)),
        ],
      ),
    );
  }
}
