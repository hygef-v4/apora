import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/contract.dart';
import '../../../core/widgets/spec_layout.dart';
import '../providers/contract_provider.dart';

/// UC06 - Contract Details (bố cục theo wireframe FID-09 trong SRS).
/// Mọi role xem hợp đồng của CHÍNH MÌNH (BR-23); nút gia hạn chỉ hiện
/// cho RESIDENT với hợp đồng ACTIVE (BR-09/BR-12).
class ContractScreen extends ConsumerStatefulWidget {
  const ContractScreen({super.key});

  @override
  ConsumerState<ContractScreen> createState() => _ContractScreenState();
}

class _ContractScreenState extends ConsumerState<ContractScreen> {
  @override
  void initState() {
    super.initState();
    // BR-13: fetch mỗi lần mở màn để số ngày còn lại luôn tính mới
    Future.microtask(() => ref.read(myContractProvider.notifier).fetch());
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatMoney(num amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '$buffer VND';
  }

  /// Wireframe hiển thị tầng dạng "4th Floor"; dữ liệu số thì thêm hậu tố
  /// thứ tự, dữ liệu chữ thì giữ nguyên.
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
    final state = ref.watch(myContractProvider);
    final roles = ref.watch(authNotifierProvider).roles;
    final isResident = roles.contains('RESIDENT');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Apartment Manager', showBack: true),
          Expanded(
            child: state.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => _ErrorRetry(
                message: e.toString(),
                onRetry: () => ref.read(myContractProvider.notifier).fetch(),
              ),
              data: (data) {
                if (data == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                return _buildContent(data, isResident);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(MyContract data, bool isResident) {
    final apartment = data.apartment;
    final contract = data.contract;

    if (apartment == null && contract == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Your account is not linked to any apartment yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(myContractProvider.notifier).fetch(),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          // Tiêu đề trang căn giữa (theo wireframe)
          const Center(
            child: Text(
              'Contract Details',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 22),

          // APARTMENT INFO (FID-09 field 1-3)
          if (apartment != null) ...[
            const SpecSectionHeader('Apartment Info'),
            SpecDetailRow(label: 'Unit Number', value: 'Room ${apartment.unitNumber}'),
            SpecDetailRow(label: 'Floor', value: _formatFloor(apartment.floor)),
            SpecDetailRow.widget(
              label: 'Status',
              child: _apartmentBadge(apartment.status),
            ),
            const SizedBox(height: 20),
          ],

          // CONTRACT DETAILS (FID-09 field 4-7); AT2: chưa có hợp đồng
          const SpecSectionHeader('Contract Details'),
          if (contract == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'This apartment has no lease contract yet. Please contact the management board.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else ...[
            SpecDetailRow.widget(
              label: 'Contract Status',
              child: contract.status == 'ACTIVE'
                  ? (contract.remainingDays != null &&
                          contract.remainingDays! <= 30
                      ? StatusBadge.warning('Expiring Soon')
                      : StatusBadge.success('Active'))
                  : StatusBadge.muted(
                      contract.status == 'EXPIRED' ? 'Expired' : 'Terminated',
                    ),
            ),
            SpecDetailRow(label: 'Start Date', value: _formatDate(contract.startDate)),
            SpecDetailRow(label: 'End Date', value: _formatDate(contract.endDate)),
            SpecDetailRow(
              label: 'Base Rent',
              value: '${_formatMoney(contract.baseRent)} /month',
            ),
          ],

          // REMAINING DURATION - chỉ khi ACTIVE (BR-12, AT1 ẩn khi EXPIRED)
          if (contract != null && contract.isActive) ...[
            const SizedBox(height: 22),
            _RemainingDurationBox(
              elapsedRatio: contract.elapsedRatio,
              startLabel: _formatDate(contract.startDate),
              endLabel: _formatDate(contract.endDate),
              // BR-13: giá trị backend tính động lúc load
              remainingDays: contract.remainingDays ?? 0,
            ),
          ],

          // Đang có yêu cầu chờ duyệt -> báo & khóa nút gửi thêm
          if (contract != null && contract.pendingExtensionId != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top, size: 18, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have an extension request awaiting approval.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Nút gia hạn - chỉ RESIDENT + hợp đồng ACTIVE (BR-09/BR-12;
          // AT1 ẩn khi EXPIRED, AT2 ẩn khi chưa có hợp đồng)
          if (isResident &&
              contract != null &&
              contract.isActive &&
              contract.pendingExtensionId == null) ...[
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  // AT3: sang màn UC07 kèm hợp đồng hiện tại
                  final submitted = await context.push<bool>(
                    AppRoutes.requestExtension,
                    extra: data,
                  );
                  if (submitted == true && mounted) {
                    ref.read(myContractProvider.notifier).fetch();
                  }
                },
                child: const Text(
                  'REQUEST STAY EXTENSION',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: .5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _apartmentBadge(String status) {
    switch (status) {
      case 'OCCUPIED':
        return StatusBadge.success('Occupied');
      case 'EMPTY':
        return StatusBadge.muted('Empty');
      default:
        return StatusBadge.muted('Inactive');
    }
  }
}

/// Khối "REMAINING DURATION" có viền: thanh tiến độ, mốc ngày và số ngày
/// còn lại in đậm ở giữa (theo wireframe).
class _RemainingDurationBox extends StatelessWidget {
  const _RemainingDurationBox({
    required this.elapsedRatio,
    required this.startLabel,
    required this.endLabel,
    required this.remainingDays,
  });

  final double elapsedRatio;
  final String startLabel;
  final String endLabel;
  final int remainingDays;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REMAINING DURATION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: elapsedRatio,
              minHeight: 16,
              backgroundColor: AppColors.divider,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                startLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                endLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              '$remainingDays DAYS REMAINING',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
