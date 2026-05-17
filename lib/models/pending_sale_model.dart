import 'package:hive/hive.dart';

part 'pending_sale_model.g.dart'; // We'll generate this adapter

@HiveType(typeId: 0)
class PendingSaleModel extends HiveObject {
  @HiveField(0)
  final String id; // local unique ID

  @HiveField(1)
  final String businessId;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final String userEmail;

  @HiveField(4)
  final List<Map<String, dynamic>> items; // each: {itemId, name, quantity, price}

  @HiveField(5)
  final double totalAmount;

  @HiveField(6)
  final String paymentMethod;

  @HiveField(7)
  final String? paymentReference;

  @HiveField(8)
  final String receiptNo; // local receipt (e.g., OFFLINE-12345)

  @HiveField(9)
  final DateTime createdAt;

  PendingSaleModel({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.userEmail,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentReference,
    required this.receiptNo,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'userId': userId,
        'userEmail': userEmail,
        'items': items,
        'totalAmount': totalAmount,
        'paymentMethod': paymentMethod,
        'paymentReference': paymentReference,
        'receiptNo': receiptNo,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingSaleModel.fromJson(Map<String, dynamic> json) => PendingSaleModel(
        id: json['id'],
        businessId: json['businessId'],
        userId: json['userId'],
        userEmail: json['userEmail'],
        items: List<Map<String, dynamic>>.from(json['items']),
        totalAmount: json['totalAmount'],
        paymentMethod: json['paymentMethod'],
        paymentReference: json['paymentReference'],
        receiptNo: json['receiptNo'],
        createdAt: DateTime.parse(json['createdAt']),
      );
}