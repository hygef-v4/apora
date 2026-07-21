import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/apartment.dart';
import '../providers/apartment_notifier.dart';

/// UC31 / UC32 (FID-31 / FID-32): Create New Apartment / Update Apartment.
class ApartmentFormScreen extends ConsumerStatefulWidget {
  const ApartmentFormScreen({super.key, this.apartment});

  final Apartment? apartment;

  @override
  ConsumerState<ApartmentFormScreen> createState() => _ApartmentFormScreenState();
}

class _ApartmentFormScreenState extends ConsumerState<ApartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _floorController;
  late final TextEditingController _roomNumberController;
  late final TextEditingController _areaSizeController;
  late final TextEditingController _baseRentController;

  bool _isLoading = false;
  String? _roomNumberError;
  bool get _isEdit => widget.apartment != null;

  @override
  void initState() {
    super.initState();
    _floorController = TextEditingController(text: widget.apartment?.floor ?? '');
    _roomNumberController =
        TextEditingController(text: widget.apartment?.unitNumber ?? '');
    _areaSizeController = TextEditingController(
      text: widget.apartment != null ? widget.apartment!.areaSize.toStringAsFixed(0) : '',
    );
    _baseRentController = TextEditingController(
      text: widget.apartment != null ? widget.apartment!.baseRent.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _floorController.dispose();
    _roomNumberController.dispose();
    _areaSizeController.dispose();
    _baseRentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _roomNumberError = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final floor = _floorController.text.trim();
      final roomNumber = _roomNumberController.text.trim();
      final areaSize = double.parse(_areaSizeController.text.trim());
      final baseRent = double.parse(_baseRentController.text.trim());

      if (_isEdit) {
        // UC32: Update Apartment
        await ref.read(apartmentDetailProvider.notifier).updateApartment(
              widget.apartment!.id,
              floor: floor,
              roomNumber: roomNumber,
              areaSize: areaSize,
              baseRent: baseRent,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Apartment information updated successfully.')),
          );
          Navigator.of(context).pop();
        }
      } else {
        // UC31: Create New Apartment
        await ref.read(apartmentDirectoryProvider.notifier).createApartment(
              floor: floor,
              roomNumber: roomNumber,
              areaSize: areaSize,
              baseRent: baseRent,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New apartment created successfully.')),
          );
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      final errorMsg = mapDioError(e);
      if (errorMsg.contains('đã được sử dụng') || errorMsg.contains('already exists')) {
        setState(() {
          _roomNumberError = 'Room number must be unique.';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Update Apartment' : 'Create New Apartment';
    final submitLabel = _isLoading
        ? 'SAVING...'
        : (_isEdit ? 'SAVE CHANGES' : 'Create');

    final ownerDisplayName = _isEdit
        ? (widget.apartment?.ownerName != null && widget.apartment!.ownerName!.trim().isNotEmpty
            ? widget.apartment!.ownerName!.trim()
            : (widget.apartment?.status == 'EMPTY' ? 'No owner' : 'Unassigned'))
        : 'Unassigned';

    final apartmentStatus = _isEdit ? widget.apartment!.status : 'EMPTY';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: title,
            showBack: true,
            actions: [
              if (!_isEdit)
                HeaderIconButton(
                  icon: Icons.more_vert,
                  tooltip: 'More',
                  onTap: () {},
                )
              else
                HeaderIconButton(
                  icon: Icons.account_circle_outlined,
                  tooltip: 'Profile',
                  onTap: () {},
                ),
            ],
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Floor Number
                        _buildFieldLabel(_isEdit ? 'Floor Number' : 'FLOOR NUMBER'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _floorController,
                          decoration: _buildInputDecoration(
                            hintText: 'Enter floor number',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter floor number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 2. Room Number
                        _buildFieldLabel(_isEdit ? 'Room Number' : 'ROOM NUMBER'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _roomNumberController,
                          onChanged: (_) {
                            if (_roomNumberError != null) {
                              setState(() => _roomNumberError = null);
                            }
                          },
                          decoration: _buildInputDecoration(
                            hintText: 'Enter room number',
                            hasError: _roomNumberError != null,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter room number.';
                            }
                            return null;
                          },
                        ),
                        if (_roomNumberError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _roomNumberError!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // 3. Area Size (m²)
                        _buildFieldLabel(_isEdit ? 'Area Size' : 'AREA SIZE (M²)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _areaSizeController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _buildInputDecoration(
                            hintText: 'Enter area size (m²)',
                            suffixText: 'm²',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter area size.';
                            }
                            final num = double.tryParse(val.trim());
                            if (num == null || num <= 0) {
                              return 'Area size must be greater than 0.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 4. Base Rent
                        _buildFieldLabel(_isEdit ? 'Base Rent' : 'BASE RENT'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _baseRentController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            hintText: 'Enter base rent',
                            prefixText: 'đ ',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter base rent.';
                            }
                            final num = double.tryParse(val.trim());
                            if (num == null || num <= 0) {
                              return 'Base rent must be greater than 0.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // 5. Status & Owner Read-only Fields
                        if (_isEdit) ...[
                          _buildFieldLabel('Status (Read-only)'),
                          const SizedBox(height: 6),
                          _buildReadOnlyBox(
                            text: apartmentStatus,
                            icon: Icons.lock_outline,
                          ),
                          const SizedBox(height: 14),

                          _buildFieldLabel('Current Owner (Read-only)'),
                          const SizedBox(height: 6),
                          _buildReadOnlyBox(
                            text: ownerDisplayName,
                            icon: Icons.lock_outline,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Apartment status and owner assignment cannot be changed here.',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Physical Info Update Notice Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              border: Border.all(color: AppColors.border, width: 1),
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                                    'Only physical apartment information and rental values will be updated.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          _buildFieldLabel('STATUS'),
                          const SizedBox(height: 6),
                          _buildReadOnlyBox(
                            text: 'EMPTY',
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'New apartments are created as EMPTY by default.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
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
                          child: Text(
                            _isEdit ? 'CANCEL' : 'Cancel',
                            style: const TextStyle(
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
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    String? prefixText,
    String? suffixText,
    bool hasError = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.textTertiary,
      ),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: hasError ? AppColors.error : AppColors.border,
          width: hasError ? 1.5 : 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: hasError ? AppColors.error : AppColors.primary,
          width: 1.5,
        ),
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

  Widget _buildReadOnlyBox({required String text, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Slate 100
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.border,
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (icon != null)
            Icon(
              icon,
              size: 18,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );
  }
}

