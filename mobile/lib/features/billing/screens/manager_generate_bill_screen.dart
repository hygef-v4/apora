import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';

class ManagerGenerateBillScreen extends ConsumerStatefulWidget {
  const ManagerGenerateBillScreen({super.key});

  @override
  ConsumerState<ManagerGenerateBillScreen> createState() => _ManagerGenerateBillScreenState();
}

class _ManagerGenerateBillScreenState extends ConsumerState<ManagerGenerateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoadingContracts = true;
  bool _isSubmitting = false;
  List<dynamic> _contracts = [];
  Map<String, dynamic>? _selectedContract;

  final _monthYearController = TextEditingController(text: '07/2026');
  final _electricityController = TextEditingController();
  final _waterController = TextEditingController();
  final _extraFeeController = TextEditingController(text: '0');
  final _extraDescController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadActiveContracts();
  }

  @override
  void dispose() {
    _monthYearController.dispose();
    _electricityController.dispose();
    _waterController.dispose();
    _extraFeeController.dispose();
    _extraDescController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveContracts() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/bills/active-contracts');
      
      if (mounted) {
        setState(() {
          _contracts = response.data['data'] as List;
          _isLoadingContracts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContracts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải danh sách căn hộ: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedContract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn căn hộ cần lập hóa đơn.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = Navigator.of(context);

    try {
      final dio = ref.read(dioProvider);
      final data = {
        'apartmentId': _selectedContract!['apartment_id'],
        'monthYear': _monthYearController.text.trim(),
        'currElectricityIndex': double.parse(_electricityController.text.trim()),
        'currWaterIndex': double.parse(_waterController.text.trim()),
        'extraFee': double.parse(_extraFeeController.text.trim()),
        'extraFeeDescription': _extraDescController.text.trim().isEmpty ? null : _extraDescController.text.trim(),
      };

      await dio.post('/bills/generate', data: data);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('🚀 Sinh hóa đơn căn hộ thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      router.pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      String errMsg = 'Lập hóa đơn thất bại';
      if (e is DioException && e.response != null && e.response!.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      } else {
        errMsg = e.toString();
      }
      messenger.showSnackBar(
        SnackBar(content: Text('❌ Lỗi: $errMsg')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Lập Hóa Đơn',
            subtitle: 'Nhập chỉ số điện nước định kỳ',
            showBack: true,
          ),
          Expanded(
            child: _isLoadingContracts
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _contracts.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có căn hộ nào có hợp đồng thuê hoạt động.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '1. Chọn Căn Hộ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 12),
                                    DropdownButtonFormField<Map<String, dynamic>>(
                                      decoration: InputDecoration(
                                        labelText: 'Căn hộ - Cư dân',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      ),
                                      initialValue: _selectedContract,
                                      items: _contracts.map<DropdownMenuItem<Map<String, dynamic>>>((contract) {
                                        return DropdownMenuItem<Map<String, dynamic>>(
                                          value: contract as Map<String, dynamic>,
                                          child: Text('Căn ${contract['unit_number']} - ${contract['resident_name']}'),
                                        );
                                      }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedContract = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '2. Thông Tin Kỳ Thanh Toán',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _monthYearController,
                                    decoration: InputDecoration(
                                      labelText: 'Kỳ hóa đơn (Tháng/Năm)',
                                      hintText: 'MM/YYYY',
                                      prefixIcon: const Icon(Icons.calendar_month),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Vui lòng nhập kỳ hóa đơn.';
                                      if (!RegExp(r'^\d{2}/\d{4}$').hasMatch(val)) return 'Định dạng hợp lệ: MM/YYYY';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '3. Chỉ Số Tiêu Thụ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _electricityController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Chỉ số điện mới (kWh)',
                                      prefixIcon: const Icon(Icons.bolt, color: Colors.orange),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Vui lòng nhập chỉ số điện.';
                                      if (double.tryParse(val) == null) return 'Phải là số hợp lệ.';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _waterController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Chỉ số nước mới (m³)',
                                      prefixIcon: const Icon(Icons.water_drop, color: Colors.blue),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Vui lòng nhập chỉ số nước.';
                                      if (double.tryParse(val) == null) return 'Phải là số hợp lệ.';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '4. Chi Phí Khác (Tùy chọn)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _extraFeeController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Số tiền phát sinh (đ)',
                                      prefixIcon: const Icon(Icons.add_card),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (val) {
                                      if (val != null && val.trim().isNotEmpty && double.tryParse(val) == null) {
                                        return 'Phải là số hợp lệ.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _extraDescController,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      labelText: 'Lý do phát sinh',
                                      hintText: 'Ví dụ: Thay vòi nước hỏng, sửa bóng đèn...',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text(
                                        'TẠO VÀ SINH HÓA ĐƠN',
                                        style: TextStyle(fontWeight: FontWeight.bold),
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
