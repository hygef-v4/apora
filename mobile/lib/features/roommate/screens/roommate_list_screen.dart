import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth_profile/providers/profile_notifier.dart';
import '../providers/roommate_provider.dart';

class RoommateListScreen extends ConsumerStatefulWidget {
  const RoommateListScreen({super.key});

  @override
  ConsumerState<RoommateListScreen> createState() => _RoommateListScreenState();
}

class _RoommateListScreenState extends ConsumerState<RoommateListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(roommateProvider.notifier).fetchRoommates(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roommateProvider);
    final profile = ref.watch(profileNotifierProvider).value;

    // BR-24: Tính chủ hộ + các thành viên được duyệt vào tổng số cư dân
    final approvedCount = state.roommates
        .where((r) => r.status == 'APPROVED')
        .length;
    final totalOccupants = approvedCount + 1; // 1 Chủ hộ + Approved roommates

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header Bar với Gradient Xanh Xịn xò của App
          GradientHeader(
            title: 'My Roommates',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: 'Làm mới',
                onTap: () =>
                    ref.read(roommateProvider.notifier).fetchRoommates(),
              ),
            ],
          ),

          Expanded(
            child: state.isLoading && state.roommates.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 1. TOP CARD: Total Residents Summary (Matching Mockup)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border,
                            width: 1.0,
                          ),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Residents',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$totalOccupants Roommates',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            // Stacked Avatar circles (👤)(👤)(👤)
                            SizedBox(
                              width: 80,
                              height: 36,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.15),
                                      child: const Icon(
                                        Icons.person,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 20,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFDCFCE7),
                                      child: const Icon(
                                        Icons.person,
                                        size: 18,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 40,
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: const Color(0xFFFEF3C7),
                                      child: const Icon(
                                        Icons.person,
                                        size: 18,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. ROOMMATE ITEMS LIST (Matching Mockup)
                      // Thẻ Chủ Hộ (Primary Owner)
                      if (profile != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.0,
                            ),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      profile.phoneNumber,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Badge [ ✔ Approved / Owner ]
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF16A34A),
                                    width: 1.0,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 13,
                                      color: Color(0xFF16A34A),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Approved',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // List of Roommates
                      ...state.roommates.map((roommate) {
                        final isApproved = roommate.status == 'APPROVED';
                        final isPending = roommate.status == 'PENDING';
                        final badgeColor = isApproved
                            ? const Color(0xFF16A34A)
                            : (isPending
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFEF4444));
                        final badgeBg = isApproved
                            ? const Color(0xFFDCFCE7)
                            : (isPending
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFFEE2E2));
                        final badgeIcon = isApproved
                            ? Icons.check_circle
                            : (isPending
                                  ? Icons.remove_circle_outline
                                  : Icons.cancel);
                        final badgeText = isApproved
                            ? 'Approved'
                            : (isPending ? 'Pending' : 'Rejected');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.0,
                            ),
                            boxShadow: AppColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: badgeBg,
                                    child: Icon(
                                      Icons.person,
                                      color: badgeColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          roommate.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          roommate.phoneNumber ??
                                              'Không có SĐT',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: badgeColor,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          badgeIcon,
                                          size: 13,
                                          color: badgeColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          badgeText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (roommate.status == 'REJECTED') ...[
                                const Divider(
                                  height: 16,
                                  color: AppColors.divider,
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: AppColors.error,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Lý do từ chối: ${roommate.rejectionReason ?? "Yêu cầu bị mờ hoặc thông tin không trùng khớp."}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.error,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),

                      // 3. INVITE NEW ROOMMATE BUTTON (Matching Mockup)
                      Container(
                        width: double.infinity,
                        height: 52,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push(AppRoutes.roommateRegister),
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          label: const Text(
                            'Invite New Roommate',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: AppColors.textPrimary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // 4. HOUSEHOLD DYNAMIC LAYOUT CARD (Matching Mockup Bottom Sketch)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF0F172A),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  'assets/images/apartment-layout.webp',
                                  height: 240,
                                  width: double.infinity,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 180,
                                        color: const Color(0xFFF1F5F9),
                                        child: const Center(
                                          child: Icon(
                                            Icons.house_siding_rounded,
                                            size: 64,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              child: Text(
                                'Sketch: Household Dynamic Layout',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
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
