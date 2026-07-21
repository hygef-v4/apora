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
        ..loadRequest(
          Uri.parse(widget.paymentUrl),
          headers: const {'Accept-Language': 'en-US,en;q=0.9'},
        );
    }
  }

  void _checkRedirect(String url) {
    debugPrint('[WebView] URL changed: $url');
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
          debugPrint('[WebView] Fallback simulate error: $e');
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
        context.pushReplacement(
          '/invoices/receipt',
          extra: {
            'invoice': invoice,
            'payment': payment,
          },
        );
      } else {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text(
              'Transaction recorded. Waiting for bank verification.',
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
    return '${buffer.toString()}đ';
  }

  @override
  Widget build(BuildContext context) {
    // 1. GIAO DIỆN WEBVIEW THẬT (PayOS Checkout)
    if (_isRealPayment) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          elevation: 0,
          title: const Text(
            'PayOS Checkout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ],
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
                            'Processing PayOS Payment...',
                            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Verifying secure transaction with bank.',
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

    // 2. GIAO DIỆN MOCK SANDBOX (Thanh toán giả lập khi test)
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Column(
            children: [
              GradientHeader(
                title: 'PayOS Checkout',
                subtitle: 'Scan QR Code or Transfer exactly',
                showBack: true,
                actions: [
                  HeaderIconButton(
                    icon: Icons.close,
                    tooltip: 'Cancel',
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
                            'Order expires in 15:00',
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
                            'Scan QR Code or Transfer exactly',
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
                                  content: Text('VietQR image saved successfully to device gallery!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Save QR Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                      'Waiting for bank transaction...',
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
                            '⚠️ Test Mode UI. To open official PayOS checkout:',
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
                                    SnackBar(content: Text('Cannot open link: $e')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.open_in_browser, size: 18),
                              label: const Text(
                                'OPEN REAL PayOS CHECKOUT',
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

                    // Transfer Information Details
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Transfer Details',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          const Divider(height: 20, color: AppColors.divider),
                          _buildInfoRow('Bank', 'MB Bank'),
                          _buildInfoRow('Account Name', 'KHUAT QUANG HUNG'),
                          _buildInfoRow('Account Number', '606911911', isCopy: true),
                          _buildInfoRow('Amount', _formatMoney(widget.totalAmount), isBold: true, isError: true, isCopy: true),
                          _buildInfoRow('Message', 'CSIJ23TT6B3 APORA BILL ${widget.invoiceId}', isCopy: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // CANCEL Button matching mockup
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : () => context.pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: _isProcessing ? null : _simulateSuccess,
                          icon: const Icon(Icons.bug_report, size: 16, color: AppColors.textTertiary),
                          label: const Text(
                            'Simulate Payment Success (Dev Test)',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ],
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
