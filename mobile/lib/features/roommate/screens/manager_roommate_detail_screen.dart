import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
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
  bool _isActioning = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(roommateProvider.notifier).fetchPendingRequests());
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _approve() async {
    setState(() => _isActioning = true);
    try {
      await ref.read(roommateProvider.notifier).updateRequestStatus(
            roommateId: widget.roommateId,
            status: 'APPROVED',
          );
      _showMessage('Đã duyệt yêu cầu tạm trú thành công.');
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _isActioning = true);
    try {
      await ref.read(roommateProvider.notifier).updateRequestStatus(
            roommateId: widget.roommateId,
            status: 'REJECTED',
          );
      _showMessage('Đã từ chối yêu cầu đăng ký tạm trú.');
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isActioning = false);
    }
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Từ chối thành viên',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: const Text('Bạn có chắc chắn muốn từ chối yêu cầu đăng ký tạm trú của thành viên này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _reject();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roommateProvider);
    // Tìm yêu cầu trong danh sách
    final roommate = state.pendingRequests.where((r) => r.id == widget.roommateId).firstOrNull;

    if (roommate == null) {
      return Scaffold(
        body: Column(
          children: [
            const GradientHeader(title: 'Chi Tiết Yêu Cầu', showBack: true),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : const Center(child: Text('Không tìm thấy yêu cầu này hoặc đã được xử lý.')),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          GradientHeader(
            title: 'Đối Soát CCCD',
            subtitle: 'Căn ${roommate.unitNumber ?? "N/A"} - ${roommate.fullName}',
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Thông tin cá nhân
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin đăng ký',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                      const Divider(height: 20, color: AppColors.divider),
                      _buildInfoRow('Họ và tên', roommate.fullName),
                      _buildInfoRow('Số điện thoại', roommate.phoneNumber ?? 'Không có'),
                      _buildInfoRow('Số CCCD / Định danh', roommate.cccdNumber),
                      _buildInfoRow('Căn hộ lưu trú', 'Căn ${roommate.unitNumber ?? "N/A"}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ảnh chụp CCCD
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ảnh chụp Giấy tờ đối chiếu (CCCD)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Mặt trước CCCD:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      _buildImageWidget(roommate.cccdFrontUrl),
                      const SizedBox(height: 16),
                      const Text(
                        'Mặt sau CCCD:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      _buildImageWidget(roommate.cccdBackUrl),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Phím thao tác duyệt
                if (_isActioning)
                  const Center(child: CircularProgressIndicator(color: AppColors.primary))
                else
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _showRejectDialog,
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
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Phê duyệt thành viên'),
                                  content: Text('Bạn có chắc chắn muốn duyệt tạm trú cho thành viên ${roommate.fullName} vào Căn ${roommate.unitNumber}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Hủy'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _approve();
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                                      child: const Text('Xác Nhận'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text('PHÊ DUYỆT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
