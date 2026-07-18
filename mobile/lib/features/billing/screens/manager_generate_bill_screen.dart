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

  double _electricityRate = 0.0;
  double _waterRate = 0.0;
  double _mgmtFee = 0.0;

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
      final results = await Future.wait([
        dio.get('/bills/active-contracts'),
        dio.get('/bills/active-pricing'),
      ]);
      
      if (mounted) {
        setState(() {
          _contracts = results[0].data['data'] as List;
          
          final pricingData = results[1].data['data'];
          _electricityRate = double.parse(pricingData['electricity_rate'].toString());
          _waterRate = double.parse(pricingData['water_rate'].toString());
          _mgmtFee = double.parse(pricingData['mgmt_fee'].toString());

          _isLoadingContracts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContracts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải thông tin khởi tạo: $e')),
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
                                    if (_selectedContract != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Chỉ số ghi nhận kỳ trước:',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.bolt, color: Colors.orange, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Điện: ${double.tryParse(_selectedContract!['last_electricity_index'].toString())?.toInt() ?? 0} kWh',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                ),
                                                const SizedBox(width: 24),
                                                const Icon(Icons.water_drop, color: Colors.blue, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Nước: ${double.tryParse(_selectedContract!['last_water_index'].toString())?.toInt() ?? 0} m³',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                                      final current = double.tryParse(val);
                                      if (current == null) return 'Phải là số hợp lệ.';
                                      if (_selectedContract != null) {
                                        final last = double.tryParse(_selectedContract!['last_electricity_index'].toString()) ?? 0.0;
                                        if (current < last) return 'Không được nhỏ hơn chỉ số cũ (${last.toInt()}).';
                                      }
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
                                      final current = double.tryParse(val);
                                      if (current == null) return 'Phải là số hợp lệ.';
                                      if (_selectedContract != null) {
                                        final last = double.tryParse(_selectedContract!['last_water_index'].toString()) ?? 0.0;
                                        if (current < last) return 'Không được nhỏ hơn chỉ số cũ (${last.toInt()}).';
                                      }
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
                            const SizedBox(height: 16),
                            AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Thông Tin Đơn Giá & Dịch Vụ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildPriceInfoItem('Đơn giá Điện', '${_formatRate(_electricityRate)} đ/kWh', Icons.bolt, Colors.orange),
                                      _buildPriceInfoItem('Đơn giá Nước', '${_formatRate(_waterRate)} đ/m³', Icons.water_drop, Colors.blue),
                                      _buildPriceInfoItem('Phí quản lý', '${_formatRate(_mgmtFee)} đ/tháng', Icons.admin_panel_settings, AppColors.success),
                                    ],
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

  String _formatRate(double val) {
    final intVal = val.toInt();
    if (intVal >= 1000) {
      return intVal.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    }
    return intVal.toString();
  }

  Widget _buildPriceInfoItem(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
        ],
      ),
    );
  }
}
