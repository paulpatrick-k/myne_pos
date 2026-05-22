import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // Fixed subscription amount in KES (1050 ≈ $7.99)
  static const int _amountInKes = 1050;

  Future<void> _startPayment() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pbService = PocketBaseService();

    // Generate a unique reference
    final reference = pbService.generateTransactionReference();

    // Load Paystack public key from .env
    final publicKey = dotenv.env['PAYSTACK_PUBLIC_KEY'];
    if (publicKey == null || publicKey.isEmpty) {
      setState(() => _error = 'Paystack public key missing. Check .env');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    // Define dummy success/failure URLs – the webview uses them to detect completion
    const successUrl = 'https://myne.app/paystack/success';
    const failureUrl = 'https://myne.app/paystack/failure';

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentWebViewScreen(
          amount: _amountInKes,
          email: auth.userEmail ?? '',
          reference: reference,
          publicKey: publicKey,
          successUrl: successUrl,
          failureUrl: failureUrl,
        ),
      ),
    );

    if (!mounted) return;

    setState(() => _isProcessing = false);

    if (result == true) {
      // Payment succeeded – activate subscription
      try {
        await pbService.activateSubscription(auth.businessId!, reference);
        // Refresh auth provider to update cached license expiry
        await auth.refreshLicenseFromServer();
        if (mounted) {
          // Navigate back to home (license now active)
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        setState(() => _error = 'Subscription activation failed: $e');
      }
    } else {
      setState(() => _error = 'Payment cancelled or failed. Please try again.');
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
                'Monthly subscription: ${auth.formatPrice(_amountInKes.toDouble())}',
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
