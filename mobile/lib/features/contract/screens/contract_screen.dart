import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';

/// UC06 - Màn xem hợp đồng / thời hạn lưu trú (theo màn FID-09).
/// Mọi role xem được hợp đồng của CHÍNH MÌNH (BR-23); nút gia hạn
/// chỉ hiện cho RESIDENT với hợp đồng ACTIVE (BR-09/BR-12).
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
    return '$buffer đ';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myContractProvider);
    final roles = ref.watch(authNotifierProvider).roles;
    final isResident = roles.contains('RESIDENT');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Hợp Đồng Của Tôi',
            subtitle: 'Thời hạn thuê & gia hạn lưu trú',
            showBack: true,
          ),
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
            'Tài khoản của bạn chưa gắn với căn hộ nào.',
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
        padding: const EdgeInsets.all(14),
        children: [
          // 1. Thông tin căn hộ (FID-09 field 1-3)
          if (apartment != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Thông tin căn hộ'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.infoBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.apartment,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phòng ${apartment.unitNumber}',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary),
                            ),
                            Text(
                              'Tầng ${apartment.floor}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      _apartmentBadge(apartment.status),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),

          // 2. Chi tiết hợp đồng (FID-09 field 4-7); AT2: chưa có hợp đồng
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: _SectionTitle('Chi tiết hợp đồng')),
                    if (contract != null)
                      contract.status == 'ACTIVE'
                          ? (contract.remainingDays != null && contract.remainingDays! <= 30
                              ? StatusBadge.warning('Sắp hết hạn')
                              : StatusBadge.success(kContractStatusLabels[contract.status]!))
                          : StatusBadge.muted(
                              kContractStatusLabels[contract.status] ??
                                  contract.status),
                  ],
                ),
                const SizedBox(height: 10),
                if (contract == null)
                  const Text(
                    'Căn hộ này chưa có hợp đồng thuê. Vui lòng liên hệ Ban quản lý.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  )
                else ...[
                  _InfoRow(
                    icon: Icons.play_circle_outline,
                    label: 'Ngày bắt đầu',
                    value: _formatDate(contract.startDate),
                  ),
                  _InfoRow(
                    icon: Icons.flag_outlined,
                    label: 'Ngày kết thúc',
                    value: _formatDate(contract.endDate),
                  ),
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Giá thuê',
                    value: '${_formatMoney(contract.baseRent)}/tháng',
                  ),
                ],
              ],
            ),
          ),

          // 3. Thời hạn còn lại - chỉ khi ACTIVE (BR-12, AT1 ẩn khi EXPIRED)
          if (contract != null && contract.isActive) ...[
            const SizedBox(height: 10),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Thời hạn còn lại'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: contract.elapsedRatio,
                      minHeight: 10,
                      backgroundColor: AppColors.divider,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(contract.startDate),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                      Text(
                        // BR-13: giá trị backend tính động lúc load
                        'Còn ${contract.remainingDays} ngày',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                      Text(
                        _formatDate(contract.endDate),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Đang có yêu cầu gia hạn chờ duyệt -> báo & khóa nút gửi thêm
          if (contract != null && contract.pendingExtensionId != null) ...[
            const SizedBox(height: 10),
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
                      'Bạn có một yêu cầu gia hạn đang chờ Ban quản lý duyệt.',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 4. Nút yêu cầu gia hạn - chỉ RESIDENT + hợp đồng ACTIVE
          //    (BR-09/BR-12; AT1 ẩn khi EXPIRED, AT2 ẩn khi chưa có hợp đồng)
          if (isResident &&
              contract != null &&
              contract.isActive &&
              contract.pendingExtensionId == null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.more_time),
                label: const Text('YÊU CẦU GIA HẠN',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _apartmentBadge(String status) {
    switch (status) {
      case 'OCCUPIED':
        return StatusBadge.success('Đang ở');
      case 'EMPTY':
        return StatusBadge.muted('Trống');
      default:
        return StatusBadge.muted('Ngừng dùng');
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Text(
            value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
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
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
