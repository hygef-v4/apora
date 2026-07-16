import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/tenancy_check_notifier.dart';

/// UC33 (FID-33): Nhận phòng (Check-in) căn hộ trống.
class ApartmentCheckinScreen extends ConsumerStatefulWidget {
  const ApartmentCheckinScreen({super.key, required this.apartmentId});

  final int apartmentId;

  @override
  ConsumerState<ApartmentCheckinScreen> createState() => _ApartmentCheckinScreenState();
}

class _ApartmentCheckinScreenState extends ConsumerState<ApartmentCheckinScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  late final TextEditingController _depositController;

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _depositController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      helpText: 'Chọn ngày bắt đầu hợp đồng',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        // Tự động set ngày kết thúc gợi ý là 1 năm sau nếu chưa chọn ngày kết thúc
        if (_endDate == null) {
          final nextYear = DateTime(picked.year + 1, picked.month, picked.day);
          _endDate = nextYear;
          _endDateController.text = DateFormat('yyyy-MM-dd').format(nextYear);
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 365)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: 'Chọn ngày kết thúc hợp đồng',
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final startStr = _startDateController.text.trim();
      final endStr = _endDateController.text.trim();
      final deposit = double.tryParse(_depositController.text.trim()) ?? 0.0;

      await ref.read(tenancyCheckProvider.notifier).processCheckIn(
            widget.apartmentId,
            fullName: name,
            phoneNumber: phone,
            startDate: startStr,
            endDate: endStr,
            depositValue: deposit,
          );

      final stateValue = ref.read(tenancyCheckProvider);
      if (stateValue.hasError) {
        throw stateValue.error!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhận phòng (Check-in) căn hộ thành công.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mapDioError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitLabel = _isLoading ? 'Đang thực hiện Check-in...' : 'Xác nhận Check-in';

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Nhận phòng (Check-in)',
            showBack: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Full name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên cư dân *',
                      hintText: 'Ví dụ: Nguyễn Văn A',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập họ tên cư dân.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone number
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại (Tài khoản) *',
                      hintText: 'Ví dụ: 0912345678',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập số điện thoại.';
                      }
                      if (!RegExp(r'^0\d{9}$').hasMatch(val.trim())) {
                        return 'Số điện thoại di động Việt Nam phải gồm 10 chữ số bắt đầu bằng 0.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contract Start Date
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: _selectStartDate,
                    decoration: const InputDecoration(
                      labelText: 'Ngày bắt đầu hợp đồng *',
                      hintText: 'Chọn ngày',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng chọn ngày bắt đầu.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contract End Date
                  TextFormField(
                    controller: _endDateController,
                    readOnly: true,
                    onTap: _selectEndDate,
                    decoration: const InputDecoration(
                      labelText: 'Ngày kết thúc hợp đồng *',
                      hintText: 'Chọn ngày',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng chọn ngày kết thúc.';
                      }
                      if (_startDate != null && _endDate != null && _startDate!.isAfter(_endDate!)) {
                        return 'Ngày kết thúc phải sau ngày bắt đầu.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Deposit Value
                  TextFormField(
                    controller: _depositController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tiền đặt cọc (VNĐ)',
                      hintText: 'Ví dụ: 10000000',
                      prefixIcon: Icon(Icons.security_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final num = double.tryParse(val.trim());
                        if (num == null || num < 0) {
                          return 'Tiền đặt cọc phải là số không âm.';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Business rule warning card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.lock_outline, color: AppColors.info, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cấp tài khoản & Mật khẩu mặc định (BR-01)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Hệ thống tự động khởi tạo tài khoản Resident với username là Số điện thoại và mật khẩu mặc định là "Apora@123". Cư dân sẽ buộc phải thay đổi mật khẩu ở lần đăng nhập đầu tiên.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(submitLabel),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Hủy bỏ'),
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
