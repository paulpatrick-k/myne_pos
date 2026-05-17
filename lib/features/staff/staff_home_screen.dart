import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../features/cart/cart_provider.dart';
import '../../models/item_model.dart';
import 'package:pocketbase/pocketbase.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final pbService = PocketBaseService();
  Stream<List<RecordModel>>? _itemsStream;
  String? businessId;
  String _searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_itemsStream == null) {
      final auth = Provider.of<AuthProvider>(context);
      if (auth.businessId != null) {
        businessId = auth.businessId;
        _itemsStream = pbService.itemsStream(businessId!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Consumer<AuthProvider>(
          builder: (_, auth, __) => Row(
            children: [
              if (auth.businessLogoUrl != null && auth.businessLogoUrl!.isNotEmpty)
                Image.network(auth.businessLogoUrl!, height: 40, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              const SizedBox(width: 8),
              const Text('MYNE POS - Staff'),
            ],
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => Navigator.pushNamed(context, '/cart'),
              ),
              if (cartProvider.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${cartProvider.itemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search items',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: _itemsStream == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<RecordModel>>(
                    stream: _itemsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      var items = snapshot.data ?? [];
                      if (_searchQuery.isNotEmpty) {
                        items = items.where((record) {
                          final name = record.getStringValue('name').toLowerCase();
                          return name.contains(_searchQuery);
                        }).toList();
                      }
                      if (items.isEmpty) {
                        return const Center(child: Text('No items found'));
                      }
                      return ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (ctx, index) {
                          final record = items[index];
                          final item = ItemModel.fromRecord(record);
                          return ListTile(
                            leading: const Icon(Icons.inventory),
                            title: Text(item.name),
                            subtitle: Text('${auth.formatPrice(item.price)} | Stock: ${item.stockQty}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_shopping_cart),
                              onPressed: () {
                                final cartItem = CartItem(
                                  id: item.id,
                                  name: item.name,
                                  price: item.price,
                                  quantity: 1,
                                  maxStock: item.stockQty,
                                  category: item.category,
                                  expiryDate: item.expiryDate,
                                  batchNumber: item.batchNumber,
                                );
                                cartProvider.addItem(cartItem);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${item.name} added to cart')),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
