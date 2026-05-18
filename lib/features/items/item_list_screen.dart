import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../features/cart/cart_provider.dart';
import '../../models/item_model.dart';
import 'item_form_screen.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final pbService = PocketBaseService();
  Stream<List<RecordModel>>? _itemsStream;
  String? businessId;
  bool isAdmin = false;
  String? _selectedDrinkCategoryFilter;
  String? _expiryFilter;  // NEW: pharmacy filter ('all', 'expiring_soon', 'expired')

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_itemsStream == null) {
      final auth = Provider.of<AuthProvider>(context);
      if (auth.businessId != null) {
        businessId = auth.businessId;
        _itemsStream = pbService.itemsStream(businessId!);
        isAdmin = auth.role == 'admin';
        // Initialize expiry filter for pharmacy
        if (auth.businessCategory?.toLowerCase() == 'pharmacy') {
          _expiryFilter ??= 'all';
        }
      }
    }
  }

  Future<void> _deleteItem(String itemId) async {
    if (!isAdmin) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await pbService.deleteItem(itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<bool> _checkOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult is Iterable) {
      return connectivityResult
          .whereType<ConnectivityResult>()
          .any((result) => result != ConnectivityResult.none);
    }
    return connectivityResult != ConnectivityResult.none;
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    isAdmin = auth.role == 'admin';
    final isLiquorBusiness = auth.businessCategory?.toLowerCase() == 'liquor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Items'),
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
        ],
      ),
      body: _itemsStream == null
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
                final items = snapshot.data ?? [];
                final categories = items
                    .map((record) => ItemModel.fromRecord(record).customData['drink_category']?.toString().trim())
                    .where((value) => value != null && value.isNotEmpty)
                    .cast<String>()
                    .toSet()
                    .toList()
                  ..sort();

                final shouldFilter = isLiquorBusiness && _selectedDrinkCategoryFilter != null && _selectedDrinkCategoryFilter != 'All';
                var filteredItems = shouldFilter
                    ? items.where((record) => ItemModel.fromRecord(record).customData['drink_category']?.toString() == _selectedDrinkCategoryFilter).toList()
                    : items;

                // expiry filter (pharmacy only)
                final isPharmacy = auth.businessCategory?.toLowerCase() == 'pharmacy';
                if (isPharmacy && _expiryFilter != null && _expiryFilter != 'all') {
                  filteredItems = filteredItems.where((record) {
                    final item = ItemModel.fromRecord(record);
                    final status = item.expiryStatus;
                    if (_expiryFilter == 'expired') return status == 'expired';
                    if (_expiryFilter == 'expiring_soon') return status == 'expiring_soon';
                    return true;
                  }).toList();
                }

                if (filteredItems.isEmpty) {
                  return const Center(child: Text('No items yet.'));
                }
                return Column(
                  children: [
                    if (isLiquorBusiness)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: DropdownButtonFormField<String>(
                          value: _selectedDrinkCategoryFilter ?? 'All',
                          decoration: const InputDecoration(
                            labelText: 'Filter by Drink Category',
                            border: OutlineInputBorder(),
                          ),
                          items: ['All', 'Soft Drink', 'Beer', 'Hard Liquor']
                              .map((c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedDrinkCategoryFilter = value),
                        ),
                      ),
                    if (isPharmacy)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: DropdownButtonFormField<String>(
                          value: _expiryFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Expiry',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Items')),
                            DropdownMenuItem(value: 'expiring_soon', child: Text('Expiring Soon (30 days)')),
                            DropdownMenuItem(value: 'expired', child: Text('Expired')),
                          ],
                          onChanged: (value) => setState(() => _expiryFilter = value),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredItems.length,
                        itemBuilder: (ctx, index) {
                          final record = filteredItems[index];
                          final item = ItemModel.fromRecord(record);
                          final itemType = item.itemType != null ? item.itemType!.toUpperCase() : null;
                          final drinkCategory = item.customData['drink_category']?.toString();
                          String customPreview = '';
                          if (drinkCategory != null && drinkCategory.isNotEmpty) {
                            customPreview = 'Category: $drinkCategory';
                          }
                          if (itemType != null && itemType.isNotEmpty) {
                            customPreview = customPreview.isEmpty ? 'Type: $itemType' : '$customPreview | Type: $itemType';
                          }
                          if (customPreview.isEmpty && item.customData.isNotEmpty) {
                            customPreview = item.customData.entries
                                .take(2)
                                .map((e) => '${e.key}: ${e.value}')
                                .join(', ');
                          }

                          // Expiry info for pharmacy
                          String? expiryInfo;
                          if (isPharmacy && item.expiryDate != null) {
                            final formatted = DateFormat('yyyy-MM-dd').format(item.expiryDate!);
                            expiryInfo = 'Exp: $formatted | Batch: ${item.batchNumber ?? '-'}';
                          }

                          return ListTile(
                            leading: const Icon(Icons.inventory),
                            title: Text(item.name),
                            subtitle: Text(
                              'Price: ${auth.formatPrice(item.price)} | Stock: ${item.stockQty}'
                              '${expiryInfo != null ? '\n$expiryInfo' : ''}'
                              '${customPreview.isNotEmpty ? '\n$customPreview' : ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
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
                                if (isAdmin) ...[
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteItem(item.id),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () async {
                              if (isAdmin) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ItemFormScreen(item: item),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () async {
                final online = await _checkOnline();
                if (!online && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You need internet to add items')),
                  );
                  return;
                }
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ItemFormScreen()),
                  );
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}