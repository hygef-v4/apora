import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/apartment.dart';
import '../providers/apartment_notifier.dart';
import '../providers/tenancy_check_notifier.dart';

/// UC34 (FID-34): Checkout Apartment & Data Anonymization.
class ApartmentCheckoutScreen extends ConsumerStatefulWidget {
  const ApartmentCheckoutScreen({super.key, required this.apartmentId});

  final int apartmentId;

  @override
  ConsumerState<ApartmentCheckoutScreen> createState() => _ApartmentCheckoutScreenState();
}

class _ApartmentCheckoutScreenState extends ConsumerState<ApartmentCheckoutScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(apartmentDetailProvider.notifier).fetch(widget.apartmentId);
    });
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(tenancyCheckProvider.notifier).processCheckOut(widget.apartmentId);

      final stateValue = ref.read(tenancyCheckProvider);
      if (stateValue.hasError) {
        throw stateValue.error!;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apartment checkout and data anonymization completed successfully.'),
          ),
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
    final AsyncValue<ApartmentDetail?> detailAsync = ref.watch(apartmentDetailProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(
            title: 'CONFIRM CHECKOUT',
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
                  return const Center(child: Text('Apartment information not found.'));
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
                  children: [
                    // Main Confirm Checkout Card (Matches Wireframe)
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header with Warning Icon Box
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.errorBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.error.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Confirm Checkout',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: AppColors.divider),
                          ),

                          // 2. Warning Description
                          const Text(
                            'This action will lock the current resident account, remove the owner from this apartment, and anonymize sensitive roommate data.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Automated Business Rules Checklist
                          _buildCheckItem('SET APARTMENT STATUS TO EMPTY'),
                          const SizedBox(height: 10),
                          _buildCheckItem('SET OWNER ACCOUNT TO INACTIVE'),
                          const SizedBox(height: 10),
                          _buildCheckItem('DELETE CCCD IMAGES FROM CLOUD STORAGE'),
                          const SizedBox(height: 10),
                          _buildCheckItem('MASK CCCD NUMBERS IN DATABASE'),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, color: AppColors.divider),
                          ),

                          // 4. Action Buttons
                          OutlinedButton(
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
                              'CANCEL',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _isLoading ? 'PROCESSING...' : 'CONFIRM CHECKOUT',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildCheckItem(String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.textTertiary, width: 1.5),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check,
            size: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

