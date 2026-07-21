import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/apartment.dart';
import '../providers/apartment_notifier.dart';
import '../providers/tenancy_check_notifier.dart';

/// UC33 (FID-33): Check-in Apartment (Assign New Owner).
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
      helpText: 'Select contract start date',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
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
      helpText: 'Select contract end date',
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
          const SnackBar(content: Text('Apartment check-in processed successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mapDioError(e)),
            backgroundColor: AppColors.error,
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
    final apartments = ref.watch(apartmentDirectoryProvider).value ?? [];
    final apt = apartments.cast<Apartment?>().firstWhere(
          (a) => a?.id == widget.apartmentId,
          orElse: () => null,
        );

    final unitNumber = apt?.unitNumber ??
        ref.watch(apartmentDetailProvider).value?.unitNumber ??
        '${widget.apartmentId}';

    final submitLabel = _isLoading ? 'PROCESSING...' : 'Confirm Check-in';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(
            title: 'ASSIGN NEW OWNER',
            showBack: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  // 1. Selected Unit Card
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.apartment,
                            size: 26,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SELECTED UNIT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Room $unitNumber',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Form Fields Card
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Full Name
                        _buildFieldLabel('Full name'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: _buildInputDecoration(
                            hintText: 'Johnathan Doe',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter full name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Phone Number
                        _buildFieldLabel('Phone number'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _buildInputDecoration(
                            hintText: '+1 (555) 000-0000',
                            prefixIcon: Icons.phone_outlined,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter phone number.';
                            }
                            if (!RegExp(r'^\+?\d{9,12}$').hasMatch(val.trim())) {
                              return 'Please enter a valid phone number (9-12 digits).';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Contract Start Date
                        _buildFieldLabel('Contract Start Date'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _startDateController,
                          readOnly: true,
                          onTap: _selectStartDate,
                          decoration: _buildInputDecoration(
                            hintText: 'MM/DD/YYYY',
                            prefixIcon: Icons.calendar_today_outlined,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please select start date.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Contract End Date
                        _buildFieldLabel('Contract End Date'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _endDateController,
                          readOnly: true,
                          onTap: _selectEndDate,
                          decoration: _buildInputDecoration(
                            hintText: 'MM/DD/YYYY',
                            prefixIcon: Icons.calendar_today_outlined,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please select end date.';
                            }
                            if (_startDate != null &&
                                _endDate != null &&
                                _startDate!.isAfter(_endDate!)) {
                              return 'End date must be after start date.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Deposit Value
                        _buildFieldLabel('Deposit Value'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _depositController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            hintText: 'Enter deposit value',
                            prefixText: 'đ ',
                          ),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final num = double.tryParse(val.trim());
                              if (num == null || num < 0) {
                                return 'Deposit value must be a non-negative number.';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),

                        // Dashed Info Box (Matching Wireframe)
                        CustomPaint(
                          painter: _DashedRectPainter(
                            color: AppColors.border,
                            strokeWidth: 1.5,
                            gap: 4.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'A resident account will be created with default password. The new owner will receive a notification to set up their profile.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border, width: 1.5),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            submitLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    IconData? prefixIcon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.textTertiary,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary)
          : null,
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}

/// Custom painter for rendering a dashed rectangle border around the info box
class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
  });

  final Color color;
  final double strokeWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(8),
      ));

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = distance + gap > metric.length ? metric.length - distance : gap;
        canvas.drawPath(
          metric.extractPath(distance, distance + len),
          paint,
        );
        distance += gap * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap;
  }
}

