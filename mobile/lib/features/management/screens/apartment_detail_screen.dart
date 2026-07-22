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

/// UC30 (FID-30): Apartment Detail Screen.
/// Displays room summary, room members, recent bills, recent tickets,
/// and check-in / check-out action panel.
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

  String _formatMonthYear(String monthYear) {
    final parts = monthYear.split('/');
    if (parts.length == 2) {
      final month = int.tryParse(parts[0]);
      final year = parts[1];
      if (month != null && month >= 1 && month <= 12) {
        const monthNames = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return '${monthNames[month - 1]} $year';
      }
    }
    return monthYear;
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(apartmentDetailProvider);
    final userRoles = ref.watch(authNotifierProvider).user?.roles ?? const [];

    final isLandlord = userRoles.contains('LANDLORD');
    final isManager = userRoles.contains('MANAGER');
    final isSecurity = userRoles.contains('SECURITY_GUARD') && !isLandlord && !isManager;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'APARTMENT DETAIL',
            showBack: true,
            actions: [
              if (isLandlord && detailAsync.value != null)
                HeaderIconButton(
                  icon: Icons.edit_note,
                  tooltip: 'Edit',
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
                        onPressed: () => ref
                            .read(apartmentDetailProvider.notifier)
                            .fetch(widget.apartmentId),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (detail) {
                if (detail == null) {
                  return const Center(child: Text('Unable to load apartment details.'));
                }

                late final StatusBadge statusBadge;
                if (detail.status == 'INACTIVE') {
                  statusBadge = StatusBadge.warning('REPAIR');
                } else if (detail.status == 'OCCUPIED') {
                  statusBadge = const StatusBadge(
                    text: 'OCCUPIED',
                    color: Colors.white,
                    backgroundColor: AppColors.navy,
                  );
                } else {
                  statusBadge = const StatusBadge(
                    text: 'EMPTY',
                    color: AppColors.textSecondary,
                    backgroundColor: AppColors.border,
                  );
                }

                final ownerName = (detail.ownerName != null && detail.ownerName!.trim().isNotEmpty)
                    ? detail.ownerName!.trim()
                    : (detail.status == 'EMPTY' ? 'No owner' : 'Unassigned');

                final phoneText = detail.ownerPhone ?? '—';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                  children: [
                    // 1. Room Summary Card (Matches Top Card in Wireframe)
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Room ${detail.unitNumber}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              statusBadge,
                            ],
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                const TextSpan(text: 'Owner: '),
                                TextSpan(
                                  text: ownerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, color: AppColors.divider),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                phoneText,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Room Members Section
                    Row(
                      children: [
                        const Text(
                          'Room Members',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.group_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (detail.status == 'EMPTY' && detail.roommates.isEmpty)
                      const AppCard(
                        padding: EdgeInsets.all(14),
                        child: Center(
                          child: Text(
                            'No room members registered.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // Primary Owner Member Card
                      if (detail.ownerName != null && detail.ownerName!.trim().isNotEmpty)
                        AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detail.ownerName!.trim(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Primary Owner',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.person_outline,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      if (detail.ownerName != null && detail.ownerName!.trim().isNotEmpty)
                        const SizedBox(height: 8),

                      // Roommates Member Cards
                      ...detail.roommates.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
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
                                        'Roommate · CCCD: ${r.cccdNumber}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.person_outline,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // 3. Recent Bills Section
                    if (!isSecurity && detail.recentBills != null) ...[
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Recent Bills',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (detail.recentBills!.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No recent bills.',
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
                                itemCount: detail.recentBills!.length,
                                separatorBuilder: (context, index) => const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Divider(height: 1, color: AppColors.divider),
                                ),
                                itemBuilder: (context, idx) {
                                  final bill = detail.recentBills![idx];
                                  final isUnpaid = bill.status == 'UNPAID';
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.border, width: 1),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatMonthYear(bill.monthYear),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            isUnpaid
                                                ? const StatusBadge(
                                                    text: 'UNPAID',
                                                    color: AppColors.error,
                                                    backgroundColor: AppColors.errorBg,
                                                  )
                                                : const StatusBadge(
                                                    text: 'PAID',
                                                    color: AppColors.success,
                                                    backgroundColor: AppColors.successBg,
                                                  ),
                                          ],
                                        ),
                                        Text(
                                          _formatCurrency(bill.totalAmount),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isUnpaid
                                                ? AppColors.error
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. Recent Tickets Section
                    AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.confirmation_number_outlined,
                                size: 18,
                                color: AppColors.textPrimary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Recent Tickets',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (detail.recentTickets.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'No recent tickets.',
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
                              itemCount: detail.recentTickets.length,
                              separatorBuilder: (context, index) => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Divider(height: 1, color: AppColors.divider),
                              ),
                              itemBuilder: (context, idx) {
                                final ticket = detail.recentTickets[idx];
                                final badge = () {
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

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border, width: 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              ticket.category,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          badge,
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ticket.description,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 5. Action Panel (Check-in / Checkout Button)
                    if (!isSecurity) ...[
                      if (detail.status == 'EMPTY') ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            context.push('/manager/apartments/${detail.id}/checkin');
                          },
                          icon: const Icon(Icons.login, size: 20),
                          label: const Text(
                            'Check-in',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'Assign new tenant to this room.',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ] else if (detail.status == 'OCCUPIED') ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            context.push('/manager/apartments/${detail.id}/checkout');
                          },
                          icon: const Icon(Icons.logout, size: 20),
                          label: const Text(
                            'Checkout',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error, width: 1.5),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Center(
                          child: Text(
                            'Process finalized upon key return.',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
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


