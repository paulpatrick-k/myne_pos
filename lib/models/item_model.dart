import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';

class ItemModel {
  final String id;
  final String businessId;
  final String name;
  final double price;
  final int stockQty;
  final String category;
  final String? description;
  final Map<String, dynamic> customData;
  final DateTime created;
  final DateTime updated;

  // Phase 6 new fields
  final String? itemType;
  final String? parentBottleId;
  final int? shotsPerBottle;

  ItemModel({
    required this.id,
    required this.businessId,
    required this.name,
    required this.price,
    required this.stockQty,
    required this.category,
    this.description,
    this.customData = const {},
    required this.created,
    required this.updated,
    this.itemType,
    this.parentBottleId,
    this.shotsPerBottle,
  });

  // Pharmacy convenience getters
  String? get batchNumber => customData['batch_number']?.toString();
  String? get dosage => customData['dosage']?.toString();
  String? get manufacturer => customData['manufacturer']?.toString();

  DateTime? get expiryDate {
    final raw = customData['expiry_date'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateTime.parse(raw);
      } catch (_) {}
    }
    return null;
  }

  String get expiryStatus {
    final date = expiryDate;
    if (date == null) return 'ok';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(date.year, date.month, date.day);
    if (expiryDay.isBefore(today)) return 'expired';
    if (expiryDay.difference(today).inDays <= 30) return 'expiring_soon';
    return 'ok';
  }

  factory ItemModel.fromRecord(RecordModel record) {
    final data = record.data;
    return ItemModel(
      id: record.id,
      businessId: _stringValue(data['business_id']),
      name: _stringValue(data['name']),
      price: _doubleValue(data['price']),
      stockQty: _intValue(data['stock_qty']),
      category: _stringValue(data['category']),
      description: data['description']?.toString(),
      customData: _parseCustomData(data['custom_data']),
      created: _parseDateTime(data['created']),
      updated: _parseDateTime(data['updated']),
      itemType: data['item_type']?.toString(),
      parentBottleId: data['parent_bottle_id']?.toString(),
      shotsPerBottle: _intOrNull(data['shots_per_bottle']),
    );
  }

  static String _stringValue(dynamic value) {
    return value?.toString() ?? '';
  }

  static double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
    return 0;
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    return null;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static Map<String, dynamic> _parseCustomData(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  Map<String, dynamic> toMap() {
    return {
      'business_id': businessId,
      'name': name,
      'price': price,
      'stock_qty': stockQty,
      'category': category,
      'description': description,
      'custom_data': customData,
      if (itemType != null) 'item_type': itemType,
      if (parentBottleId != null) 'parent_bottle_id': parentBottleId,
      if (shotsPerBottle != null) 'shots_per_bottle': shotsPerBottle,
      // We do not include created/updated – PocketBase manages them
    };
  }

  ItemModel copyWith({
    String? id,
    String? businessId,
    String? name,
    double? price,
    int? stockQty,
    String? category,
    String? description,
    Map<String, dynamic>? customData,
    DateTime? created,
    DateTime? updated,
    String? itemType,
    String? parentBottleId,
    int? shotsPerBottle,
  }) {
    return ItemModel(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      name: name ?? this.name,
      price: price ?? this.price,
      stockQty: stockQty ?? this.stockQty,
      category: category ?? this.category,
      description: description ?? this.description,
      customData: customData ?? this.customData,
      created: created ?? this.created,
      updated: updated ?? this.updated,
      itemType: itemType ?? this.itemType,
      parentBottleId: parentBottleId ?? this.parentBottleId,
      shotsPerBottle: shotsPerBottle ?? this.shotsPerBottle,
    );
  }
}