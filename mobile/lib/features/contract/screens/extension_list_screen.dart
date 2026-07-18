import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';

/// UC08 - Màn danh sách yêu cầu gia hạn / hợp đồng (theo màn FID-11).
/// Chỉ MANAGER/LANDLORD (BR-16). Tab lọc theo trạng thái, tab "Chờ duyệt"
/// hiển thị số lượng; card bấm vào mở màn duyệt (UC09).
class ExtensionListScreen extends ConsumerStatefulWidget {
  const ExtensionListScreen({super.key});

  @override
  ConsumerState<ExtensionListScreen> createState() => _ExtensionListScreenState();
}

class _ExtensionListScreenState extends ConsumerState<ExtensionListScreen> {
  /// null = Tất cả; ngược lại 1 trong ACTIVE/EXPIRING/EXPIRED.
  String? _filter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(extensionListProvider.notifier).fetch());
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatCompactCurrency(double rent) {
    if (rent >= 1000000) {
      final val = rent / 1000000.0;
      return '${val.toStringAsFixed(1).replaceAll('.', ',')}M/th';
    }
    return '${(rent / 1000.0).toStringAsFixed(0)}k/th';
  }

  int _getRemainingDays(StayExtension ext) {
    final rawRemaining = ext.currentEndDate.difference(DateTime.now()).inDays;
    return rawRemaining >= 0 ? rawRemaining : 0;
  }

  /// Phân loại hợp đồng thực tế theo DB status (ACTIVE / EXPIRED) kết hợp số ngày còn lại.
  String _getVirtualStatus(StayExtension ext) {
    final remainingDays = _getRemainingDays(ext);
    if (remainingDays <= 0) {
      return 'EXPIRED'; // Hết hạn
    }
    if (remainingDays <= 30) {
      return 'EXPIRING'; // Sắp HH (ACTIVE nhưng còn <= 30 ngày)
    }
    return 'ACTIVE'; // Hiệu lực (ACTIVE và còn > 30 ngày)
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(extensionListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Hợp đồng',
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
    final allCount = all.length;
    final approvedCount = all.where((e) => _getVirtualStatus(e) == 'ACTIVE').length;
    final pendingCount = all.where((e) => _getVirtualStatus(e) == 'EXPIRING').length;
    final rejectedCount = all.where((e) => _getVirtualStatus(e) == 'EXPIRED').length;

    final filtered = _filter == null
        ? all
        : all.where((e) => _getVirtualStatus(e) == _filter).toList();

    return Column(
      children: [
        // Tab lọc pills
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabItem(
                  label: 'Tất cả ($allCount)',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                  selectedBgColor: const Color(0xFF1E293B),
                  selectedTextColor: Colors.white,
                  unselectedTextColor: const Color(0xFF64748B),
                  borderColor: const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 8),
                _buildTabItem(
                  label: 'Hiệu lực ($approvedCount)',
                  selected: _filter == 'ACTIVE',
                  onTap: () => setState(() => _filter = 'ACTIVE'),
                  selectedBgColor: const Color(0xFFF0FDF4),
                  selectedTextColor: const Color(0xFF16A34A),
                  unselectedTextColor: const Color(0xFF16A34A),
                  borderColor: const Color(0xFFBBF7D0),
                ),
                const SizedBox(width: 8),
                _buildTabItem(
                  label: 'Sắp HH ($pendingCount)',
                  selected: _filter == 'EXPIRING',
                  onTap: () => setState(() => _filter = 'EXPIRING'),
                  selectedBgColor: const Color(0xFFFFFBEB),
                  selectedTextColor: const Color(0xFFD97706),
                  unselectedTextColor: const Color(0xFFD97706),
                  borderColor: const Color(0xFFFEF3C7),
                ),
                const SizedBox(width: 8),
                _buildTabItem(
                  label: 'Hết hạn ($rejectedCount)',
                  selected: _filter == 'EXPIRED',
                  onTap: () => setState(() => _filter = 'EXPIRED'),
                  selectedBgColor: const Color(0xFFFEF2F2),
                  selectedTextColor: const Color(0xFFDC2626),
                  unselectedTextColor: const Color(0xFFDC2626),
                  borderColor: const Color(0xFFFEE2E2),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _filter == null
                        ? 'Chưa có hợp đồng nào.'
                        : 'Không có hợp đồng nào.',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(extensionListProvider.notifier).fetch(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildCard(filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color selectedBgColor,
    required Color selectedTextColor,
    required Color unselectedTextColor,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selectedBgColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedBgColor : borderColor,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? selectedTextColor : unselectedTextColor,
          ),
        ),
      ),
    );
  }

  /// 1 card yêu cầu / hợp đồng
  Widget _buildCard(StayExtension ext) {
    // Thu tiền thuê mock dựa trên id để đồng bộ giao diện
    final mockRent = 6000000.0 + (ext.id % 4) * 500000.0;

    // Thời hạn hợp đồng: Bắt đầu = (End Date - 1 năm), Kết thúc = End Date hiện tại
    final contractStartDate = ext.currentEndDate.subtract(const Duration(days: 365));

    // Phân loại trạng thái ảo
    final remainingDays = _getRemainingDays(ext);
    final virtualStatus = _getVirtualStatus(ext);

    late final StatusBadge statusBadge;
    if (virtualStatus == 'ACTIVE') {
      statusBadge = StatusBadge.success('Hiệu lực');
    } else if (virtualStatus == 'EXPIRING') {
      statusBadge = StatusBadge.warning('Còn $remainingDays ngày');
    } else {
      statusBadge = const StatusBadge(
        text: 'Hết hạn',
        color: AppColors.error,
        backgroundColor: AppColors.errorBg,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
          border: virtualStatus == 'EXPIRING'
              ? const Border(
                  left: BorderSide(color: Color(0xFFF59E0B), width: 4),
                )
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final reviewed = await context
                .push<bool>(AppRoutes.extensionDetailPath(ext.id));
            if (reviewed == true && mounted) {
              ref.read(extensionListProvider.notifier).fetch();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Căn hộ ${ext.unitNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    statusBadge,
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ext.residentName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                // 3 cột thông tin: Bắt đầu, Kết thúc, Tiền thuê
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Bắt đầu',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(contractStartDate),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Kết thúc',
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(ext.currentEndDate),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: virtualStatus == 'EXPIRING'
                                    ? const Color(0xFFD97706)
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Tiền thuê',
                              style: TextStyle(fontSize: 10, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCompactCurrency(mockRent),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Nút thao tác: nếu có yêu cầu gia hạn (PENDING) thì hiện cả Xem HĐ và Gia hạn ngay, ngược lại chỉ hiện Xem HĐ full width
                if (ext.status == 'PENDING')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final reviewed = await context.push<bool>(
                              AppRoutes.extensionDetailPath(ext.id),
                            );
                            if (reviewed == true && mounted) {
                              ref.read(extensionListProvider.notifier).fetch();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB), // Xanh nước biển
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(36),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Gia hạn ngay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
