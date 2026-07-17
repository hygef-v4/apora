import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/apartment.dart';
import '../providers/apartment_notifier.dart';
import '../providers/tenancy_check_notifier.dart';

/// UC34 (FID-34): Trả phòng (Checkout) & Ẩn danh dữ liệu.
class ApartmentCheckoutScreen extends ConsumerStatefulWidget {
  const ApartmentCheckoutScreen({super.key, required this.apartmentId});

  final int apartmentId;

  @override
  ConsumerState<ApartmentCheckoutScreen> createState() => _ApartmentCheckoutScreenState();
}

class _ApartmentCheckoutScreenState extends ConsumerState<ApartmentCheckoutScreen> {
  bool _isLoading = false;

  Future<void> _submit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận trả phòng?'),
        content: const Text(
          'Hành động này sẽ chấm dứt hợp đồng hiện tại, vô hiệu hóa tài khoản cư dân và ẩn danh hoàn toàn dữ liệu người ở ghép. Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Đồng ý Trả phòng'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(tenancyCheckProvider.notifier).processCheckOut(widget.apartmentId);

      final stateValue = ref.read(tenancyCheckProvider);
      if (stateValue.hasError) {
        throw stateValue.error!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chạy tiến trình Checkout & Ẩn danh thành công.')),
        );
        // Trở về danh sách căn hộ vì phòng này giờ đã trống
        Navigator.of(context).pop(); 
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
    final AsyncValue<ApartmentDetail?> detailAsync = ref.watch(apartmentDetailProvider);
    final submitLabel = _isLoading ? 'Đang thực hiện Checkout...' : 'Xác nhận Trả phòng';

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Trả phòng (Checkout)',
            showBack: true,
          ),
          Expanded(
            child: detailAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(mapDioError(err), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.read(apartmentDetailProvider.notifier).fetch(widget.apartmentId),
                        child: const Text('Tải lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (detail) {
                if (detail == null) {
                  return const Center(child: Text('Không tìm thấy thông tin căn hộ.'));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Physical info card
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.meeting_room, color: AppColors.warning, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Căn hộ ${detail.unitNumber}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Chủ hộ: ${detail.ownerName ?? "Chưa rõ"} · SĐT: ${detail.ownerPhone ?? "Không có"}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Các bước xử lý tự động khi Checkout (BR-65)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Checklist card
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        children: [
                          _checklistItem(
                            Icons.history_toggle_off,
                            'Kết thúc Hợp đồng thuê',
                            'Chuyển trạng thái hợp đồng đang hoạt động thành EXPIRED.',
                          ),
                          const Divider(indent: 52),
                          _checklistItem(
                            Icons.no_accounts_outlined,
                            'Vô hiệu hóa tài khoản Resident',
                            'Chuyển tài khoản cư dân chính thành INACTIVE. Bump token_version để cưỡng chế logout khỏi tất cả thiết bị (BR-07, BR-49).',
                          ),
                          const Divider(indent: 52),
                          _checklistItem(
                            Icons.phonelink_erase,
                            'Thu hồi device tokens',
                            'Hủy toàn bộ FCM Tokens liên kết với tài khoản cư dân này để ngừng gửi thông báo (BR-44).',
                          ),
                          const Divider(indent: 52),
                          _checklistItem(
                            Icons.lock_reset,
                            'Ẩn danh thông tin người ở ghép (BR-20)',
                            'Xóa hoàn toàn ảnh chụp CCCD mặt trước/mặt sau trên Cloudinary. Mã hóa số CCCD thành chuỗi MASK_<id> bảo mật.',
                          ),
                          const Divider(indent: 52),
                          _checklistItem(
                            Icons.vpn_key_outlined,
                            'Bàn giao phòng trống',
                            'Giải phóng liên kết owner khỏi căn hộ và đổi trạng thái căn hộ về EMPTY (BR-47).',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Warning card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cảnh báo Bảo mật & Quyền riêng tư',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Quy trình ẩn danh hóa là quy trình một chiều không thể đảo ngược để bảo vệ thông tin cư dân cũ. Lịch sử hóa đơn, lịch sử sự cố phản ánh vẫn được giữ lại để đối soát tài chính nhưng toàn bộ dữ liệu nhân thân nhạy cảm đã bị loại bỏ.',
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
                    const SizedBox(height: 32),

                    // Checkout trigger button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: const Icon(Icons.logout),
                      label: Text(submitLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Hủy bỏ'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _checklistItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
    );
  }
}
