import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/invoice.dart';
import '../models/payment.dart';

class PaymentReceiptScreen extends StatelessWidget {
  const PaymentReceiptScreen({
    super.key,
    required this.invoice,
    required this.payment,
  });

  final Invoice invoice;
  final Payment payment;

  String _formatMoney(double amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} đ';
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = months[dt.month - 1];
    final dayStr = dt.day.toString().padLeft(2, '0');
    final hourStr = dt.hour.toString().padLeft(2, '0');
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '$monthStr $dayStr, ${dt.year} • $hourStr:$minuteStr';
  }

  @override
  Widget build(BuildContext context) {
    final payDate = payment.paidAt ?? payment.createdAt;
    final formattedDate = _formatDateTime(payDate);
    final refId = payment.transactionCode ?? '#MH-${payment.id.toString().padLeft(5, '0')}-UC24';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const GradientHeader(
            title: 'PAYMENT RECEIPT',
            showBack: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. TOP SUCCESS ICON & HEADER
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF16A34A), width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check_rounded, size: 40, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Payment Successful',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Transaction completed successfully',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // 2. RECEIPT CARD (Paper bill layout)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // TOTAL AMOUNT
                            const Text(
                              'TOTAL AMOUNT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textTertiary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '- ${_formatMoney(payment.amount)}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Dashed Divider
                            Row(
                              children: List.generate(
                                30,
                                (i) => Expanded(
                                  child: Container(
                                    height: 1.5,
                                    color: i % 2 == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // RECEIPT DETAILS
                            _buildReceiptRow('Reference ID', refId, isBoldValue: true, isPrimary: true),
                            _buildReceiptRow('Timestamp', formattedDate),
                            _buildReceiptRow(
                              'Payment Method',
                              payment.paymentMethod.contains('VietQR') || payment.paymentMethod.contains('PayOS')
                                  ? '💳 Direct Bank Transfer'
                                  : payment.paymentMethod,
                            ),
                            _buildReceiptRow(
                              'Apartment',
                              invoice.unitNumber != null ? 'Apartment ${invoice.unitNumber}' : 'Apartment 101',
                            ),
                            _buildReceiptRow('Service Fee', '0 đ'),

                            const SizedBox(height: 16),
                            // Dotted Divider
                            Row(
                              children: List.generate(
                                36,
                                (i) => Expanded(
                                  child: Container(
                                    height: 1.5,
                                    color: i % 2 == 0 ? AppColors.textTertiary.withValues(alpha: 0.4) : Colors.transparent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // BARCODE VERIFICATION BOX
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
                              ),
                              child: Column(
                                children: [
                                  // Barcode bars illustration
                                  SizedBox(
                                    height: 38,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(42, (index) {
                                        final isBlack = index % 2 == 0;
                                        double width = 2;
                                        if (index % 3 == 0) width = 3;
                                        if (index % 5 == 0) width = 1;
                                        if (index % 7 == 0) width = 4;
                                        return Container(
                                          width: width,
                                          height: double.infinity,
                                          color: isBlack ? AppColors.textPrimary : Colors.transparent,
                                        );
                                      }),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'ELECTRONIC RECEIPT - VALID UNTIL NEXT BILLING CYCLE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Zigzag receipt bottom edge design
                      SizedBox(
                        height: 12,
                        child: Row(
                          children: List.generate(24, (index) {
                            return Expanded(
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. ACTION BUTTONS
                // Row 1: Download PDF & Share
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _generateAndSavePDF(context),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opening system share sheet...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Row 2: Back to Home Button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => context.go(AppRoutes.residentHome),
                    icon: const Icon(Icons.home_outlined, size: 20),
                    label: const Text(
                      'Back to Home',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.3),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBoldValue = false, bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBoldValue ? FontWeight.w900 : FontWeight.w700,
              color: isPrimary ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSavePDF(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tạo biên lai PDF...'),
          duration: Duration(milliseconds: 800),
        ),
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'BIEN LAI GIAO DICH',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'Xac nhan thanh toan hoa don',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ),
                  pw.SizedBox(height: 24),
                  pw.Divider(),
                  pw.SizedBox(height: 12),
                  _buildPdfRow('Ma giao dich:', payment.transactionCode ?? '#N/A'),
                  _buildPdfRow('Thoi gian:', payment.paidAt != null ? _formatDateTime(payment.paidAt!) : _formatDateTime(DateTime.now())),
                  _buildPdfRow('Hinh thuc:', payment.paymentMethod),
                  _buildPdfRow('Can ho:', invoice.unitNumber != null ? 'Can ho ${invoice.unitNumber}' : 'Can ho 502'),
                  _buildPdfRow('Phi dich vu cong:', '0 d'),
                  pw.SizedBox(height: 12),
                  pw.Divider(),
                  pw.SizedBox(height: 12),
                  _buildPdfRow('So tien thanh toan:', _formatMoney(payment.amount).replaceAll('đ', 'VND')),
                  pw.SizedBox(height: 32),
                  pw.Center(
                    child: pw.Text(
                      'Cam on quy cu dan da thanh toan!',
                      style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/bien_lai_${payment.transactionCode ?? invoice.id}.pdf");
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tải PDF Thành Công'),
            content: Text('Biên lai PDF đã được tạo và lưu tại:\n\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  OpenFile.open(file.path);
                },
                child: const Text('XEM FILE (LOCATE)'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ĐÓNG'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
