import 'dart:typed_data';
import 'package:intl/intl.dart';

class ReceiptPrinter {
  static Future<Uint8List> generateReceiptBytes({
    required String businessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
    Uint8List? logoBytes,
    required String receiptNo,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double total,
    double tax = 0,
    required String paymentMethod,
    String? paymentReference,
    String? kraInvoiceId,
    required String thankYou,
  }) async {
    final text = generateReceiptText(
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
      receiptNo: receiptNo,
      date: date,
      items: items,
      total: total,
      paymentMethod: paymentMethod,
      paymentReference: paymentReference,
      kraInvoiceId: kraInvoiceId,
      thankYou: thankYou,
    );
    return Uint8List.fromList(text.codeUnits);
  }

  /// Generate plain text receipt (for WhatsApp/Email)
  static String generateReceiptText({
    required String businessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
    required String receiptNo,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    required double total,
    required String paymentMethod,
    String? paymentReference,
    String? kraInvoiceId,
    required String thankYou,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(businessName.toUpperCase());
    if (businessAddress.isNotEmpty) buffer.writeln(businessAddress);
    if (businessPhone.isNotEmpty) buffer.writeln('Tel: $businessPhone');
    if (businessEmail.isNotEmpty) buffer.writeln('Email: $businessEmail');
    buffer.writeln('=' * 32);
    buffer.writeln('RECEIPT #$receiptNo');
    buffer.writeln(DateFormat('yyyy-MM-dd HH:mm:ss').format(date));
    buffer.writeln('-' * 32);
    buffer.writeln('Item            Qty   Price   Total');
    for (final item in items) {
      final name = (item['name'] ?? '').toString();
      final qty = item['quantity'] as int;
      final price = (item['price'] as num).toDouble();
      final subtotal = price * qty;
      buffer.writeln('${name.padRight(15)} ${qty.toString().padLeft(3)} ${_formatMoney(price).padLeft(6)} ${_formatMoney(subtotal).padLeft(7)}');
    }
    buffer.writeln('-' * 32);
    buffer.writeln('TOTAL: ${_formatMoney(total).padLeft(26)}');
    buffer.writeln('Payment: $paymentMethod');
    if (paymentReference != null && paymentReference.isNotEmpty)
      buffer.writeln('Ref: $paymentReference');
    if (kraInvoiceId != null && kraInvoiceId.isNotEmpty)
      buffer.writeln('KRA Invoice: $kraInvoiceId');
    buffer.writeln();
    buffer.writeln(thankYou);
    return buffer.toString();
  }

  static String _formatMoney(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }
}