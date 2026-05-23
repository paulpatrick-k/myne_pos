import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../../core/services/pocketbase_service.dart';
import 'payment_webview.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isProcessing = false;
  String? _error;

  Future<void> _startPayment() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pbService = PocketBaseService();

    // Generate a unique transaction reference
    final reference = pbService.generateTransactionReference();

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Step 1: Initialize payment via proxy
      final httpClient = http.Client();
      final initResponse = await httpClient.post(
        Uri.parse('http://192.168.1.66:3000/init-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': 105000,
          'email': auth.userEmail,
          'businessId': auth.businessId,
          'reference': reference,
        }),
      );

      final initData = jsonDecode(initResponse.body);
      final authUrl = initData['authorization_url'];
      if (authUrl == null) throw Exception('No authorization URL');

      // Step 2: Open WebView
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebViewScreen(authorizationUrl: authUrl),
        ),
      );

      if (result == true) {
        // Step 3: Confirm payment and activate subscription
        setState(() => _isProcessing = true);
        final confirmResponse = await httpClient.post(
          Uri.parse('http://192.168.1.66:3000/confirm-payment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'reference': reference,
            'businessId': auth.businessId,
          }),
        );

        if (confirmResponse.statusCode == 200) {
          // Refresh license from server
          await auth.refreshLicenseFromServer();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          final errorBody = jsonDecode(confirmResponse.body);
          setState(() => _error = 'Activation failed: ${errorBody['error']}');
        }
      } else {
        setState(() => _error = 'Payment was not completed. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock, size: 80, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                'Your free trial has expired',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'To continue using MYNE POS, please subscribe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Monthly subscription: ${auth.formatPrice(1050.0)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              ElevatedButton(
                onPressed: _isProcessing ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator()
                    : const Text('Subscribe Now'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  await auth.logout();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
