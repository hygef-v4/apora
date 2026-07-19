import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/billing_provider.dart';

class PaymentWebView extends ConsumerStatefulWidget {
  const PaymentWebView({
    super.key,
    required this.invoiceId,
    required this.paymentUrl,
    required this.totalAmount,
  });

  final int invoiceId;
  final String paymentUrl;
  final double totalAmount;

  @override
  ConsumerState<PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends ConsumerState<PaymentWebView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late final WebViewController _webViewController;
  bool _isProcessing = false;
  bool _isRealPayment = false;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Kiểm tra xem là link thanh toán thật (không phải giả lập mock)
    _isRealPayment = !widget.paymentUrl.contains('MOCK_ORDER');

    if (_isRealPayment) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() => _loadingProgress = progress);
              }
            },
            onPageStarted: (String url) {
              _checkRedirect(url);
            },
            onUrlChange: (UrlChange change) {
              if (change.url != null) {
                _checkRedirect(change.url!);
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              final uri = Uri.tryParse(request.url);
              if (uri != null) {
                final path = uri.path;
                final isSuccessPath = path.contains('/api/payments/payos/success');
                final isCancelPath = path.contains('/api/payments/payos/cancel');
                final isPayOsSuccess = uri.queryParameters['code'] == '00' && uri.queryParameters['cancel'] == 'false';
                final isPayOsCancel = uri.queryParameters['cancel'] == 'true';

                if (isSuccessPath || isPayOsSuccess || isCancelPath || isPayOsCancel) {
                  _checkRedirect(request.url);
                  return NavigationDecision.prevent;
                }
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.paymentUrl));
    }
  }

  void _checkRedirect(String url) {
    debugPrint('[WebView] URL thay đổi: $url');
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final path = uri.path;
    final isSuccessPath = path.contains('/api/payments/payos/success');
    final isCancelPath = path.contains('/api/payments/payos/cancel');
    final isPayOsSuccess = uri.queryParameters['code'] == '00' && uri.queryParameters['cancel'] == 'false';
    final isPayOsCancel = uri.queryParameters['cancel'] == 'true';

    if (isSuccessPath || isPayOsSuccess) {
      _handleSuccessRedirect();
    } else if (isCancelPath || isPayOsCancel) {
      if (mounted && !_isProcessing) {
        context.pop();
      }
    }
  }

  Future<void> _handleSuccessRedirect() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      dynamic invoice;
      dynamic payment;

      // 1. Poll trạng thái hóa đơn, chờ webhook PayOS server-to-server đánh dấu
      // PAID (BR-32: webhook là nguồn chân lý duy nhất).
      for (int attempt = 0; attempt < 3; attempt++) {
        await ref.read(billingProvider.notifier).fetchData();
        final billingState = ref.read(billingProvider);
        for (final inv in billingState.invoices) {
          if (inv.id == widget.invoiceId && inv.status == 'PAID') {
            invoice = inv;
            break;
          }
        }

        if (invoice != null) break;
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // 2. CHỈ môi trường DEV: chưa có PayOS/webhook thật -> giả lập thành công
      // để test end-to-end. TUYỆT ĐỐI KHÔNG giả lập trên release build (backend
      // cũng chặn 403 - BR-33), tránh hiển thị biên lai giả khi backend UNPAID.
      if (invoice == null && kDebugMode) {
        try {
          payment = await ref.read(billingProvider.notifier).simulateSuccessPayment(widget.invoiceId);
          final billingState = ref.read(billingProvider);
          for (final inv in billingState.invoices) {
            if (inv.id == widget.invoiceId && inv.status == 'PAID') {
              invoice = inv;
              break;
            }
          }
        } catch (e) {
          debugPrint('[WebView] Fallback simulate (dev) lỗi: $e');
        }
      }

      if (!mounted) return;

      if (_isRealPayment) {
        try {
          _webViewController.loadRequest(Uri.parse('about:blank'));
        } catch (_) {}
      }
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;

      if (invoice != null) {
        // Điều hướng tới màn biên lai
        context.pushReplacement(
          '/invoices/receipt',
          extra: {
            'invoice': invoice,
            'payment': payment,
          },
        );
      } else {
        // Webhook về chậm: KHÔNG bịa trạng thái PAID trên UI. Báo rõ và quay lại
        // danh sách hóa đơn - hóa đơn sẽ tự cập nhật khi webhook tới.
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text(
              'Đã ghi nhận giao dịch. Hệ thống đang chờ ngân hàng xác nhận, '
              'hóa đơn sẽ tự cập nhật trong giây lát. Vui lòng kiểm tra lại sau.',
            ),
            duration: Duration(seconds: 5),
          ));
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isRealPayment) {
      try {
        _webViewController.loadRequest(Uri.parse('about:blank'));
      } catch (_) {}
    }
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    // 1. GIAO DIỆN WEBVIEW THẬT (Khi kết nối cổng thanh toán trực tuyến thật)
    if (_isRealPayment) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          title: const Text(
            'Thanh toán hóa đơn',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          bottom: _loadingProgress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    backgroundColor: Colors.white24,
                    color: AppColors.primary,
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _webViewController),
            if (_isProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: AppCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 16),
                          const Text(
                            'Đang nhận tín hiệu từ PayOS...',
                            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hệ thống đang xác thực giao dịch an toàn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // 2. GIAO DIỆN GIẢ LẬP (MOCK SANDBOX - Khi test offline)
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Column(
            children: [
              GradientHeader(
                title: 'Cổng Thanh Toán',
                subtitle: 'Giao dịch qua VietQR / PayOS',
                showBack: true,
                actions: [
                  HeaderIconButton(
                    icon: Icons.close,
                    tooltip: 'Hủy giao dịch',
                    onTap: () => context.pop(),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Mock PayOS Header Logo
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.payment, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'payOS',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Đơn hàng hết hạn sau 15:00',
                            style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cột hiển thị Mã QR
                    AppCard(
                      child: Column(
                        children: [
                          const Text(
                            'Quét mã VietQR để thanh toán',
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 16),
                          // Vẽ Mock QR Code
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border, width: 2),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Mock QR Code Patterns
                                SizedBox(
                                  width: 180,
                                  height: 180,
                                  child: GridView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 6,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: 36,
                                    itemBuilder: (context, idx) {
                                      final isCorner = idx == 0 || idx == 5 || idx == 30 || idx == 35;
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: isCorner ? AppColors.navy : (idx % 3 == 0 ? Colors.black87 : Colors.white),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Center logo
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.qr_code_scanner, size: 24, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã tải và lưu ảnh VietQR thành công vào thư viện của thiết bị!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Lưu ảnh QR về máy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Opacity(
                                opacity: 0.3 + (_pulseController.value * 0.7),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Đang chờ giao dịch từ ngân hàng...',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppColors.divider),
                          const SizedBox(height: 12),
                          const Text(
                            '⚠️ Đây là màn hình giả lập UI. Để quét mã VietQR thật từ PayOS:',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final uri = Uri.parse(widget.paymentUrl);
                                try {
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Không thể mở link: $e')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.open_in_browser, size: 18),
                              label: const Text(
                                'MỞ CỔNG THANH TOÁN VietQR THẬT',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Thông tin chuyển khoản chi tiết
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin chuyển khoản',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          const Divider(height: 20, color: AppColors.divider),
                          _buildInfoRow('Ngân hàng', 'MB Bank (Quân Đội)'),
                          _buildInfoRow('Số tài khoản', '113115118'),
                          _buildInfoRow('Tên tài khoản', 'CONG TY APORA VIET NAM'),
                          _buildInfoRow('Số tiền chuyển', _formatMoney(widget.totalAmount), isBold: true, isError: true),
                          _buildInfoRow('Nội dung chuyển', 'APORA BILL ${widget.invoiceId}', isCopy: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Khung giả lập thanh toán
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.successBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.terminal, color: AppColors.success, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Bảng giả lập hệ thống (Sandbox)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: OutlinedButton(
                                    onPressed: _isProcessing ? null : () => context.pop(),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.error),
                                      foregroundColor: AppColors.error,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Hủy thanh toán', style: TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _isProcessing ? null : _simulateSuccess,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Thanh Toán Thành Công', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AppCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        const Text(
                          'Đang nhận Webhook từ PayOS...',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hệ thống đang xác thực chữ ký HMAC-SHA256 bảo mật.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, bool isError = false, bool isCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                  color: isError ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              if (isCopy) ...[
                const SizedBox(width: 4),
                const Icon(Icons.copy, size: 14, color: AppColors.primary),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _simulateSuccess() async {
    setState(() => _isProcessing = true);

    try {
      // Gọi service cập nhật trạng thái hóa đơn & sinh log payment
      final payment = await ref.read(billingProvider.notifier).simulateSuccessPayment(widget.invoiceId);
      final billingState = ref.read(billingProvider);
      final invoice = billingState.invoices.firstWhere((inv) => inv.id == widget.invoiceId);

      if (mounted) {
        // Redirect tới màn hình biên lai thành công (UC17)
        context.pushReplacement(
          '/invoices/receipt',
          extra: {
            'invoice': invoice,
            'payment': payment,
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
