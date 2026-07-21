import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/network/dio_client.dart'; // Để dùng mapDioError
import '../providers/roommate_provider.dart';

class RoommateApprovalDetailScreen extends ConsumerStatefulWidget {
  final int roommateId;
  const RoommateApprovalDetailScreen({super.key, required this.roommateId});

  @override
  ConsumerState<RoommateApprovalDetailScreen> createState() => _RoommateApprovalDetailScreenState();
}

class _RoommateApprovalDetailScreenState extends ConsumerState<RoommateApprovalDetailScreen> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isActioning = false;
  int? _selectedRoommateId;

  @override
  void initState() {
    super.initState();
    _selectedRoommateId = widget.roommateId;
    Future.microtask(() => ref.read(roommateProvider.notifier).fetchPendingRequests());
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _approve(int targetId) async {
    setState(() => _isActioning = true);
    try {
      await ref.read(roommateProvider.notifier).updateRequestStatus(
            roommateId: targetId,
            status: 'APPROVED',
          );
      _showMessage('Đã duyệt yêu cầu tạm trú thành công.');
      await ref.read(roommateProvider.notifier).fetchPendingRequests();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _reject(int targetId, String reason) async {
    setState(() => _isActioning = true);
    try {
      await ref.read(roommateProvider.notifier).updateRequestStatus(
            roommateId: targetId,
            status: 'REJECTED',
            reason: reason,
          );
      _showMessage('Đã từ chối yêu cầu đăng ký tạm trú.');
      await ref.read(roommateProvider.notifier).fetchPendingRequests();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _showRejectDialog(int targetId) {
    _reasonController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Lý do từ chối',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Nhập lý do từ chối (ví dụ: Ảnh CCCD bị mờ, Sai số CCCD...)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập lý do từ chối.';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final reason = _reasonController.text.trim();
                  Navigator.pop(context);
                  _reject(targetId, reason);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Từ Chối'),
            ),
          ],
        );
      },
    );
  }

  void _showApproveDialog(dynamic roommate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phê duyệt thành viên'),
        content: Text('Bạn có chắc chắn muốn duyệt tạm trú cho thành viên ${roommate.fullName} vào Căn ${roommate.unitNumber ?? "N/A"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approve(roommate.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Xác Nhận'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roommateProvider);
    final pendingRequests = state.pendingRequests;

    // Tìm đối tượng được chọn
    dynamic selectedRoommate;
    if (pendingRequests.isNotEmpty) {
      selectedRoommate = pendingRequests.firstWhere(
        (r) => r.id == _selectedRoommateId,
        orElse: () => pendingRequests.first,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          GradientHeader(
            title: 'Roommate Approval',
            subtitle: 'Phê duyệt đăng ký tạm trú',
            showBack: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          Expanded(
            child: state.isLoading && pendingRequests.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : pendingRequests.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có yêu cầu tạm trú nào đang chờ duyệt.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 1. TOP SECTION: Pending Requests (N) List with Radio Selectors
                          Row(
                            children: [
                              const Icon(Icons.tune, size: 18, color: AppColors.textPrimary),
                              const SizedBox(width: 8),
                              Text(
                                'Pending Requests (${pendingRequests.length})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          ...pendingRequests.map((roommate) {
                            final isSelected = selectedRoommate != null && roommate.id == selectedRoommate.id;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedRoommateId = roommate.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF0F172A) : AppColors.border,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.08),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            roommate.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Apartment: Căn ${roommate.unitNumber ?? "N/A"}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked,
                                        color: isSelected ? const Color(0xFF0F172A) : AppColors.textTertiary,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),

                          // 2. BOTTOM SECTION: Identity Verification Card
                          if (selectedRoommate != null) ...[
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border, width: 1.0),
                                boxShadow: AppColors.cardShadow,
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Identity Verification
                                  const Row(
                                    children: [
                                      Icon(Icons.verified_user_outlined, color: AppColors.textPrimary, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Identity Verification',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: AppColors.border, thickness: 1),
                                  const SizedBox(height: 16),

                                  // Field 1: Full Legal Name
                                  const Text(
                                    'Full Legal Name',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedRoommate.fullName,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 14),

                                  // Field 2: Phone Number
                                  const Text(
                                    'Phone Number',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedRoommate.phoneNumber ?? 'Không có',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 14),

                                  // Field 3: ID Document Number
                                  const Text(
                                    'ID Document Number',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedRoommate.maskedCccdNumber,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 18),

                                  // Field 4: ID Card Front
                                  const Text(
                                    'ID Card Front',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildImageWidget(selectedRoommate.cccdFrontUrl),
                                  const SizedBox(height: 16),

                                  // Field 5: ID Card Back
                                  const Text(
                                    'ID Card Back',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildImageWidget(selectedRoommate.cccdBackUrl),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Phím thao tác duyệt cho đối tượng được chọn
                            if (_isActioning)
                              const Center(child: CircularProgressIndicator(color: AppColors.primary))
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _showRejectDialog(selectedRoommate.id),
                                        icon: const Icon(Icons.close, color: AppColors.error),
                                        label: const Text('TỪ CHỐI', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppColors.error, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showApproveDialog(selectedRoommate),
                                        icon: const Icon(Icons.check, color: Colors.white),
                                        label: const Text('PHÊ DUYỆT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 3,
                                          shadowColor: AppColors.primary.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String? url) {
    if (url == null || url.trim().isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('Không có ảnh chụp hoặc ảnh bị lỗi.', style: TextStyle(color: AppColors.textTertiary)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 180,
            color: Colors.grey.shade200,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 180,
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.broken_image, color: AppColors.textTertiary, size: 36),
            ),
          );
        },
      ),
    );
  }
}
