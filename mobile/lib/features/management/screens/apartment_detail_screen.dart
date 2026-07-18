import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/apartment.dart';
import '../providers/apartment_notifier.dart';

/// UC30 (FID-30): Chi tiết căn hộ.
/// Hiển thị thông tin vật lý, chủ hộ, danh sách thành viên ở ghép đã duyệt,
/// hóa đơn gần đây, sự cố gần đây.
/// Phân quyền hiển thị:
/// - Security Guard: Ẩn giá thuê, ẩn hóa đơn, ẩn nút Chỉnh sửa/Check-in/Checkout, che giấu CCCD.
/// - Manager: Thấy đầy đủ, có quyền Check-in/Checkout nhưng không được Chỉnh sửa thông tin căn hộ (BR-60).
/// - Landlord: Toàn quyền (đầy đủ thông tin, có quyền Chỉnh sửa/Check-in/Checkout).
class ApartmentDetailScreen extends ConsumerStatefulWidget {
  const ApartmentDetailScreen({super.key, required this.apartmentId});

  final int apartmentId;

  @override
  ConsumerState<ApartmentDetailScreen> createState() => _ApartmentDetailScreenState();
}

class _ApartmentDetailScreenState extends ConsumerState<ApartmentDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(apartmentDetailProvider.notifier).fetch(widget.apartmentId);
    });
  }

  String _formatCurrency(double value) {
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return format.format(value);
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '??';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }


  String _formatCompactCurrency(double rent) {
    if (rent >= 1000000) {
      final val = rent / 1000000.0;
      return '${val.toStringAsFixed(1).replaceAll('.', ',')}M/th';
    }
    return '${(rent / 1000.0).toStringAsFixed(0)}k/th';
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(apartmentDetailProvider);
    final userRoles = ref.watch(authNotifierProvider).user?.roles ?? const [];
    
    final isLandlord = userRoles.contains('LANDLORD');
    final isManager = userRoles.contains('MANAGER');
    final isSecurity = userRoles.contains('SECURITY_GUARD') && !isLandlord && !isManager;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            title: 'Chi tiết căn hộ',
            showBack: true,
            actions: [
              if (isLandlord && detailAsync.value != null)
                HeaderIconButton(
                  icon: Icons.edit_note,
                  tooltip: 'Chỉnh sửa',
                  onTap: () {
                    final detail = detailAsync.value!;
                    final apt = Apartment(
                      id: detail.id,
                      unitNumber: detail.unitNumber,
                      floor: detail.floor,
                      status: detail.status,
                      areaSize: detail.areaSize,
                      baseRent: detail.baseRent,
                      ownerId: detail.ownerId,
                      ownerName: detail.ownerName,
                      ownerPhone: detail.ownerPhone,
                      unpaidInvoiceCount: 0,
                      unresolvedTicketCount: 0,
                    );
                    context.push('/manager/apartments/${widget.apartmentId}/edit', extra: apt);
                  },
                ),
            ],
          ),
          Expanded(
            child: detailAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(mapDioError(error), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.read(apartmentDetailProvider.notifier).fetch(widget.apartmentId),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (detail) {
                if (detail == null) {
                  return const Center(child: Text('Không tải được thông tin căn hộ.'));
                }

                // Tính toán số lượng sự cố chưa xử lý để gán trạng thái Bảo trì
                final unresolvedCount = detail.recentTickets
                    .where((t) => t.status != 'RESOLVED' && t.status != 'CANCELLED')
                    .length;

                // Xác định badge trạng thái giống với danh sách căn hộ
                late final StatusBadge statusBadge;
                if (unresolvedCount > 0) {
                  statusBadge = StatusBadge.warning('Bảo trì');
                } else if (detail.status == 'OCCUPIED') {
                  statusBadge = StatusBadge.success('Đang thuê');
                } else {
                  statusBadge = StatusBadge(
                    text: 'Trống',
                    color: AppColors.primary,
                    backgroundColor: AppColors.infoBg,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  children: [
                    // 1. Physical info (no card wrapper, matches layout in mockup)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Căn hộ ${detail.unitNumber}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              statusBadge,
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tầng ${detail.floor} · ${detail.areaSize.toStringAsFixed(0)}m²',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. THÔNG TIN CƯ DÂN (tiêu đề đưa vào trong card)
                    if (detail.status == 'OCCUPIED') ...[
                      AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thông tin cư dân',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _getInitials(detail.ownerName ?? ''),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        detail.ownerName ?? 'Chưa cập nhật tên',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        detail.ownerPhone!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                 InkWell(
                                   onTap: () {
                                     // Chat trực tiếp với cư dân
                                     if (detail.ownerId != null) {
                                       context.push(
                                         AppRoutes.chatDetailPath(detail.ownerId!),
                                         extra: detail.ownerName,
                                       );
                                     }
                                   },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.chat_bubble,
                                      color: Color(0xFF2563EB),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 3. THÀNH VIÊN Ở GHÉP (tiêu đề đưa vào trong card)
                      AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thành viên ở ghép',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            if (detail.roommates.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'Chưa đăng ký thành viên ở ghép.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: detail.roommates.length,
                                separatorBuilder: (context, index) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1, color: AppColors.divider),
                                ),
                                itemBuilder: (context, idx) {
                                  final r = detail.roommates[idx];
                                  return Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0EA5E9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _getInitials(r.fullName),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.fullName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'SĐT: ${r.phoneNumber ?? 'Không có'} · CCCD: ${r.cccdNumber}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 4. HỢP ĐỒNG THUÊ & NÚT THU TIỀN THUÊ (Tiêu đề và nút gom chung vào card)
                      AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hợp đồng thuê',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Column(
                                      children: [
                                        Text(
                                          'Bắt đầu',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '01/01/2025',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Column(
                                      children: [
                                        Text(
                                          'Kết thúc',
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '31/12/2025',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Tiền thuê',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatCompactCurrency(detail.baseRent),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Thu tiền thuê / chuyển hướng quản lý hoá đơn
                                context.push(AppRoutes.managerInvoiceList);
                              },
                              icon: const Icon(Icons.credit_card, color: Colors.white, size: 18),
                              label: const Text('Thu tiền thuê'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 5. Recent Bills Section (tiêu đề đưa vào trong card)
                      if (!isSecurity && detail.recentBills != null) ...[
                        AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Hóa đơn gần đây',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 10),
                              if (detail.recentBills!.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      'Không tìm thấy hóa đơn nào.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: detail.recentBills!.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
                                  itemBuilder: (context, idx) {
                                    final bill = detail.recentBills![idx];
                                    final isPaid = bill.status == 'PAID';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Kỳ hóa đơn: ${bill.monthYear}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatCurrency(bill.totalAmount),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          isPaid
                                              ? StatusBadge.success('Đã thanh toán')
                                              : StatusBadge.warning('Chưa trả'),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],

                    // 6. Recent Tickets Section (tiêu đề đưa vào trong card)
                    AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sự cố phản ánh',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          if (detail.recentTickets.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Chưa ghi nhận sự cố nào.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: detail.recentTickets.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
                              itemBuilder: (context, idx) {
                                final ticket = detail.recentTickets[idx];
                                final statusBadge = () {
                                  switch (ticket.status) {
                                    case 'RESOLVED':
                                      return StatusBadge.success('RESOLVED');
                                    case 'CANCELLED':
                                      return StatusBadge.muted('CANCELLED');
                                    case 'PROCESSING':
                                      return StatusBadge.info('PROCESSING');
                                    default:
                                      return StatusBadge.warning(ticket.status);
                                  }
                                }();
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ticket.category,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              ticket.description,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      statusBadge,
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 7. Action Panel (Check-in / Checkout với màu đỏ chữ trắng)
                    if (!isSecurity) ...[
                      if (detail.status == 'EMPTY')
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push('/manager/apartments/${detail.id}/checkin');
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Nhận phòng (Check-in)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        )
                      else if (detail.status == 'OCCUPIED')
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push('/manager/apartments/${detail.id}/checkout');
                          },
                          icon: const Icon(Icons.logout, color: Colors.white, size: 18),
                          label: const Text('Trả phòng (Checkout)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444), // Đỏ 500
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
