import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';
import '../widgets/spec_layout.dart';

/// UC09 - Extension Request Detail (bố cục theo wireframe FID-12 trong SRS).
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

  /// AT2: true khi bấm REJECT mà chưa nhập lý do -> viền đỏ.
  bool _rejectError = false;
  bool _isSubmitting = false;

  /// Đã chốt duyệt/từ chối trong phiên này -> pop(true) cho màn UC08 refresh.
  bool _reviewed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(extensionDetailProvider.notifier).fetch(widget.extensionId),
    );
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

  String _formatFloor(String floor) {
    final n = int.tryParse(floor.trim());
    if (n == null) return floor;
    final suffix = (n % 100 >= 11 && n % 100 <= 13)
        ? 'th'
        : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
    return '$n$suffix Floor';
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
        title: Text(approved ? 'Approve request?' : 'Reject request?'),
        content: Text(
          approved
              ? 'The contract will be extended to the new end date. Continue?'
              : 'The request will be rejected and the resident will receive '
                  'the reason. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              approved ? 'Approve' : 'Reject',
              style: TextStyle(
                color: approved ? AppColors.success : AppColors.error,
              ),
            ),
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
      _showSnack(
        approved
            ? 'Extension request approved.'
            : 'Extension request rejected.',
      );
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
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const GradientHeader(
              title: 'Extension Request Detail',
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
                          onPressed: () => ref
                              .read(extensionDetailProvider.notifier)
                              .fetch(widget.extensionId),
                          child: const Text('Retry'),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // Badge trạng thái đơn (FID-12 field 1)
        Align(
          alignment: Alignment.centerRight,
          child: _statusBadge(ext.status),
        ),
        const SizedBox(height: 14),

        // RESIDENT INFO (FID-12 field 2)
        const SpecSectionHeader('Resident Info'),
        const SizedBox(height: 6),
        _LabeledLine(label: 'Full Name', value: ext.residentName),
        _LabeledLine(label: 'Phone', value: ext.residentPhone),
        _LabeledLine(
          label: 'Apartment',
          value: 'Room ${ext.unitNumber} — ${_formatFloor(ext.floor)}',
        ),
        const SizedBox(height: 18),

        // CONTRACT INFO (FID-12 field 3)
        const SpecSectionHeader('Contract Info'),
        const SizedBox(height: 6),
        _LabeledLine(
          label: 'Contract Period',
          value: '${_formatDate(ext.contractStartDate)} — '
              '${_formatDate(ext.contractEndDate)}',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              const Text(
                'Contract Status: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              ext.contractStatus == 'ACTIVE'
                  ? (ext.currentEndDate.difference(DateTime.now()).inDays <= 30
                      ? StatusBadge.warning('Expiring Soon')
                      : StatusBadge.success('ACTIVE'))
                  : StatusBadge.muted(
                      ext.contractStatus == 'EXPIRED'
                          ? 'Expired'
                          : 'Terminated',
                    ),
            ],
          ),
        ),
        _LabeledLine(
          label: 'Base Rent',
          value: '${_formatMoney(ext.baseRent)} /month',
        ),
        const SizedBox(height: 18),

        // Khối EXTENSION REQUEST có viền (FID-12 field 4-6)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EXTENSION REQUEST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _LabeledLine(
                label: 'Current End Date',
                value: _formatDate(ext.currentEndDate),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Text(
                      'Requested End Date: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: AppColors.warningBg,
                      child: Text(
                        _formatDate(ext.requestedEndDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _LabeledLine(
                label: 'Duration',
                value: '+${ext.extensionDays} days',
              ),
              const SizedBox(height: 12),
              // Lý do của cư dân, trình bày dạng trích dẫn (wireframe)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${ext.reason ?? '—'}"',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Submitted: ${_formatDate(ext.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),

        // Kết quả đã xử lý (khi mở lại đơn APPROVED/REJECTED)
        if (!ext.isPending) ...[
          const SizedBox(height: 18),
          const SpecSectionHeader('Review Result'),
          const SizedBox(height: 6),
          _LabeledLine(
            label: 'Reviewed By',
            value: ext.reviewedByName ?? '—',
          ),
          if (ext.reviewedAt != null)
            _LabeledLine(
              label: 'Reviewed On',
              value: _formatDate(ext.reviewedAt!),
            ),
          if (ext.rejectReason != null && ext.rejectReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Reject Reason: ${ext.rejectReason}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                  height: 1.4,
                ),
              ),
            ),
        ],

        // ADMIN ACTION - chỉ khi còn PENDING (PRE-02)
        if (ext.isPending) ...[
          const SizedBox(height: 20),
          const SpecSectionHeader('Admin Action'),
          const SizedBox(height: 8),
          const SpecFieldLabel('Reject Reason (required if rejecting)'),
          // FID-12 field 7: lý do từ chối (bắt buộc khi REJECT)
          TextField(
            controller: _rejectController,
            maxLines: 3,
            maxLength: 500,
            enabled: !_isSubmitting,
            style: const TextStyle(fontSize: 13),
            onChanged: (_) {
              if (_rejectError) setState(() => _rejectError = false);
            },
            decoration: InputDecoration(
              hintText: 'Enter reason for rejection...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  // AT2: viền đỏ khi thiếu lý do
                  color: _rejectError ? AppColors.error : AppColors.border,
                  width: _rejectError ? 2 : 1,
                ),
              ),
            ),
          ),
          if (_rejectError)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'A rejection reason is required.',
                style: TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ),
          const SizedBox(height: 8),
          // FID-12 field 8: ghi chú thông báo
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.textTertiary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'A push notification will be sent to the resident upon '
                  'approval or rejection.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              // FID-12 field 9: APPROVE
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : () => _review('APPROVE'),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'APPROVE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: .5,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // FID-12 field 10: REJECT
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : () => _review('REJECT'),
                    child: const Text(
                      'REJECT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'PENDING':
        return StatusBadge.warning('PENDING');
      case 'APPROVED':
        return StatusBadge.success('APPROVED');
      default:
        return const StatusBadge(
          text: 'REJECTED',
          color: AppColors.error,
          backgroundColor: AppColors.errorBg,
        );
    }
  }
}

/// Dòng "Nhãn: giá trị" viết liền một hàng (theo wireframe UC09).
class _LabeledLine extends StatelessWidget {
  const _LabeledLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
