import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/contract.dart';
import '../providers/contract_provider.dart';
import '../../../core/widgets/spec_layout.dart';

/// UC07 - Request Stay Extension (bố cục theo wireframe FID-10 trong SRS).
/// Chỉ RESIDENT. Nhận MyContract (hợp đồng ACTIVE) từ màn UC06; validate
/// BR-14 (ngày mới phải sau ngày kết thúc hiện tại) + BR-15 (lý do 10-500).
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

  String _formatFloor(String floor) {
    final n = int.tryParse(floor.trim());
    if (n == null) return floor;
    final suffix = (n % 100 >= 11 && n % 100 <= 13)
        ? 'th'
        : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
    return '$n$suffix Floor';
  }

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
      _showSnack('Please select a new end date.');
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
      _showSnack('Extension request submitted successfully.');
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Request Stay Extension', showBack: true),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  // CURRENT CONTRACT - chỉ đọc (FID-10 field 1-2)
                  const SpecSectionHeader('Current Contract'),
                  if (apartment != null)
                    SpecDetailRow(
                      label: 'Apartment',
                      value: 'Room ${apartment.unitNumber} — '
                          '${_formatFloor(apartment.floor)}',
                    ),
                  SpecDetailRow(
                    label: 'Current End Date',
                    value: _formatDate(endDate),
                  ),
                  const SizedBox(height: 20),

                  // EXTENSION REQUEST (FID-10 field 3-7)
                  const SpecSectionHeader('Extension Request'),
                  const SizedBox(height: 8),
                  const SpecFieldLabel('New Desired End Date', required: true),
                  InkWell(
                    onTap: _isSubmitting ? null : _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          // AT1: viền đỏ khi ngày không hợp lệ
                          color:
                              _dateError ? AppColors.error : AppColors.border,
                          width: _dateError ? 2 : 1,
                        ),
                        color: AppColors.surface,
                      ),
                      child: Text(
                        _selectedDate == null
                            ? 'Select date...'
                            : _formatDate(_selectedDate!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedDate == null
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Hint (FID-10 field 4)
                  Text(
                    '(Must be after ${_formatDate(endDate)})',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (_dateError) ...[
                    const SizedBox(height: 6),
                    // AT1: inline error (FID-10 field 5)
                    const Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 14, color: AppColors.error),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'New date must be after the current contract end date',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),

                  // Lý do (FID-10 field 6-7, BR-15: 10-500 ký tự)
                  const SpecFieldLabel('Reason', required: true),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 4,
                    maxLength: 500,
                    enabled: !_isSubmitting,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter your reason for requesting an '
                          'extension... (min 10 characters)',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      // AT2: tối thiểu 10 ký tự
                      if ((val ?? '').trim().length < 10) {
                        return 'Reason must be at least 10 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),

                  // SUMMARY - thời gian gia hạn thêm (FID-10 field 8)
                  const SpecSectionHeader('Summary'),
                  SpecDetailRow(
                    label: 'Extension Period',
                    value: days == null ? '— days' : '+$days days',
                  ),
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
                      onPressed: _isSubmitting ? null : _submit,
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
                              'SUBMIT REQUEST',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: .5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // AT3: hủy - bỏ toàn bộ dữ liệu, quay về màn UC06
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : () => context.pop(),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
