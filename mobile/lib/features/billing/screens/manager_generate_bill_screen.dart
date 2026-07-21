import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
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
    _electricityController.addListener(_onFormChanged);
    _waterController.addListener(_onFormChanged);
    _extraFeeController.addListener(_onFormChanged);
    _loadActiveContracts();
  }

  @override
  void dispose() {
    _electricityController.removeListener(_onFormChanged);
    _waterController.removeListener(_onFormChanged);
    _extraFeeController.removeListener(_onFormChanged);
    _monthYearController.dispose();
    _electricityController.dispose();
    _waterController.dispose();
    _extraFeeController.dispose();
    _extraDescController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return double.tryParse(val.toString()) ?? 0.0;
  }

  double get _lastElec {
    if (_selectedContract == null) return 0.0;
    final val = _selectedContract!['last_electricity_index'] ?? _selectedContract!['lastElectricityIndex'];
    return _parseDouble(val);
  }

  double get _lastWater {
    if (_selectedContract == null) return 0.0;
    final val = _selectedContract!['last_water_index'] ?? _selectedContract!['lastWaterIndex'];
    return _parseDouble(val);
  }

  Future<void> _loadActiveContracts() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/bills/active-contracts');
      
      if (mounted) {
        setState(() {
          _contracts = res.data['data'] as List;
          _isLoadingContracts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingContracts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load initialization data: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedContract == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room / apartment.')),
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
          content: Text('🚀 Monthly bill generated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      router.pop();
    } catch (e) {
      setState(() => _isSubmitting = false);
      String errMsg = 'Failed to generate bill';
      if (e is DioException && e.response != null && e.response!.data != null) {
        errMsg = e.response!.data['message'] ?? errMsg;
      } else {
        errMsg = e.toString();
      }
      messenger.showSnackBar(
        SnackBar(content: Text('❌ Error: $errMsg')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          GradientHeader(
            title: 'Input Monthly Bills.',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.settings,
                tooltip: 'Pricing Settings',
                onTap: () => context.push(AppRoutes.pricingSettings),
              ),
            ],
          ),
          Expanded(
            child: _isLoadingContracts
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _contracts.isEmpty
                    ? const Center(
                        child: Text(
                          'No active rented apartments found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // SINGLE MAIN CARD: Utility Meter Input (Matching Mockup)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border, width: 1.0),
                                boxShadow: AppColors.cardShadow,
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Card Title (Matching Mockup: Utility Meter Input)
                                  const Text(
                                    'Utility Meter Input',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // FIELD 1: ROOM / APARTMENT
                                  const Text(
                                    'ROOM / APARTMENT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<Map<String, dynamic>>(
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      hintText: 'Select Room / Apartment',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    initialValue: _selectedContract,
                                    items: _contracts.map<DropdownMenuItem<Map<String, dynamic>>>((contract) {
                                      return DropdownMenuItem<Map<String, dynamic>>(
                                        value: contract as Map<String, dynamic>,
                                        child: Text(
                                          'Unit ${contract['unit_number']} - ${contract['resident_name']}',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedContract = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // FIELD 2: MONTH / YEAR
                                  const Text(
                                    'MONTH / YEAR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _monthYearController,
                                    decoration: InputDecoration(
                                      hintText: '07/2026',
                                      prefixIcon: const Icon(Icons.calendar_month, color: AppColors.textSecondary),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Please enter billing month.';
                                      if (!RegExp(r'^\d{2}/\d{4}$').hasMatch(val)) return 'Valid format: MM/YYYY';
                                      return null;
                                    },
                                  ),

                                  // Dotted Line Separator
                                  const SizedBox(height: 18),
                                  const Divider(height: 1, color: AppColors.border, thickness: 1),
                                  const SizedBox(height: 18),

                                  // FIELD 3: Previous Electricity Index & Current Reading Input
                                  Text(
                                    _selectedContract != null
                                        ? 'Previous Electricity Index: ${_lastElec.toInt()} kWh'
                                        : 'Previous Electricity Index: -- kWh',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _electricityController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'Enter current index',
                                      prefixIcon: const Icon(Icons.bolt, color: Colors.orange),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Please enter electricity reading.';
                                      final current = double.tryParse(val);
                                      if (current == null) return 'Must be a valid number.';
                                      if (_selectedContract != null && current < _lastElec) {
                                        return 'Cannot be lower than previous index (${_lastElec.toInt()}).';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // FIELD 4: Previous Water Index & Current Reading Input
                                  Text(
                                    _selectedContract != null
                                        ? 'Previous Water Index: ${_lastWater.toInt()} m³'
                                        : 'Previous Water Index: -- m³',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _waterController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'Enter current index',
                                      prefixIcon: const Icon(Icons.water_drop, color: Colors.blue),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Please enter water reading.';
                                      final current = double.tryParse(val);
                                      if (current == null) return 'Must be a valid number.';
                                      if (_selectedContract != null && current < _lastWater) {
                                        return 'Cannot be lower than previous index (${_lastWater.toInt()}).';
                                      }
                                      return null;
                                    },
                                  ),

                                  // Dotted Line Separator
                                  const SizedBox(height: 18),
                                  const Divider(height: 1, color: AppColors.border, thickness: 1),
                                  const SizedBox(height: 18),

                                  // FIELD 5: Extra Fee (Optional)
                                  const Text(
                                    'Extra Fee (Optional)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _extraFeeController,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                      hintText: 'e.g., 50,000 VND',
                                      prefixIcon: const Icon(Icons.add_card),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val != null && val.trim().isNotEmpty && double.tryParse(val) == null) {
                                        return 'Must be a valid number.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // FIELD 6: Fee Description (Optional)
                                  const Text(
                                    'Fee Description (Optional)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _extraDescController,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                      hintText: 'e.g., Replacement light bulb',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // SUBMIT BUTTON (ISSUE BILL 📄 - Matching Mockup)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _isSubmitting ? null : _submit,
                                icon: _isSubmitting
                                    ? const SizedBox.shrink()
                                    : const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                                label: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      )
                                    : const Text(
                                        'ISSUE BILL',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                                      ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 3,
                                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
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
