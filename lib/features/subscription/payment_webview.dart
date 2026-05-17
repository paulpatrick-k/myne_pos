import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.amount,
    required this.email,
    required this.reference,
    required this.publicKey,
    required this.successUrl,
    required this.failureUrl,
  });

  final int amount;
  final String email;
  final String reference;
  final String publicKey;
  final String successUrl;
  final String failureUrl;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(_buildPaymentUri());
  }

  Uri _buildPaymentUri() {
    return Uri.https(
      'checkout.paystack.com',
      '/',
      {
        'amount': widget.amount.toString(),
        'email': widget.email,
        'reference': widget.reference,
        'public_key': widget.publicKey,
        'redirect_url': widget.successUrl,
        'callback_url': widget.successUrl,
        'on_success': widget.successUrl,
        'on_failure': widget.failureUrl,
      },
    );
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final url = request.url;

    if (url.startsWith(widget.successUrl)) {
      Navigator.of(context).pop(true);
      return NavigationDecision.prevent;
    }

    if (url.startsWith(widget.failureUrl)) {
      Navigator.of(context).pop(false);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paystack Checkout'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
