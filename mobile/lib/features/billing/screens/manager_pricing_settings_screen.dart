import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/network/dio_client.dart'; // Để sử dụng dioProvider hoặc mapDioError

class ManagerPricingSettingsScreen extends ConsumerStatefulWidget {
  const ManagerPricingSettingsScreen({super.key});

  @override
  ConsumerState<ManagerPricingSettingsScreen> createState() => _ManagerPricingSettingsScreenState();
}

class _ManagerPricingSettingsScreenState extends ConsumerState<ManagerPricingSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = true;
  bool _isSaving = false;

  final _electricityController = TextEditingController();
  final _waterController = TextEditingController();
  final _mgmtFeeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPricingSettings();
  }

  @override
  void dispose() {
    _electricityController.dispose();
    _waterController.dispose();
    _mgmtFeeController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadPricingSettings() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/bills/active-pricing');
      
      final data = response.data['data'];
      
      if (mounted) {
        setState(() {
          _electricityController.text = (double.tryParse(data['electricity_rate'].toString())?.toInt() ?? 0).toString();
          _waterController.text = (double.tryParse(data['water_rate'].toString())?.toInt() ?? 0).toString();
          _mgmtFeeController.text = (double.tryParse(data['mgmt_fee'].toString())?.toInt() ?? 0).toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Lỗi tải cấu hình đơn giá: $e');
      }
    }
  }

  Future<void> _savePricingSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final router = Navigator.of(context);

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/bills/active-pricing', data: {
        'electricity_rate': double.parse(_electricityController.text.trim()),
        'water_rate': double.parse(_waterController.text.trim()),
        'mgmt_fee': double.parse(_mgmtFeeController.text.trim()),
      });

      _showMessage('Cập nhật cấu hình đơn giá thành công!');
      if (router.canPop()) {
        router.pop();
      }
    } catch (e) {
      _showMessage('Lỗi khi lưu đơn giá: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Cấu Hình Đơn Giá', showBack: true),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thiết lập biểu phí dịch vụ tòa nhà',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Thay đổi này sẽ được áp dụng cho tất cả hóa đơn phát sinh từ thời điểm lưu cấu hình mới.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.bolt, color: Colors.orange, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Đơn giá Điện (đ/kWh) *',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _electricityController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Ví dụ: 2000',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    suffixText: 'đ/kWh',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Vui lòng nhập đơn giá điện.';
                                    }
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n < 0) {
                                      return 'Đơn giá điện không hợp lệ.';
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
                                const Row(
                                  children: [
                                    Icon(Icons.water_drop, color: Colors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Đơn giá Nước (đ/m³) *',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _waterController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Ví dụ: 2166',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    suffixText: 'đ/m³',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Vui lòng nhập đơn giá nước.';
                                    }
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n < 0) {
                                      return 'Đơn giá nước không hợp lệ.';
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
                                const Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings, color: AppColors.success, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Phí Quản lý & Vận hành (đ/tháng) *',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _mgmtFeeController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Ví dụ: 150000',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    suffixText: 'đ/tháng',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Vui lòng nhập phí quản lý.';
                                    }
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n < 0) {
                                      return 'Phí quản lý không hợp lệ.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _savePricingSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'LƯU CẤU HÌNH ĐƠN GIÁ',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
