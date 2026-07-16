import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
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
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Biên lai giao dịch',
            subtitle: 'Xác nhận thanh toán hóa đơn',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Icon trạng thái và tiêu đề thành công
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: AppColors.successBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle, size: 48, color: AppColors.success),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Thanh Toán Thành Công',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hóa đơn Tháng ${invoice.monthYear}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatMoney(invoice.totalAmount),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Card thông tin chi tiết biên lai
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Thông tin hóa đơn',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const Divider(height: 20, color: AppColors.divider),
                      _buildReceiptRow('Mã giao dịch', payment.transactionCode ?? '#N/A'),
                      _buildReceiptRow('Thời gian', payment.paidAt != null ? _formatDateTime(payment.paidAt!) : _formatDateTime(DateTime.now())),
                      _buildReceiptRow('Hình thức', payment.paymentMethod),
                      _buildReceiptRow('Căn hộ', invoice.unitNumber != null ? 'Căn hộ ${invoice.unitNumber}' : 'Căn hộ 502 (Tầng 5)'),
                      _buildReceiptRow('Phí dịch vụ cổng', '0 đ'),
                      const Divider(height: 20, color: AppColors.divider),
                      _buildReceiptRow('Số tiền thanh toán', _formatMoney(payment.amount), isBoldValue: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card vẽ mã vạch (Barcode) giả lập cực kì premium
                AppCard(
                  child: Column(
                    children: [
                      const Text(
                        'MÃ VẠCH XÁC THỰC GIAO DỊCH',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary, letterSpacing: 1),
                      ),
                      const SizedBox(height: 12),
                      // Vẽ barcode bằng Container
                      SizedBox(
                        height: 50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(35, (index) {
                            // Tạo các vạch đen trắng độ rộng ngẫu nhiên nhưng cố định
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
                      Text(
                        payment.payosOrderId,
                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons: Tải PDF, Chia sẻ
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => _generateAndSavePDF(context),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Tải PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                            // Giả lập share
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đang mở bảng chia sẻ hệ thống...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Chia sẻ', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            foregroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Về trang chủ button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoutes.residentHome),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'QUAY VỀ TRANG CHỦ',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBoldValue ? FontWeight.w900 : FontWeight.w700,
              color: isBoldValue ? AppColors.primary : AppColors.textPrimary,
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
