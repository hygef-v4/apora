import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';

/// Màn danh sách TẤT CẢ hợp đồng cho Manager/Landlord (theo template màn 05).
/// Tab lọc: Tất cả / Hiệu lực / Sắp hết hạn / Hết hạn. Thẻ nào có yêu cầu
/// gia hạn đang chờ thì hiện nút "Duyệt gia hạn" -> màn duyệt (UC09).
class ContractListScreen extends ConsumerStatefulWidget {
  const ContractListScreen({super.key});

  @override
  ConsumerState<ContractListScreen> createState() => _ContractListScreenState();
}

class _ContractListScreenState extends ConsumerState<ContractListScreen> {
  /// null = Tất cả; ngược lại 1 trong ACTIVE / EXPIRING / EXPIRED.
  String? _filter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(allContractsProvider.notifier).fetch());
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatCompactRent(num rent) {
    if (rent >= 1000000) {
      final val = rent / 1000000.0;
      return '${val.toStringAsFixed(1).replaceAll('.', ',')}M/mo';
    }
    return '${(rent / 1000.0).toStringAsFixed(0)}k/mo';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allContractsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Contracts',
            subtitle: 'All lease contracts of residents',
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
                            ref.read(allContractsProvider.notifier).fetch(),
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

  Widget _buildList(List<ContractListItem> all) {
    final allCount = all.length;
    final activeCount = all.where((c) => c.bucket == 'ACTIVE').length;
    final expiringCount = all.where((c) => c.bucket == 'EXPIRING').length;
    final expiredCount = all.where((c) => c.bucket == 'EXPIRED').length;

    final filtered =
        _filter == null ? all : all.where((c) => c.bucket == _filter).toList();

    return Column(
      children: [
        // Tab lọc theo nhóm trạng thái (như template màn 05)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabItem(
                  label: 'All ($allCount)',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                  selectedBgColor: const Color(0xFF1E293B),
                  selectedTextColor: Colors.white,
                  unselectedTextColor: const Color(0xFF64748B),
                  borderColor: const Color(0xFFCBD5E1),
                ),
                const SizedBox(width: 8),
                _buildTabItem(
                  label: 'Active ($activeCount)',
                  selected: _filter == 'ACTIVE',
                  onTap: () => setState(() => _filter = 'ACTIVE'),
                  selectedBgColor: const Color(0xFFF0FDF4),
                  selectedTextColor: const Color(0xFF16A34A),
                  unselectedTextColor: const Color(0xFF16A34A),
                  borderColor: const Color(0xFFBBF7D0),
                ),
                const SizedBox(width: 8),
                _buildTabItem(
                  label: 'Expiring ($expiringCount)',
                  selected: _filter == 'EXPIRING',
                  onTap: () => setState(() => _filter = 'EXPIRING'),
                  selectedBgColor: const Color(0xFFFFFBEB),
                  selectedTextColor: const Color(0xFFD97706),
                  unselectedTextColor: const Color(0xFFD97706),
                  borderColor: const Color(0xFFFEF3C7),
                ),
                const SizedBox(width: 8),
                _buildTabItem(
                  label: 'Expired ($expiredCount)',
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
                        ? 'No contracts yet.'
                        : 'No contracts in this group.',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(allContractsProvider.notifier).fetch(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildCard(filtered[index]),
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

  Widget _buildCard(ContractListItem c) {
    final bucket = c.bucket;

    late final StatusBadge statusBadge;
    if (bucket == 'ACTIVE') {
      statusBadge = StatusBadge.success('Active');
    } else if (bucket == 'EXPIRING') {
      statusBadge = StatusBadge.warning('${c.remainingDays} days left');
    } else {
      statusBadge = const StatusBadge(
        text: 'Expired',
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
          border: bucket == 'EXPIRING'
              ? const Border(left: BorderSide(color: Color(0xFFF59E0B), width: 4))
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Room ${c.unitNumber}',
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
                '${c.residentName} · Floor ${c.floor}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              // 3 cột: Bắt đầu / Kết thúc / Tiền thuê (dữ liệu thật)
              Row(
                children: [
                  _infoBox('Start', _formatDate(c.startDate)),
                  const SizedBox(width: 8),
                  _infoBox(
                    'End',
                    _formatDate(c.endDate),
                    valueColor: bucket == 'EXPIRING'
                        ? const Color(0xFFD97706)
                        : (bucket == 'EXPIRED'
                            ? AppColors.error
                            : AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  _infoBox(
                    'Rent',
                    _formatCompactRent(c.baseRent),
                    bg: const Color(0xFFEFF6FF),
                    labelColor: const Color(0xFF2563EB),
                    valueColor: const Color(0xFF2563EB),
                  ),
                ],
              ),
              // Có yêu cầu gia hạn chờ duyệt -> nút sang màn duyệt (UC09)
              if (c.pendingExtensionId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final reviewed = await context.push<bool>(
                        AppRoutes.extensionDetailPath(c.pendingExtensionId!),
                      );
                      if (reviewed == true && mounted) {
                        ref.read(allContractsProvider.notifier).fetch();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(38),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.more_time, size: 18),
                    label: const Text(
                      'Review Extension Request',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(
    String label,
    String value, {
    Color bg = const Color(0xFFF8FAFC),
    Color labelColor = AppColors.textSecondary,
    Color valueColor = AppColors.textPrimary,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: labelColor)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
