import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/apartment.dart';
import '../providers/apartment_notifier.dart';

/// UC31 / UC32 (FID-31 / FID-32): Thêm mới / Cập nhật thông tin căn hộ (Chỉ Landlord).
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
  bool get _isEdit => widget.apartment != null;

  @override
  void initState() {
    super.initState();
    _floorController = TextEditingController(text: widget.apartment?.floor ?? '');
    _roomNumberController = TextEditingController(text: widget.apartment?.unitNumber ?? '');
    _areaSizeController = TextEditingController(
      text: widget.apartment != null ? widget.apartment!.areaSize.toString() : '',
    );
    _baseRentController = TextEditingController(
      text: widget.apartment != null ? widget.apartment!.baseRent.toString() : '',
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final floor = _floorController.text.trim();
      final roomNumber = _roomNumberController.text.trim();
      final areaSize = double.parse(_areaSizeController.text.trim());
      final baseRent = double.parse(_baseRentController.text.trim());

      if (_isEdit) {
        // UC32: Cập nhật căn hộ
        await ref.read(apartmentDetailProvider.notifier).updateApartment(
              widget.apartment!.id,
              floor: floor,
              roomNumber: roomNumber,
              areaSize: areaSize,
              baseRent: baseRent,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật thông tin căn hộ thành công.')),
          );
          Navigator.of(context).pop();
        }
      } else {
        // UC31: Thêm mới căn hộ
        await ref.read(apartmentDirectoryProvider.notifier).createApartment(
              floor: floor,
              roomNumber: roomNumber,
              areaSize: areaSize,
              baseRent: baseRent,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm căn hộ mới thành công.')),
          );
          Navigator.of(context).pop();
        }
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
    final title = _isEdit ? 'Cập nhật căn hộ' : 'Thêm căn hộ mới';
    final submitLabel = _isLoading
        ? 'Đang xử lý...'
        : (_isEdit ? 'Lưu thay đổi' : 'Thêm căn hộ');

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: title,
            showBack: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Floor field
                  TextFormField(
                    controller: _floorController,
                    decoration: const InputDecoration(
                      labelText: 'Số tầng *',
                      hintText: 'Ví dụ: Tầng 1, Tầng 2, Tầng G...',
                      prefixIcon: Icon(Icons.layers_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập số tầng.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Room Number field
                  TextFormField(
                    controller: _roomNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Số phòng *',
                      hintText: 'Ví dụ: 101, 102, 201...',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập số phòng.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Area Size field
                  TextFormField(
                    controller: _areaSizeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Diện tích (m²) *',
                      hintText: 'Ví dụ: 55.5',
                      prefixIcon: Icon(Icons.aspect_ratio_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập diện tích.';
                      }
                      final num = double.tryParse(val.trim());
                      if (num == null || num <= 0) {
                        return 'Diện tích phải là số dương lớn hơn 0.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Base Rent field
                  TextFormField(
                    controller: _baseRentController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Giá thuê gốc (VNĐ) *',
                      hintText: 'Ví dụ: 5000000',
                      prefixIcon: Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập giá thuê gốc.';
                      }
                      final num = double.tryParse(val.trim());
                      if (num == null || num <= 0) {
                        return 'Giá thuê phải là số dương lớn hơn 0.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  if (_isEdit) ...[
                    // BR-64 status/owner cannot be edited on this screen notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        border: Border.all(color: AppColors.info.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lưu ý về vòng đời (BR-64)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cập nhật thông tin vật lý căn hộ không làm thay đổi trạng thái (${widget.apartment!.status}) và chủ sở hữu hiện tại.',
                                  style: const TextStyle(
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
                  ] else ...[
                    // BR-47 EMPTY status display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.success, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Trạng thái mặc định (BR-47)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Căn hộ mới tạo sẽ được thiết lập trạng thái mặc định là "EMPTY" (Phòng trống) để sẵn sàng cho Check-in.',
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
                  ],

                  // Action buttons
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
