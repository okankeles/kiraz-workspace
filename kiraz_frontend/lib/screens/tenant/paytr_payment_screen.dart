import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PayTrPaymentScreen extends StatefulWidget {
  final String token;
  final String? title;

  const PayTrPaymentScreen({
    super.key,
    required this.token,
    this.title,
  });

  @override
  State<PayTrPaymentScreen> createState() => _PayTrPaymentScreenState();
}

class _PayTrPaymentScreenState extends State<PayTrPaymentScreen> {
  static const Color darkNavy = Color(0xFF161F33);
  static const Color vibrantBlue = Color(0xFF2563EB);
  static const Color ivoryBg = Color(0xFFFBF8F1);

  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    final payTrUrl = 'https://www.paytr.com/odeme/guvenli/${widget.token}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            _checkCallbackUrl(url);
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _checkCallbackUrl(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_checkCallbackUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('PayTR WebView Hatası: [${error.errorCode}] ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(payTrUrl));
  }

  bool _checkCallbackUrl(String url) {
    if (_isFinished) return true;

    final lower = url.toLowerCase();

    // Success URL patterns (matches backend ok-url https://kiraz.app/payment-success or custom query params)
    if (lower.contains('payment-success') ||
        lower.contains('payment_success') ||
        lower.contains('payment/success') ||
        lower.contains('odeme-basarili') ||
        lower.contains('ok_url') ||
        lower.contains('status=success')) {
      _finishPayment(true);
      return true;
    }

    // Fail URL patterns (matches backend fail-url https://kiraz.app/payment-fail or failure redirects)
    if (lower.contains('payment-fail') ||
        lower.contains('payment_fail') ||
        lower.contains('payment/fail') ||
        lower.contains('odeme-basarisiz') ||
        lower.contains('fail_url') ||
        lower.contains('status=failed') ||
        lower.contains('status=fail')) {
      _finishPayment(false);
      return true;
    }

    return false;
  }

  void _finishPayment(bool success) {
    if (_isFinished) return;
    _isFinished = true;
    if (mounted) {
      Navigator.of(context).pop(success);
    }
  }

  Future<bool> _onWillPop() async {
    if (_isFinished) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Ödemeden Çıkılsın mı?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Ödeme sayfasından çıkarsanız işleminiz tamamlanmayacaktır. Ayrılmak istediğinize emin misiniz?',
          style: GoogleFonts.inter(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Ödemeye Devam Et',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: vibrantBlue,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Çık',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      _finishPayment(false);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? darkNavy : ivoryBg,
        appBar: AppBar(
          backgroundColor: isDark ? darkNavy : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Kapat',
            onPressed: () async {
              final shouldLeave = await _onWillPop();
              if (shouldLeave && context.mounted) {
                Navigator.of(context).pop(false);
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title ?? 'PayTR Güvenli Ödeme',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : darkNavy,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 11,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '256-Bit SSL Korumalı Güvenli Ödeme',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(vibrantBlue),
                    minHeight: 3,
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: isDark ? darkNavy : Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(vibrantBlue),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'PayTR Güvenli Ödeme Ekranı Yükleniyor...',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : darkNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lütfen bekleyiniz, banka bağlantısı kuruluyor.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
