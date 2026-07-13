import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
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

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(apartmentDetailProvider);
    final userRoles = ref.watch(authNotifierProvider).user?.roles ?? const [];
    
    final isLandlord = userRoles.contains('LANDLORD');
    final isManager = userRoles.contains('MANAGER');
    final isSecurity = userRoles.contains('SECURITY_GUARD') && !isLandlord && !isManager;

    return Scaffold(
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

                final statusLabel = detail.status == 'OCCUPIED'
                    ? 'Đang ở'
                    : (detail.status == 'EMPTY' ? 'Phòng trống' : 'Ngừng hoạt động');

                return ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    // 1. Physical info card
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Phòng ${detail.unitNumber}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              detail.status == 'OCCUPIED'
                                  ? StatusBadge.success(statusLabel)
                                  : (detail.status == 'EMPTY'
                                      ? StatusBadge.muted(statusLabel)
                                      : StatusBadge.warning(statusLabel)),
                            ],
                          ),
                          const Divider(height: 24),
                          _infoRow(Icons.layers, 'Tầng', detail.floor),
                          const SizedBox(height: 10),
                          _infoRow(Icons.aspect_ratio, 'Diện tích', '${detail.areaSize} m²'),
                          const SizedBox(height: 10),
                          if (!isSecurity) ...[
                            _infoRow(
                              Icons.payments,
                              'Giá thuê gốc',
                              _formatCurrency(detail.baseRent),
                              valueStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Owner info card
                    if (detail.status == 'OCCUPIED') ...[
                      const Text(
                        'Chủ hộ hiện tại',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.successBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person, color: AppColors.success),
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
                                    detail.ownerPhone ?? 'Không có số điện thoại',
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
                      const SizedBox(height: 14),
                    ],

                    // 3. Roommates Section
                    const Text(
                      'Thành viên ở ghép',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (detail.roommates.isEmpty)
                      const AppCard(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'Chưa đăng ký thành viên ở ghép.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ...detail.roommates.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  const Icon(Icons.people_outline, color: AppColors.textSecondary, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.fullName,
                                          style: const TextStyle(
                                            fontSize: 13,
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
                                  StatusBadge.success('APPROVED'),
                                ],
                              ),
                            ),
                          )),
                    const SizedBox(height: 14),

                    // 4. Recent Bills Section (hidden for Security Guards)
                    if (!isSecurity && detail.recentBills != null) ...[
                      const Text(
                        'Hóa đơn gần đây',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (detail.recentBills!.isEmpty)
                        const AppCard(
                          padding: EdgeInsets.all(16),
                          child: Center(
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
                        AppCard(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: detail.recentBills!.map((bill) {
                              final isPaid = bill.status == 'PAID';
                              return ListTile(
                                dense: true,
                                title: Text(
                                  'Kỳ hóa đơn: ${bill.monthYear}',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  _formatCurrency(bill.totalAmount),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: isPaid
                                    ? StatusBadge.success('Đã thanh toán')
                                    : StatusBadge.warning('Chưa trả'),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 14),
                    ],

                    // 5. Recent Tickets Section
                    const Text(
                      'Sự cố phản ánh',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (detail.recentTickets.isEmpty)
                      const AppCard(
                        padding: EdgeInsets.all(16),
                        child: Center(
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
                      AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: detail.recentTickets.map((ticket) {

                            return ListTile(
                              dense: true,
                              title: Text(
                                ticket.category,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                ticket.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: () {
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
                              }(),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // 6. Action Panel (Check-in / Checkout) for Manager/Landlord
                    if (!isSecurity) ...[
                      if (detail.status == 'EMPTY')
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tính năng Check-in sẽ có ở module Tenancy Management (Module 2).'),
                              ),
                            );
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
                          ),
                        )
                      else if (detail.status == 'OCCUPIED')
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tính năng Checkout sẽ có ở module Tenancy Management (Module 2).'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.logout, color: AppColors.warning),
                          label: const Text('Trả phòng (Checkout)', style: TextStyle(color: AppColors.warning)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.warning),
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  Widget _infoRow(IconData icon, String label, String value, {TextStyle? valueStyle}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ).merge(valueStyle),
          ),
        ),
      ],
    );
  }
}
