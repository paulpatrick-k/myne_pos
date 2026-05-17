import 'package:flutter/material.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  int quantity;
  final int maxStock; // current stock from server
  final String? category;       // NEW
  final DateTime? expiryDate;   // NEW
  final String? batchNumber;    // NEW

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.maxStock,
    this.category,
    this.expiryDate,
    this.batchNumber,
  });

  double get subtotal => price * quantity;
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.subtotal);

  void addItem(CartItem item) {
    final existingIndex = _items.indexWhere((i) => i.id == item.id);
    if (existingIndex != -1) {
      final existing = _items[existingIndex];
      if (existing.quantity < existing.maxStock) {
        existing.quantity++;
      } else {
        // Optionally show a snackbar – but we'll handle UI feedback outside
      }
    } else {
      if (item.quantity <= item.maxStock) {
        _items.add(item);
      }
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void updateQuantity(String id, int newQuantity) {
    final index = _items.indexWhere((i) => i.id == id);
    if (index != -1) {
      final item = _items[index];
      if (newQuantity > 0 && newQuantity <= item.maxStock) {
        item.quantity = newQuantity;
      } else if (newQuantity == 0) {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}