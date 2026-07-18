import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';

/// UC09 - Màn duyệt / từ chối yêu cầu gia hạn (theo màn FID-12).
/// Chỉ MANAGER/LANDLORD (BR-16). Duyệt sẽ dời end_date hợp đồng trong
/// 1 transaction ở backend (BR-17); từ chối bắt buộc lý do (AT1/AT2);
/// cư dân nhận thông báo kết quả (BR-18).
class ExtensionReviewScreen extends ConsumerStatefulWidget {
  const ExtensionReviewScreen({super.key, required this.extensionId});

  final int extensionId;

  @override
  ConsumerState<ExtensionReviewScreen> createState() =>
      _ExtensionReviewScreenState();
}

class _ExtensionReviewScreenState extends ConsumerState<ExtensionReviewScreen> {
  final _rejectController = TextEditingController();
  /// AT2: true khi bấm TỪ CHỐI mà chưa nhập lý do -> viền đỏ.
  bool _rejectError = false;
  bool _isSubmitting = false;
  /// Đã chốt duyệt/từ chối trong phiên này -> pop(true) cho màn UC08 refresh.
  bool _reviewed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(extensionDetailProvider.notifier).fetch(widget.extensionId));
  }

  @override
  void dispose() {
    _rejectController.dispose();
    super.dispose();
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _review(String action) async {
    if (action == 'REJECT' && _rejectController.text.trim().isEmpty) {
      // AT2: từ chối bắt buộc có lý do
      setState(() => _rejectError = true);
      return;
    }

    // Xác nhận trước khi chốt (duyệt là đổi hợp đồng, không hoàn tác được)
    final approved = action == 'APPROVE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? 'Duyệt yêu cầu?' : 'Từ chối yêu cầu?'),
        content: Text(approved
            ? 'Hợp đồng sẽ được gia hạn đến ngày kết thúc mới. Tiếp tục?'
            : 'Yêu cầu sẽ bị từ chối và cư dân nhận được lý do. Tiếp tục?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approved ? 'Duyệt' : 'Từ chối',
                style: TextStyle(
                    color: approved ? AppColors.success : AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _rejectError = false;
    });
    try {
      await ref.read(extensionDetailProvider.notifier).review(
            widget.extensionId,
            action: action,
            rejectReason: action == 'REJECT' ? _rejectController.text : null,
          );
      _reviewed = true;
      _showSnack(approved
          ? 'Đã duyệt yêu cầu gia hạn.'
          : 'Đã từ chối yêu cầu gia hạn.');
    } catch (e) {
      // AT3: hợp đồng hết hiệu lực / đã có người khác xử lý -> giữ màn hình
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(extensionDetailProvider);

    // Chặn back mặc định để trả kết quả _reviewed cho màn danh sách
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop(_reviewed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            const GradientHeader(
              title: 'Duyệt Yêu Cầu Gia Hạn',
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
                          onPressed: () => ref
                              .read(extensionDetailProvider.notifier)
                              .fetch(widget.extensionId),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (ext) {
                  if (ext == null) {
                    return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  return _buildContent(ext);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(StayExtensionDetail ext) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Trạng thái tổng (FID-12 field 1)
        Row(
          children: [
            Text(
              'Yêu cầu #GH-${ext.id}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const Spacer(),
            _statusBadge(ext.status),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Thông tin cư dân (FID-12 field 2)
        AppCard(
          child: Row(
            children: [
              InitialsAvatar(name: ext.residentName, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ext.residentName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text(
                      '${ext.residentPhone} · Phòng ${ext.unitNumber} · Tầng ${ext.floor}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Hợp đồng hiện tại (FID-12 field 3)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _SectionTitle('Hợp đồng hiện tại')),
                  ext.contractStatus == 'ACTIVE'
                      ? StatusBadge.success(
                          kContractStatusLabels[ext.contractStatus]!)
                      : StatusBadge.muted(
                          kContractStatusLabels[ext.contractStatus] ??
                              ext.contractStatus),
                ],
              ),
              const SizedBox(height: 10),
              _InfoRow(
                label: 'Thời hạn',
                value:
                    '${_formatDate(ext.contractStartDate)} - ${_formatDate(ext.contractEndDate)}',
              ),
              _InfoRow(
                label: 'Giá thuê',
                value: '${_formatMoney(ext.baseRent)}/tháng',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 4. Nội dung yêu cầu (FID-12 field 4-6)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Nội dung yêu cầu'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ngày kết thúc mới: ${_formatDate(ext.requestedEndDate)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gia hạn thêm +${ext.extensionDays} ngày '
                      '(từ ${_formatDate(ext.currentEndDate)})',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Lý do của cư dân:',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                ext.reason ?? '—',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                'Gửi ngày ${_formatDate(ext.createdAt)}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),

        // Kết quả đã xử lý (khi mở lại đơn APPROVED/REJECTED)
        if (!ext.isPending) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Kết quả xử lý'),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Người xử lý',
                  value: ext.reviewedByName ?? '—',
                ),
                if (ext.reviewedAt != null)
                  _InfoRow(
                    label: 'Ngày xử lý',
                    value: _formatDate(ext.reviewedAt!),
                  ),
                if (ext.rejectReason != null && ext.rejectReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Lý do từ chối: ${ext.rejectReason}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.error, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        ],

        // 5. Khối duyệt - chỉ khi còn PENDING (PRE-02)
        if (ext.isPending) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Xử lý yêu cầu'),
                const SizedBox(height: 10),
                // FID-12 field 7: lý do từ chối (bắt buộc khi TỪ CHỐI)
                TextField(
                  controller: _rejectController,
                  maxLines: 3,
                  maxLength: 500,
                  enabled: !_isSubmitting,
                  onChanged: (_) {
                    if (_rejectError) setState(() => _rejectError = false);
                  },
                  decoration: InputDecoration(
                    labelText: 'Lý do từ chối (bắt buộc khi từ chối)',
                    hintText: 'VD: Tòa nhà có kế hoạch cải tạo...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        // AT2: viền đỏ khi thiếu lý do
                        color:
                            _rejectError ? AppColors.error : AppColors.border,
                        width: _rejectError ? 2 : 1,
                      ),
                    ),
                  ),
                ),
                if (_rejectError)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      '(!) Cần nhập lý do từ chối.',
                      style: TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 8),
                // FID-12 field 8: ghi chú thông báo
                const Row(
                  children: [
                    Icon(Icons.notifications_active_outlined,
                        size: 14, color: AppColors.textTertiary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cư dân sẽ nhận thông báo ngay khi yêu cầu được duyệt hoặc từ chối.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // FID-12 field 10: TỪ CHỐI
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed:
                              _isSubmitting ? null : () => _review('REJECT'),
                          child: const Text('TỪ CHỐI',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // FID-12 field 9: DUYỆT
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed:
                              _isSubmitting ? null : () => _review('APPROVE'),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('DUYỆT',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
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
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
