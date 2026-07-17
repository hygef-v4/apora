import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';

/// UC07 - Màn gửi yêu cầu gia hạn lưu trú (theo màn FID-10). Chỉ RESIDENT.
/// Nhận MyContract (hợp đồng ACTIVE) từ màn UC06; validate BR-14 (ngày mới
/// phải sau ngày kết thúc hiện tại) + BR-15 (lý do 10-500 ký tự).
class RequestExtensionScreen extends ConsumerStatefulWidget {
  const RequestExtensionScreen({super.key, required this.myContract});

  final MyContract myContract;

  @override
  ConsumerState<RequestExtensionScreen> createState() =>
      _RequestExtensionScreenState();
}

class _RequestExtensionScreenState
    extends ConsumerState<RequestExtensionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime? _selectedDate;
  /// AT1: true khi ngày đã chọn không hợp lệ -> viền đỏ + inline error.
  bool _dateError = false;
  bool _isSubmitting = false;

  ContractInfo get _contract => widget.myContract.contract!;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// FID-10 field 8: số ngày gia hạn thêm; null khi chưa chọn/không hợp lệ.
  int? get _extensionDays {
    final picked = _selectedDate;
    if (picked == null || _dateError) return null;
    return picked.difference(_contract.endDate).inDays;
  }

  Future<void> _pickDate() async {
    final endDate = _contract.endDate;
    final now = DateTime.now();
    // Hợp đồng ACTIVE nhưng end_date đã qua (chưa có job auto-expire):
    // initialDate không được nhỏ hơn firstDate, lấy mốc muộn hơn
    final defaultInitial = endDate.add(const Duration(days: 1));
    final initial = defaultInitial.isBefore(now) ? now : defaultInitial;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? initial,
      // Cho chọn từ hôm nay để AT1 (chọn ngày <= end_date) thể hiện được lỗi
      firstDate: now,
      lastDate: initial.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
      // BR-14: phải SAU ngày kết thúc hiện tại (so theo ngày)
      _dateError = !picked.isAfter(endDate);
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    // AT2: lý do >= 10 ký tự (validator); AT1: ngày phải chọn và hợp lệ
    final reasonOk = _formKey.currentState!.validate();
    if (_selectedDate == null) {
      _showSnack('Vui lòng chọn ngày kết thúc mới.');
      return;
    }
    if (_dateError || !reasonOk) return; // inline error đã hiển thị

    final d = _selectedDate!;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    setState(() => _isSubmitting = true);
    try {
      await ref.read(myContractProvider.notifier).requestExtension(
            requestedEndDate: dateStr,
            reason: _reasonController.text,
          );
      _showSnack('Gửi yêu cầu gia hạn thành công.');
      if (mounted) context.pop(true); // POS-02: quay về màn UC06
    } catch (e) {
      // AT4: lỗi mạng/server - giữ nguyên dữ liệu đã nhập để gửi lại
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartment = widget.myContract.apartment;
    final endDate = _contract.endDate;
    final days = _extensionDays;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Yêu Cầu Gia Hạn',
            subtitle: 'Gia hạn thời gian lưu trú',
            showBack: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // 1. Hợp đồng hiện tại (read-only - FID-10 field 1-2)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hợp đồng hiện tại',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 10),
                        if (apartment != null)
                          _ReadonlyRow(
                            label: 'Căn hộ',
                            value:
                                'Phòng ${apartment.unitNumber} · Tầng ${apartment.floor}',
                          ),
                        _ReadonlyRow(
                          label: 'Ngày kết thúc hiện tại',
                          value: _formatDate(endDate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Ngày kết thúc mới (FID-10 field 3-5)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Ngày kết thúc mới *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _isSubmitting ? null : _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                // AT1: viền đỏ khi ngày không hợp lệ
                                color: _dateError
                                    ? AppColors.error
                                    : AppColors.border,
                                width: _dateError ? 2 : 1,
                              ),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month,
                                    size: 18, color: AppColors.primary),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedDate == null
                                      ? 'Chọn ngày...'
                                      : _formatDate(_selectedDate!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedDate == null
                                        ? AppColors.textTertiary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_dateError)
                          // AT1: inline error (FID-10 field 5)
                          const Text(
                            '(!) Ngày mới phải sau ngày kết thúc hợp đồng hiện tại.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.error),
                          )
                        else
                          // Hint (FID-10 field 4)
                          Text(
                            '(Phải sau ngày ${_formatDate(endDate)})',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textTertiary),
                          ),
                        const SizedBox(height: 10),
                        // Thời gian gia hạn thêm (FID-10 field 8)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.infoBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            days == null
                                ? 'Thời gian gia hạn thêm: — ngày'
                                : 'Thời gian gia hạn thêm: +$days ngày',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Lý do (FID-10 field 6-7, BR-15: 10-500 ký tự)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('2. Lý do gia hạn *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 4,
                          maxLength: 500,
                          enabled: !_isSubmitting,
                          decoration: InputDecoration(
                            hintText:
                                'VD: Công việc ổn định, muốn tiếp tục ở lại...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            // AT2: tối thiểu 10 ký tự
                            if ((val ?? '').trim().length < 10) {
                              return '(!) Lý do phải có ít nhất 10 ký tự.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('GỬI YÊU CẦU',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // AT3: hủy - bỏ toàn bộ dữ liệu, quay về màn UC06
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => context.pop(),
                      child: const Text('HỦY'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadonlyRow extends StatelessWidget {
  const _ReadonlyRow({required this.label, required this.value});

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
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
