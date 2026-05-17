import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pocketbase/pocketbase.dart'; // for RecordModel
import '../../core/services/pocketbase_service.dart';
import '../../core/services/receipt_printer.dart';
import '../../shared/providers/auth_provider.dart';
import 'cart_provider.dart';

Future<Uint8List> consolidateHttpClientResponseBytes(HttpClientResponse response) async {
  final bytes = <int>[];
  await for (final chunk in response) {
    bytes.addAll(chunk);
  }
  return Uint8List.fromList(bytes);
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'Cash';
  final TextEditingController _referenceController = TextEditingController();
  bool _isProcessing = false;

  final List<String> _paymentMethods = ['Cash', 'M-Pesa', 'Card', 'Airtel Money'];

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _completeSale() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final pbService = PocketBaseService();

    print('Checkout auth state: businessId=${auth.businessId} userId=${auth.userId} role=${auth.role} userEmail=${auth.userEmail}');

    // Strong safety check
    if (auth.businessId == null || auth.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to complete sale')),
      );
      return;
    }

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty')),
      );
      return;
    }

    // License check
    if (auth.isLicenseExpired()) {
      if (mounted) Navigator.pushReplacementNamed(context, '/paywall');
      return;
    }

    // Expiry validation for pharmacy
    final cartItems = cart.items;
    final isPharmacy = auth.businessCategory?.toLowerCase() == 'pharmacy';
    if (isPharmacy) {
      final now = DateTime.now();
      final expiredItems = cartItems.where((item) {
        if (item.expiryDate == null) return false;
        return item.expiryDate!.isBefore(DateTime(now.year, now.month, now.day));
      }).toList();

      if (expiredItems.isNotEmpty) {
        final names = expiredItems.map((e) => e.name).join(', ');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot sell expired item(s): $names')),
          );
        }
        setState(() => _isProcessing = false);
        return;  // abort sale
      }
    }

    setState(() => _isProcessing = true);

    try {
      final itemsForSale = cart.items.map((item) {
        return {
          'item_id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
        };
      }).toList();

      print('🛒 Checkout items: ${itemsForSale.map((item) => '${item['name']}(${item['item_id']}) x${item['quantity']}').join(', ')}');

      final total = cart.totalPrice;
      final receiptNo = pbService.generateReceiptNo();

      final isOnline = await pbService.isOnline();

      if (isOnline) {
        await pbService.createSale(
          businessId: auth.businessId!,
          userId: auth.userId!,
          userEmail: auth.userEmail ?? '',
          items: itemsForSale,
          totalAmount: total,
          paymentMethod: _paymentMethod,
          paymentReference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          receiptNo: receiptNo,
        );

        cart.clearCart();

        if (mounted) {
          _showSuccessDialog(receiptNo);
        }
      } else {
        await pbService.queueSale(
          businessId: auth.businessId!,
          userId: auth.userId!,
          userEmail: auth.userEmail ?? '',
          items: itemsForSale,
          totalAmount: total,
          paymentMethod: _paymentMethod,
          paymentReference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          receiptNo: receiptNo,
        );
        cart.clearCart();
        if (mounted) _showOfflineConfirmation(receiptNo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog(String receiptNo) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final pbService = PocketBaseService();
    await pbService.ensureAdminAuth();

    // Fetch the sale record to get KRA invoice ID (if any)
    RecordModel? saleRecord;
    String? kraInvoiceId;
    try {
      saleRecord = await pbService.adminPb.collection('sales').getFirstListItem(
        'receipt_no = "$receiptNo"',
      );
      kraInvoiceId = saleRecord?.getStringValue('kra_invoice_id');
    } catch (e) {
      print('Could not fetch sale record for KRA ID: $e');
    }

    final saleItems = cart.items.map((item) => {
      'name': item.name,
      'quantity': item.quantity,
      'price': item.price,
    }).toList();

    final receiptText = ReceiptPrinter.generateReceiptText(
      businessName: auth.businessName ?? 'MYNE POS',
      businessAddress: auth.businessAddress ?? '',
      businessPhone: auth.businessPhone ?? '',
      businessEmail: auth.businessEmail ?? '',
      receiptNo: receiptNo,
      date: DateTime.now(),
      items: saleItems,
      total: cart.totalPrice,
      paymentMethod: _paymentMethod,
      paymentReference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
      thankYou: 'Thank you for your purchase!',
      kraInvoiceId: kraInvoiceId,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sale Complete'),
        content: Text('Receipt No: $receiptNo\n\nWhat would you like to do?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _printReceipt(receiptNo, saleItems, kraInvoiceId);
            },
            child: const Text('Print Receipt'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showShareOptions(receiptText, receiptNo);
            },
            child: const Text('Share Receipt'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showOfflineConfirmation(String receiptNo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sale Saved Offline'),
        content: Text(
            'Receipt No: $receiptNo\n\nThis sale will be synced automatically when internet is restored.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReceipt(
    String receiptNo, 
    List<Map<String, dynamic>> items, 
    String? kraInvoiceId,
  ) async {
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final receiptText = ReceiptPrinter.generateReceiptText(
        businessName: auth.businessName ?? 'MYNE POS',
        businessAddress: auth.businessAddress ?? '',
        businessPhone: auth.businessPhone ?? '',
        businessEmail: auth.businessEmail ?? '',
        receiptNo: receiptNo,
        date: DateTime.now(),
        items: items,
        total: cart.totalPrice,
        paymentMethod: _paymentMethod,
        paymentReference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        kraInvoiceId: kraInvoiceId,
        thankYou: 'Thank you for shopping with us!',
      );

      // Simple & reliable - share as text
      await Share.share(receiptText, subject: 'Receipt #$receiptNo - MYNE POS');

      // Log it
      await PocketBaseService().logAuditAction(
        userId: auth.userId!,
        userEmail: auth.userEmail ?? '',
        action: 'receipt_shared',
        details: {'receipt_no': receiptNo},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt shared - you can now print it')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share receipt: $e')),
        );
      }
    }
  }

  void _showShareOptions(String receiptText, String receiptNo) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('WhatsApp'),
              onTap: () => _sendWhatsApp(receiptText),
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              onTap: () => _sendEmail(receiptText, receiptNo),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Other ...'),
              onTap: () => Share.share(receiptText, subject: 'Receipt $receiptNo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsApp(String receiptText) async {
    final phoneController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('WhatsApp Receipt'),
        content: TextField(
          controller: phoneController,
          decoration: const InputDecoration(
            labelText: 'Customer phone number (e.g., 2547XXXXXXX)',
            helperText: 'Include country code without leading +',
          ),
          keyboardType: TextInputType.phone,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed == true && phoneController.text.trim().isNotEmpty) {
      String phone = phoneController.text.trim();
      if (phone.startsWith('0')) phone = '254${phone.substring(1)}';
      if (!phone.startsWith('254')) phone = '254$phone';
      final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(receiptText)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open WhatsApp')));
      }
    }
  }

  Future<void> _sendEmail(String receiptText, String receiptNo) async {
    final emailController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email Receipt'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Customer email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed == true && emailController.text.trim().isNotEmpty) {
      final subject = 'Receipt $receiptNo';
      final body = receiptText;
      final url = Uri.parse('mailto:${emailController.text.trim()}?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open email client')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: cart.items.length,
                itemBuilder: (ctx, i) {
                  final item = cart.items[i];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Text('${item.quantity} x ${auth.formatPrice(item.price)}'),
                    trailing: Text(auth.formatPrice(item.subtotal)),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Total'),
              trailing: Text(auth.formatPrice(cart.totalPrice),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              items: _paymentMethods.map((method) {
                return DropdownMenuItem(value: method, child: Text(method));
              }).toList(),
              onChanged: (value) => setState(() => _paymentMethod = value!),
              decoration: const InputDecoration(labelText: 'Payment Method'),
            ),
            const SizedBox(height: 16),
            if (_paymentMethod != 'Cash')
              TextFormField(
                controller: _referenceController,
                decoration: InputDecoration(
                    labelText: '${_paymentMethod} Reference (e.g., Transaction ID)'),
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isProcessing ? null : _completeSale,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text('Complete Sale'),
            ),
          ],
        ),
      ),
    );
  }
}