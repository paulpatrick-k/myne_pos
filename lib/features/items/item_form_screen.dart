import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../models/item_model.dart';

class ItemFormScreen extends StatefulWidget {
  final ItemModel? item;
  const ItemFormScreen({super.key, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descController = TextEditingController();

  // Dynamic controllers
  final Map<String, TextEditingController> _dynamicControllers = {};
  final _shotsPerBottleController = TextEditingController();
  String? _selectedSize; // for boutique
  DateTime? _selectedExpiry; // for pharmacy/beauty
  bool _isLoading = false;

  late PocketBaseService pbService;
  String? businessId;
  String? businessCategory;
  bool _authReady = false;

  // Phase 6 fields
  String? _selectedItemType;
  String? _parentBottleId;
  int? _shotsPerBottle;
  List<RecordModel> _bottleItems = [];
  bool _loadingBottles = false;

  // Phase 6 refined drink categories
  String? _selectedMainDrinkCategory;   // "Soft Drink", "Beer", "Hard Liquor"
  String? _selectedDrinkSubCategory;    // sub-type or custom value
  final TextEditingController _otherDrinkSubCategoryController = TextEditingController();

  // Boutique clothing type
  String? _selectedClothingType;
  final TextEditingController _otherClothingTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_authReady) {
      final auth = Provider.of<AuthProvider>(context);
      if (auth.businessId != null && auth.businessCategory != null) {
        businessId = auth.businessId;
        businessCategory = auth.businessCategory;
        pbService = PocketBaseService();

        if (widget.item != null) {
          final item = widget.item!;
          _nameController.text = item.name;
          _priceController.text = item.price.toString();
          _stockController.text = item.stockQty.toString();
          _descController.text = item.description ?? '';
          _prefillDynamic(item.customData);

          _selectedItemType = item.itemType?.toLowerCase();
          _shotsPerBottleController.text = item.shotsPerBottle?.toString() ?? '';
          _parentBottleId = item.parentBottleId;

          // Pre-fill drink categories
          final oldDrinkCategory = item.customData['drink_category']?.toString();
          if (oldDrinkCategory != null) {
            // map old values if needed (optional)
            if (oldDrinkCategory == 'Hard Beer') {
              _selectedMainDrinkCategory = 'Beer';
            } else if (oldDrinkCategory == 'Liquor') {
              _selectedMainDrinkCategory = 'Hard Liquor';
            } else {
              _selectedMainDrinkCategory = oldDrinkCategory;
            }
          } else {
            _selectedMainDrinkCategory = null;
          }
          String? sub = item.customData['drink_subcategory']?.toString();
          if (sub != null) {
            if (sub == 'Others') {
              _selectedDrinkSubCategory = 'Others';
            } else if (['Soda', 'Juice', 'Water', 'Vodka', 'Whisky', 'Brandy', 'Cognac', 'Spirit', 'Rum', 'Wine'].contains(sub)) {
              _selectedDrinkSubCategory = sub;
            } else {
              // custom
              _selectedDrinkSubCategory = 'Others';
              _otherDrinkSubCategoryController.text = sub;
            }
          }

          // Pre-fill clothing type
          if (item.customData['clothing_type'] != null) {
            String ct = item.customData['clothing_type']!;
            if ([
              'T-Shirt', 'Shirt', 'Skirt', 'Trouser', 'Shorts', 'Shoes', 'Tie',
              'Jacket', 'Coat', 'Sweater', 'Hoodie', 'Dress', 'Suit', 'Blouse',
              'Vest', 'Jeans', 'Leggings', 'Joggers', 'Cap', 'Hat', 'Scarf',
              'Gloves', 'Socks', 'Underwear', 'Belt', 'Watch', 'Bangle', 'Necklace',
              'Earrings', 'Ring', 'Bag', 'Backpack', 'Wallet', 'Sunglasses',
              'Swimsuit', 'Sportswear', 'Others'
            ].contains(ct)) {
              _selectedClothingType = ct;
              if (ct == 'Others') {
                _otherClothingTypeController.text = item.customData['clothing_type'] ?? '';
              }
            } else {
              _selectedClothingType = 'Others';
              _otherClothingTypeController.text = ct;
            }
          }
        }

        if (businessCategory == 'liquor') {
          _loadBottleItems();
        }

        _authReady = true;
      }
    }
  }

  void _prefillDynamic(Map<String, dynamic> data) {
    // Keep the custom data around for the dynamic field builder to use.
    // The actual controllers are created lazily so we don't rebuild them repeatedly.
  }

  Future<void> _loadBottleItems() async {
    setState(() => _loadingBottles = true);
    try {
      _bottleItems = await pbService.getBottleItems(businessId!);
    } catch (e) {
      print('Load bottles error: $e');
    } finally {
      if (mounted) setState(() => _loadingBottles = false);
    }
  }


  TextEditingController _getDynamicController(String key, String? initialValue) {
    final existing = _dynamicControllers[key];
    if (existing != null) {
      if (existing.text.isEmpty && initialValue != null) {
        existing.text = initialValue;
      }
      return existing;
    }
    final controller = TextEditingController(text: initialValue);
    _dynamicControllers[key] = controller;
    return controller;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descController.dispose();
    _shotsPerBottleController.dispose();
    _otherDrinkSubCategoryController.dispose();
    _otherClothingTypeController.dispose();
    for (final controller in _dynamicControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (businessCategory == 'liquor') {
      if (_selectedMainDrinkCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select drink category')),
        );
        return;
      }
      if (_selectedMainDrinkCategory != 'Beer') {
        // Sub-category required for Soft Drink and Hard Liquor
        if (_selectedDrinkSubCategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select type of drink')),
          );
          return;
        }
        if (_selectedDrinkSubCategory == 'Others' &&
            _otherDrinkSubCategoryController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please specify the drink type')),
          );
          return;
        }
      }
      if (_selectedItemType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select item type')),
        );
        return;
      }
      if (_selectedItemType == 'bottle' && _shotsPerBottleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter shots per bottle')),
        );
        return;
      }
      if (_selectedItemType == 'shot' && (_parentBottleId == null || _parentBottleId!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a parent bottle')),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
        'business_id': businessId!,
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'stock_qty': int.parse(_stockController.text.trim()),
        'category': businessCategory!,
        'description': _descController.text.trim(),
      };

      if (businessCategory == 'liquor') {
        data['item_type'] = _selectedItemType;
        if (_selectedItemType == 'bottle') {
          final shotsPerBottle = int.tryParse(_shotsPerBottleController.text.trim());
          if (shotsPerBottle != null) {
            data['shots_per_bottle'] = shotsPerBottle;
          }
        }
        if (_selectedItemType == 'shot' && _parentBottleId != null && _parentBottleId!.isNotEmpty) {
          data['parent_bottle_id'] = _parentBottleId;
        }
      }

      data['custom_data'] = _gatherCustomData();

      if (widget.item == null) {
        await pbService.createItem(businessId!, data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added!')),
        );
      } else {
        await pbService.updateItem(widget.item!.id, data);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated!')),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _gatherCustomData() {
    final data = <String, dynamic>{};

    // New drink categories (liquor)
    if (businessCategory == 'liquor') {
      data['drink_category'] = _selectedMainDrinkCategory;
      if (_selectedMainDrinkCategory == 'Beer') {
        // no subcategory
      } else if (_selectedDrinkSubCategory != null) {
        if (_selectedDrinkSubCategory == 'Others') {
          // store the typed text as subcategory
          data['drink_subcategory'] = _otherDrinkSubCategoryController.text.trim();
        } else {
          data['drink_subcategory'] = _selectedDrinkSubCategory;
        }
      }
    }

    // Boutique clothing type
    if (businessCategory == 'boutique') {
      if (_selectedClothingType != null) {
        data['clothing_type'] = _selectedClothingType == 'Others'
            ? _otherClothingTypeController.text.trim()
            : _selectedClothingType;
      }
    }

    switch (businessCategory!.toLowerCase()) {
      case 'boutique':
        if (_selectedSize != null) data['size'] = _selectedSize;
        _addIfNotEmpty('color', data);
        _addIfNotEmpty('material', data);
        break;
      case 'pharmacy':
        if (_selectedExpiry != null)
          data['expiry_date'] = DateFormat('yyyy-MM-dd').format(_selectedExpiry!);
        _addIfNotEmpty('batch_number', data);
        _addIfNotEmpty('dosage', data);
        _addIfNotEmpty('manufacturer', data);
        break;
      case 'hardware':
        _addIfNotEmpty('unit', data);
        _addIfNotEmpty('brand', data);
        _addIfNotEmptyNumber('weight_kg', data);
        break;
      case 'beauty':
        _addIfNotEmpty('brand', data);
        _addIfNotEmptyNumber('volume_ml', data);
        _addIfNotEmpty('skin_type', data);
        if (_selectedExpiry != null)
          data['expiry_date'] = DateFormat('yyyy-MM-dd').format(_selectedExpiry!);
        break;
      case 'liquor':
        _addIfNotEmptyNumber('volume_ml', data);
        _addIfNotEmptyNumber('alcohol_percent', data);
        _addIfNotEmpty('brand', data);
        _addIfNotEmpty('country_of_origin', data);
        break;
      case 'bookshop':
        _addIfNotEmpty('author', data);
        _addIfNotEmpty('isbn', data);
        _addIfNotEmpty('publisher', data);
        _addIfNotEmptyNumber('publication_year', data);
        break;
      default:
        // store all dynamic controller values as string
        _dynamicControllers.forEach((key, ctrl) {
          final val = ctrl.text.trim();
          if (val.isNotEmpty) data[key] = val;
        });
    }
    return data;
  }

  void _addIfNotEmpty(String key, Map map) {
    final v = _dynamicControllers[key]?.text.trim();
    if (v != null && v.isNotEmpty) map[key] = v;
  }

  void _addIfNotEmptyNumber(String key, Map map) {
    final v = _dynamicControllers[key]?.text.trim();
    if (v != null && v.isNotEmpty) {
      final num = double.tryParse(v) ?? int.tryParse(v);
      if (num != null) map[key] = num;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady || businessId == null || businessCategory == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Common fields
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Enter a number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(labelText: 'Stock Qty *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Enter a whole number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              // Dynamic section
              Text('Category Specific Fields ($businessCategory)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._buildDynamicFields(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(widget.item == null ? 'Create Item' : 'Update Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDynamicFields() {
    final fields = <Widget>[];
    final itemData = widget.item?.customData ?? {};

    // Helper to get pre-filled value
    String? prefill(String key) => itemData[key]?.toString();

    switch (businessCategory!.toLowerCase()) {
      case 'boutique':
        if (_selectedSize == null) {
          _selectedSize = prefill('size');
        }

        fields.add(
          DropdownButtonFormField<String>(
            value: _selectedSize,
            decoration: const InputDecoration(labelText: 'Size *'),
            items: ['XS', 'S', 'M', 'L', 'XL', 'XXL']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedSize = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
        );
        fields.add(const SizedBox(height: 16));
        // Color
        _addTextFieldTo(fields, 'color', 'Color *', prefill('color'), required: true);
        fields.add(const SizedBox(height: 16));
        // Material
        _addTextFieldTo(fields, 'material', 'Material', prefill('material'), required: false);
        fields.add(const SizedBox(height: 16));
        // Clothing type
        fields.add(const Text('Clothing Type', style: TextStyle(fontWeight: FontWeight.w500)));
        fields.add(const SizedBox(height: 8));
        fields.add(
          DropdownButtonFormField<String>(
            value: _selectedClothingType,
            decoration: const InputDecoration(labelText: 'Type of Wear *'),
            items: [
              'T-Shirt', 'Shirt', 'Skirt', 'Trouser', 'Shorts', 'Shoes', 'Tie',
              'Jacket', 'Coat', 'Sweater', 'Hoodie', 'Dress', 'Suit', 'Blouse',
              'Vest', 'Jeans', 'Leggings', 'Joggers', 'Cap', 'Hat', 'Scarf',
              'Gloves', 'Socks', 'Underwear', 'Belt', 'Watch', 'Bangle', 'Necklace',
              'Earrings', 'Ring', 'Bag', 'Backpack', 'Wallet', 'Sunglasses',
              'Swimsuit', 'Sportswear', 'Others'
            ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedClothingType = v;
                if (v != 'Others') _otherClothingTypeController.clear();
              });
            },
            validator: (v) => v == null ? 'Required' : null,
          ),
        );
        if (_selectedClothingType == 'Others')
          fields.add(
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextFormField(
                controller: _otherClothingTypeController,
                decoration: const InputDecoration(labelText: 'Specify clothing type'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          );
        break;

      case 'pharmacy':
        if (_selectedExpiry == null && prefill('expiry_date') != null) {
          _selectedExpiry = DateFormat('yyyy-MM-dd').parse(prefill('expiry_date')!);
        }
        fields.add(
          _buildDatePicker('expiry_date', 'Expiry Date *', required: true),
        );
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'batch_number', 'Batch Number *', prefill('batch_number'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'dosage', 'Dosage *', prefill('dosage'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'manufacturer', 'Manufacturer *', prefill('manufacturer'), required: true);
        break;

      case 'hardware':
        _addTextFieldTo(fields, 'unit', 'Unit (piece/meter/kg) *', prefill('unit'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'brand', 'Brand *', prefill('brand'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'weight_kg', 'Weight (kg)', prefill('weight_kg'), required: false, number: true);
        break;

      case 'beauty':
        _addTextFieldTo(fields, 'brand', 'Brand *', prefill('brand'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'volume_ml', 'Volume (ml) *', prefill('volume_ml'), required: true, number: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'skin_type', 'Skin type', prefill('skin_type'), required: false);
        fields.add(const SizedBox(height: 16));
        if (_selectedExpiry == null && prefill('expiry_date') != null) {
          _selectedExpiry = DateFormat('yyyy-MM-dd').parse(prefill('expiry_date')!);
        }
        fields.add(
          _buildDatePicker('expiry_date', 'Expiry Date (optional)', required: false),
        );
        break;

      case 'liquor':
        fields.add(const SizedBox(height: 24));
        fields.add(const Text('Liquor Details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
        fields.add(const SizedBox(height: 12));

        // Main drink category
        fields.add(
          DropdownButtonFormField<String>(
            value: _selectedMainDrinkCategory,
            decoration: const InputDecoration(labelText: 'Drink Category *'),
            items: ['Soft Drink', 'Beer', 'Hard Liquor']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedMainDrinkCategory = v;
                // reset sub-category when main changes
                _selectedDrinkSubCategory = null;
                _otherDrinkSubCategoryController.clear();
              });
            },
            validator: (v) => v == null ? 'Required' : null,
          ),
        );
        fields.add(const SizedBox(height: 16));

        // Sub-category for Soft Drink
        if (_selectedMainDrinkCategory == 'Soft Drink') {
          fields.add(
            DropdownButtonFormField<String>(
              value: _selectedDrinkSubCategory,
              decoration: const InputDecoration(labelText: 'Type of Soft Drink *'),
              items: ['Soda', 'Juice', 'Water', 'Others']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedDrinkSubCategory = v;
                  if (v != 'Others') _otherDrinkSubCategoryController.clear();
                });
              },
              validator: (v) => v == null ? 'Required' : null,
            ),
          );
          if (_selectedDrinkSubCategory == 'Others')
            fields.add(
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextFormField(
                  controller: _otherDrinkSubCategoryController,
                  decoration: const InputDecoration(labelText: 'Specify soft drink'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            );
        }

        // Sub-category for Hard Liquor
        if (_selectedMainDrinkCategory == 'Hard Liquor') {
          fields.add(
            DropdownButtonFormField<String>(
              value: _selectedDrinkSubCategory,
              decoration: const InputDecoration(labelText: 'Type of Hard Liquor *'),
              items: ['Vodka', 'Whisky', 'Brandy', 'Cognac', 'Spirit', 'Rum', 'Wine', 'Others']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedDrinkSubCategory = v;
                  if (v != 'Others') _otherDrinkSubCategoryController.clear();
                });
              },
              validator: (v) => v == null ? 'Required' : null,
            ),
          );
          if (_selectedDrinkSubCategory == 'Others')
            fields.add(
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextFormField(
                  controller: _otherDrinkSubCategoryController,
                  decoration: const InputDecoration(labelText: 'Specify hard liquor'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            );
        }

        fields.add(const SizedBox(height: 16));
        fields.add(
          DropdownButtonFormField<String>(
            value: _selectedItemType,
            decoration: const InputDecoration(labelText: 'Item Type *'),
            items: ['Bottle', 'Shot']
                .map((t) => DropdownMenuItem(value: t.toLowerCase(), child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedItemType = v;
              _shotsPerBottle = null;
              _parentBottleId = null;
            }),
            validator: (v) => v == null ? 'Required' : null,
          ),
        );
        if (_selectedItemType == 'bottle') {
          fields.add(const SizedBox(height: 16));
          fields.add(
            TextFormField(
              controller: _shotsPerBottleController,
              decoration: const InputDecoration(labelText: 'Shots per Bottle *'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (_selectedItemType == 'bottle') {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  if (int.tryParse(value) == null) return 'Enter a whole number';
                }
                return null;
              },
            ),
          );
        }
        if (_selectedItemType == 'shot') {
          fields.add(const SizedBox(height: 16));
          if (_loadingBottles) {
            fields.add(const Center(child: CircularProgressIndicator()));
          } else if (_bottleItems.isEmpty) {
            fields.add(const Text('No bottle items available. Create a bottle first.'));
          } else {
            fields.add(
              DropdownButtonFormField<String>(
                value: _parentBottleId,
                decoration: const InputDecoration(labelText: 'Parent Bottle *'),
                items: _bottleItems
                    .map((record) => DropdownMenuItem(
                          value: record.id,
                          child: Text(record.getStringValue('name') ?? 'Unnamed bottle'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _parentBottleId = value),
                validator: (value) {
                  if (_selectedItemType == 'shot') {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Required';
                  }
                  return null;
                },
              ),
            );
          }
        }
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'volume_ml', 'Volume (ml) *', prefill('volume_ml'), required: true, number: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'alcohol_percent', 'Alcohol % *', prefill('alcohol_percent'), required: true, number: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'brand', 'Brand *', prefill('brand'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'country_of_origin', 'Country of Origin *', prefill('country_of_origin'), required: true);
        break;

      case 'bookshop':
        _addTextFieldTo(fields, 'author', 'Author *', prefill('author'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'isbn', 'ISBN *', prefill('isbn'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'publisher', 'Publisher *', prefill('publisher'), required: true);
        fields.add(const SizedBox(height: 16));
        _addTextFieldTo(fields, 'publication_year', 'Publication Year *', prefill('publication_year'), required: true, number: true);
        break;

      default:
        fields.add(const Text('No custom fields available.'));
    }
    return fields;
  }

  Widget _buildDatePicker(String key, String label, {bool required = false}) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedExpiry ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) setState(() => _selectedExpiry = date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          _selectedExpiry != null ? DateFormat('yyyy-MM-dd').format(_selectedExpiry!) : 'Tap to select',
        ),
      ),
    );
  }

  void _addTextFieldTo(List<Widget> container, String key, String label, String? initialValue,
      {bool required = true, bool number = false}) {
    final ctrl = _getDynamicController(key, initialValue);
    container.add(
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
        keyboardType: number ? TextInputType.number : TextInputType.text,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}