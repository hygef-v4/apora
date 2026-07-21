import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';

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
        _showMessage('Failed to load pricing settings: $e');
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

      _showMessage('Pricing settings updated successfully!');
      if (router.canPop()) {
        router.pop();
      }
    } catch (e) {
      _showMessage('Error saving pricing settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const GradientHeader(title: 'Pricing Settings', showBack: true),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Building Utility & Service Rates',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Changes will apply to all newly generated bills from the moment new rates are saved.',
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
                                      'Electricity Rate (VND/kWh) *',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _electricityController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., 2000',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    suffixText: 'VND/kWh',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter electricity rate.';
                                    }
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n < 0) {
                                      return 'Invalid electricity rate.';
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
                                      'Water Rate (VND/m³) *',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _waterController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., 2166',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    suffixText: 'VND/m³',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter water rate.';
                                    }
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n < 0) {
                                      return 'Invalid water rate.';
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
                                      'Management & Service Fee (VND/month) *',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _mgmtFeeController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'e.g., 150000',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    suffixText: 'VND/month',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter management fee.';
                                    }
                                    final n = double.tryParse(val.trim());
                                    if (n == null || n < 0) {
                                      return 'Invalid management fee.';
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
                                elevation: 2,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'SAVE PRICING SETTINGS',
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
