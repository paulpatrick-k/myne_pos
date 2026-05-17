import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';
import 'cart_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _logAction(BuildContext context, String action, Map<String, dynamic> details) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Safety check - prevent null crash
    if (auth.businessId == null || auth.userId == null) {
      print('⚠️ Skipping audit log: auth data not available');
      return;
    }

    try {
      await PocketBaseService().logAuditAction(
        userId: auth.userId!,
        userEmail: auth.userEmail ?? 'unknown',
        action: action,
        details: details,
      );
    } catch (e) {
      print('Failed to log action: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: cart.items.isEmpty
          ? const Center(child: Text('Cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      final item = cart.items[i];
                      return ListTile(
                        leading: CircleAvatar(child: Text('${item.quantity}')),
                        title: Text(item.name),
                        subtitle: Text('${auth.formatPrice(item.price)} each'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () async {
                                final oldQty = item.quantity;
                                cart.updateQuantity(item.id, item.quantity - 1);
                                if (item.quantity - 1 < oldQty) {
                                  await _logAction(context, 'decrease_cart_quantity', {
                                    'item_id': item.id,
                                    'item_name': item.name,
                                    'old_quantity': oldQty,
                                    'new_quantity': item.quantity - 1,
                                  });
                                }
                              },
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                cart.updateQuantity(item.id, item.quantity + 1);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _logAction(context, 'remove_from_cart', {
                                  'item_id': item.id,
                                  'item_name': item.name,
                                  'quantity': item.quantity,
                                });
                                cart.removeItem(item.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total:', style: Theme.of(context).textTheme.titleLarge),
                      Text(auth.formatPrice(cart.totalPrice),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: cart.items.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CheckoutScreen()),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Proceed to Checkout'),
                  ),
                ),
              ],
            ),
    );
  }
}