import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' show MultipartFile;

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  late final PocketBase pb;           // Normal user client
  late final PocketBase adminPb;      // Superuser client for writes
  bool _isInitialized = false;

  void _init() {
    if (_isInitialized) return;
    final url = dotenv.env['POCKETBASE_URL'] ?? 'http://127.0.0.1:8090';
    pb = PocketBase(url);
    adminPb = PocketBase(url);
    _isInitialized = true;
  }

  Future<void> ensureAdminAuth() async {
    if (!_isInitialized) _init();

    if (adminPb.authStore.isValid) return;

    final adminEmail = dotenv.env['PB_ADMIN_EMAIL'] ?? 'admin@mynepos.com';
    final adminPassword = dotenv.env['PB_ADMIN_PASSWORD'] ?? 'Admin1234!';

    try {
      await adminPb.admins.authWithPassword(adminEmail, adminPassword);
      print('✅ Superuser (Admin) authenticated successfully');
    } catch (e) {
      print('❌ Superuser auth failed: $e');
      rethrow;
    }
  }

  // ---------- Error handling (unchanged) ----------
  Never _handleError(dynamic e, [String context = '']) {
    final msg = _formatErrorMessage(e);
    throw Exception('$context$msg');
  }

  String _formatErrorMessage(dynamic e) {
    if (e is ClientException) {
      final response = e.response as Map?;
      if (response != null) {
        final message = response['message'];
        if (message != null) return _flattenErrorValue(message);
        final data = response['data'];
        if (data != null) return _flattenErrorValue(data);
      }
      return e.toString();
    }
    if (e is Exception) {
      return e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    }
    return e.toString();
  }

  String _flattenErrorValue(dynamic value) {
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${_flattenErrorValue(entry.value)}')
          .join('; ');
    }
    if (value is List) {
      return value.map(_flattenErrorValue).join('; ');
    }
    return value?.toString() ?? '';
  }

  // ---------- Phase 1 methods (unchanged) ----------
  String generateRandomPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  String generateBusinessCode(String category) {
    String prefix;
    switch (category.toLowerCase()) {
      case 'boutique': prefix = 'BOU'; break;
      case 'pharmacy': prefix = 'PHA'; break;
      case 'hardware': prefix = 'HAR'; break;
      case 'beauty': prefix = 'BEA'; break;
      case 'liquor': prefix = 'LIQ'; break;
      case 'bookshop': prefix = 'BOO'; break;
      default: prefix = category.substring(0, 3).toUpperCase();
    }
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final suffix = String.fromCharCodes(
      Iterable.generate(5, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    return '$prefix-$suffix';
  }

  Future<Map<String, String>> createBusinessAndAdmin({
    required String businessName,
    required String email,
    required String phone,
    required String address,
    required String category,
    required String country,
    required String currencyCode,
  }) async {
    await ensureAdminAuth();

    final businessCode = generateBusinessCode(category);
    final businessData = {
      'business_name': businessName,
      'phone': phone,
      'address': address,
      'category': category,
      'unique_code': businessCode,
      'trial_start': DateTime.now().toIso8601String(),
      'trial_end': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'subscription_active': false,
      'country': country,
      'currency_code': currencyCode,
    };

    RecordModel business;
    try {
      business = await adminPb.collection('businesses').create(body: businessData);
      print('✅ Business created: ID=${business.id}, Code=$businessCode');
    } catch (e) {
      print('❌ Business creation failed: $e');
      if (e is ClientException) {
        print('Response data: ${e.response}');
      }
      rethrow;
    }
    final businessId = business.id;

    String adminPassword;
    try {
      adminPassword = generateRandomPassword();
      await adminPb.collection('user').create(body: {
        'email': email,
        'password': adminPassword,
        'passwordConfirm': adminPassword,
        'role': 'admin',
        'business_id': businessId,
      });
      print('✅ User created for $email with password: $adminPassword');
    } catch (e) {
      // Rollback business creation
      await adminPb.collection('businesses').delete(businessId);
      throw Exception('User creation failed, business rolled back: $e');
    }

    // Verify with admin client
    try {
      final testAuth = await adminPb.collection('user').authWithPassword(email, adminPassword);
      print('✅ Verification successful for ${testAuth.record?.id}');
    } catch (e) {
      print('⚠️ User verification failed: $e');
    }

    return {
      'businessCode': businessCode,
      'adminPassword': adminPassword,
      'businessId': businessId,
    };
  }

  Future<Map<String, dynamic>> login({
    required String businessCode,
    required String email,
    required String password,
  }) async {
    if (!_isInitialized) _init();

    // 1. Fetch business using ADMIN client (bypasses list rules)
    await ensureAdminAuth(); // ensure superuser is authenticated
    final normalizedCode = businessCode.trim().toUpperCase();
    print('🔍 Looking for business with code: "$normalizedCode"');
    final businesses = await adminPb.collection('businesses').getList(
      filter: 'unique_code = "$normalizedCode"',
    );
    if (businesses.items.isEmpty) {
      print('❌ No business found with code: $normalizedCode');
      throw Exception('Invalid business code');
    }
    final business = businesses.items.first;
    final businessId = business.id;
    print('✅ Business found: $businessId');

    // 2. Authenticate the user with normal client
    RecordModel user;
    try {
      print('🔐 Attempting authentication for $email');
      final authData = await pb.collection('user').authWithPassword(email, password);
      user = authData.record!;
      print('✅ User authenticated: ${user.id}');
    } catch (e) {
      print('❌ Authentication failed: $e');
      throw Exception('Invalid email or password');
    }

    // 3. Verify user belongs to this business
    if (user.getStringValue('business_id') != businessId) {
      throw Exception('User does not belong to this business');
    }

    // 4. Return session data
    return {
      'user': user,
      'userId': user.id,
      'businessId': businessId,
      'role': user.getStringValue('role'),
      'businessCategory': business.getStringValue('category'),
      'businessCode': businessCode,
    };
  }

  void logout() {
    if (!_isInitialized) _init();
    pb.authStore.clear();
  }

  bool get isLoggedIn {
    if (!_isInitialized) _init();
    return pb.authStore.isValid && pb.authStore.token.isNotEmpty;
  }

  String? get currentUserId {
    if (!_isInitialized) _init();
    return pb.authStore.model?.id;
  }

  String? get currentUserEmail {
    if (!_isInitialized) _init();
    return pb.authStore.model?.getStringValue('email');
  }

  // ---------- Phase 2 – offline & real‑time items (unchanged) ----------
  Future<bool> _isOnline() async {
    final dynamic connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult is Iterable) {
      return connectivityResult
          .whereType<ConnectivityResult>()
          .any((result) => result != ConnectivityResult.none);
    }
    return connectivityResult != ConnectivityResult.none;
  }

  String _itemCacheKey(String businessId) => 'items_cache_$businessId';

  Future<List<RecordModel>> getItems(String businessId) async {
    if (!_isInitialized) _init();
    if (!isLoggedIn) throw Exception('Not authenticated');

    final online = await _isOnline();
    if (!online) {
      return _getCachedItems(businessId);
    }

    try {
      // Use adminPb (superuser) to bypass strict listRule
      final result = await adminPb.collection('items').getList(
        filter: 'business_id = "$businessId"',
        sort: '-created',
      );
      await _cacheItems(businessId, result.items);
      return result.items;
    } catch (e) {
      print('Failed to fetch items with admin client: $e');
      // Fallback to normal client (for staff who may have list permission)
      try {
        final result = await pb.collection('items').getList(
          filter: 'business_id = "$businessId"',
          sort: '-created',
        );
        await _cacheItems(businessId, result.items);
        return result.items;
      } catch (e2) {
        final cached = await _getCachedItems(businessId);
        if (cached.isNotEmpty) return cached;
        _handleError(e2, 'Failed to fetch items: ');
      }
    }
  }

  Future<List<RecordModel>> getBottleItems(String businessId) async {
    await ensureAdminAuth();
    try {
      final result = await adminPb.collection('items').getList(
        filter: 'business_id = "$businessId" && item_type = "bottle"',
        sort: 'name',
      );
      return result.items;
    } catch (e) {
      print('❌ getBottleItems failed: $e');
      return [];
    }
  }

  Future<void> convertBottlesToShots({
    required String bottleItemId,
    required int bottleCount,
    required String shotItemId,
    required int shotsPerBottle,
  }) async {
    await ensureAdminAuth();

    final bottle = await adminPb.collection('items').getOne(bottleItemId);
    final currentBottleStock = bottle.getIntValue('stock_qty');
    if (currentBottleStock < bottleCount) {
      throw Exception('Not enough whole bottles in stock (available: $currentBottleStock)');
    }

    await adminPb.collection('items').update(bottleItemId, body: {
      'stock_qty': currentBottleStock - bottleCount,
    });

    final shot = await adminPb.collection('items').getOne(shotItemId);
    final currentShotStock = shot.getIntValue('stock_qty');
    final addedShots = bottleCount * shotsPerBottle;
    await adminPb.collection('items').update(shotItemId, body: {
      'stock_qty': currentShotStock + addedShots,
    });

    print('✅ Converted $bottleCount bottles → $addedShots shots');
  }

  Future<RecordModel> createItem(String businessId, Map<String, dynamic> data) async {
    await ensureAdminAuth();
    data['business_id'] = businessId;
    print('🔧 Creating item: businessId=$businessId, data=$data');
    try {
      final item = await adminPb.collection('items').create(body: data);
      print('✅ Item created successfully: ${item.id}');
      return item;
    } catch (e) {
      print('❌ Item creation failed: $e');
      rethrow;
    }
  }

  Future<RecordModel> updateItem(String itemId, Map<String, dynamic> data) async {
    await ensureAdminAuth();
    return await adminPb.collection('items').update(itemId, body: data);
  }

  Future<void> deleteItem(String itemId) async {
    await ensureAdminAuth();
    await adminPb.collection('items').delete(itemId);
  }

  Stream<List<RecordModel>> itemsStream(String businessId) {
    final controller = StreamController<List<RecordModel>>.broadcast();

    // Initial load
    getItems(businessId).then((items) {
      if (!controller.isClosed) controller.add(items);
    }).catchError((e) {
      print('itemsStream initial load error: $e');
    });

    // Realtime subscription (use normal client for now)
    if (_isInitialized) {
      try {
        pb.collection('items').subscribe('*', (e) {
          getItems(businessId).then((items) {
            if (!controller.isClosed) controller.add(items);
          }).catchError((err) {
            print('itemsStream subscribe error: $err');
          });
        }, filter: 'business_id = "$businessId"');
      } catch (e) {
        print('itemsStream subscribe setup error: $e');
      }
    }

    controller.onCancel = () {
      pb.collection('items').unsubscribe();
    };

    return controller.stream;
  }

  Future<void> _cacheItems(String businessId, List<RecordModel> items) async {
    if (!Hive.isBoxOpen('items_cache')) {
      print('PocketBaseService: items_cache box is not open; skipping cache');
      return;
    }
    final box = Hive.box('items_cache');
    final key = _itemCacheKey(businessId);
    final jsonList = items.map((item) => item.toJson()).toList();
    await box.put(key, jsonEncode(jsonList));
  }

  Future<List<RecordModel>> _getCachedItems(String businessId) async {
    if (!Hive.isBoxOpen('items_cache')) {
      print('PocketBaseService: items_cache box is not open; returning empty cache');
      return [];
    }
    final box = Hive.box('items_cache');
    final key = _itemCacheKey(businessId);
    final String? data = box.get(key);
    if (data == null) return [];

    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => RecordModel.fromJson(json)).toList();
  }

  Map<String, dynamic> buildCustomDataFromForm(Map<String, dynamic> formValues) {
    formValues.removeWhere((key, value) => value == null || value == '');
    return Map<String, dynamic>.from(formValues);
  }

  // ---------- Phase 3 – Cart & Sales (unchanged) ----------
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  String _normalizeItemId(String itemId) => itemId.trim();

  String _escapeFilterValue(String value) {
    return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  Future<RecordModel?> _findCachedItemByName(String businessId, String itemName) async {
    final normalizedName = itemName.trim();
    if (normalizedName.isEmpty) return null;

    final cachedItems = await _getCachedItems(businessId);
    if (cachedItems.isEmpty) return null;

    for (final record in cachedItems) {
      final recordName = record.getStringValue('name').trim();
      if (recordName == normalizedName) {
        return record;
      }
    }

    final lowerName = normalizedName.toLowerCase();
    for (final record in cachedItems) {
      final recordName = record.getStringValue('name').trim().toLowerCase();
      if (recordName == lowerName) {
        return record;
      }
    }

    return null;
  }

  Future<RecordModel> _resolveItemRecord(String businessId, String itemId, String itemName) async {
    final normalizedId = _normalizeItemId(itemId);
    if (normalizedId.isNotEmpty) {
      try {
        final record = await adminPb.collection('items').getOne(normalizedId, expand: '');
        print('✅ Resolved item by id: $normalizedId');
        return record;
      } catch (e) {
        print('⚠️ _resolveItemRecord by id failed: $normalizedId -> $e');
      }
    }

    final normalizedName = itemName.trim();
    if (normalizedName.isNotEmpty) {
      try {
        final escapedName = _escapeFilterValue(normalizedName);
        final list = await adminPb.collection('items').getList(
          filter: 'business_id = "$businessId" && name = "$escapedName"',
          perPage: 1,
        );
        if (list.items.isNotEmpty) {
          final record = list.items.first;
          print('✅ Resolved item by name: $normalizedName -> ${record.id}');
          return record;
        }
        print('⚠️ No item found by name: "$normalizedName" in business $businessId via admin query');
      } catch (e) {
        print('⚠️ _resolveItemRecord by name failed for "$normalizedName": $e');
      }

      final cachedRecord = await _findCachedItemByName(businessId, normalizedName);
      if (cachedRecord != null) {
        print('✅ Resolved item from cache by name: $normalizedName -> ${cachedRecord.id}');
        return cachedRecord;
      }
    }

    throw Exception('Could not resolve item record for "$itemName" ($itemId)');
  }

  // ==================== ROBUST STOCK OPERATIONS ====================

  Future<RecordModel> _resolveItem(String itemId, String itemName, String businessId) async {
    await ensureAdminAuth();

    if (itemId.isNotEmpty) {
      try {
        final record = await adminPb.collection('items').getOne(itemId);
        print('✅ Resolved by ID: $itemId');
        return record;
      } catch (_) {}
    }

    try {
      final escapedName = itemName.replaceAll('"', '\\"');
      final result = await adminPb.collection('items').getList(
        filter: 'business_id = "$businessId" && name = "$escapedName"',
        perPage: 1,
      );
      if (result.items.isNotEmpty) {
        print('✅ Resolved by name: $itemName → ${result.items.first.id}');
        return result.items.first;
      }
    } catch (e) {
      print('❌ Name resolution failed: $e');
    }

    throw Exception('Item not found: $itemName');
  }

  Future<int> getCurrentStock(String itemId, String itemName, String businessId) async {
    final record = await _resolveItem(itemId, itemName, businessId);
    final stock = record.getIntValue('stock_qty') ?? 0;
    print('📊 Current stock for $itemName: $stock');
    return stock;
  }

  Future<bool> deductStock(String itemId, String itemName, String businessId, int quantity) async {
    await ensureAdminAuth();

    try {
      final record = await _resolveItem(itemId, itemName, businessId);
      final current = record.getIntValue('stock_qty') ?? 0;

      if (current < quantity) {
        print('❌ Insufficient stock for $itemName');
        return false;
      }

      final newStock = current - quantity;
      await adminPb.collection('items').update(record.id, body: {'stock_qty': newStock});

      print('✅ Deducted $quantity of $itemName (new stock: $newStock)');
      return true;
    } catch (e) {
      print('❌ deductStock failed for $itemName: $e');
      return false;
    }
  }

  Future<void> checkStockForItems(String businessId, List<Map<String, dynamic>> items) async {
    for (final item in items) {
      final itemId = item['item_id'] as String? ?? '';
      final itemName = item['name'] as String? ?? '';
      final qty = item['quantity'] as int;
      final record = await _resolveItemRecord(businessId, itemId, itemName);
      final stock = record.getIntValue('stock_qty') ?? 0;
      if (stock < qty) {
        throw Exception('Insufficient stock for $itemName (stock: $stock, requested: $qty)');
      }
    }
  }

  String generateReceiptNo() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'RCPT-$timestamp-$random';
  }

  Future<RecordModel> createSale({
    required String businessId,
    required String userId,
    required String userEmail,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String? paymentReference,
    required String receiptNo,
  }) async {
    await ensureAdminAuth();

    final resolvedItems = <Map<String, dynamic>>[];
    for (final item in items) {
      final itemId = item['item_id'] as String? ?? '';
      final itemName = item['name'] as String? ?? '';
      final record = await _resolveItemRecord(businessId, itemId, itemName);
      final resolvedName = record.getStringValue('name').trim();
      resolvedItems.add({
        ...item,
        'item_id': record.id,
        'name': resolvedName,
      });
    }

    try {
      await checkStockForItems(businessId, resolvedItems);
    } catch (e) {
      print('❌ Sale creation failed during stock check: $e');
      rethrow;
    }

    // Deduct stock
    for (final item in items) {
      final itemId = item['item_id'] as String? ?? '';
      final itemName = item['name'] as String? ?? 'Unknown';
      final qty = item['quantity'] as int;

      final success = await deductStock(itemId, itemName, businessId, qty);
      if (!success) {
        throw Exception('Stock deduction failed for $itemName');
      }
    }

    final saleData = {
      'business_id': businessId,
      'user': userId,
      'user_email': userEmail,
      'items': resolvedItems,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'receipt_no': receiptNo,
    };
    if (paymentReference != null && paymentReference.trim().isNotEmpty) {
      saleData['payment_reference'] = paymentReference;
    }

    try {
      final sale = await adminPb.collection('sales').create(body: saleData);
      print('✅ Sale created successfully: $receiptNo');

      // Auto log sale for audit trail (uses adminPb as well)
      await logAuditAction(
        userId: userId,
        userEmail: userEmail,
        action: 'sale_completed',
        details: {
          'receipt_no': receiptNo,
          'total_amount': totalAmount,
          'payment_method': paymentMethod,
          'items_count': items.length,
          'payment_reference': paymentReference ?? 'N/A',
        },
      );
      return sale;
    } catch (e) {
      print('❌ Sale creation failed: $e');
      rethrow;
    }
  }

  Future<void> queueSale({
    required String businessId,
    required String userId,
    required String userEmail,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required String paymentMethod,
    String? paymentReference,
    required String receiptNo,
  }) async {
    if (!Hive.isBoxOpen('pending_sales')) {
      await Hive.openBox('pending_sales');
    }
    final box = Hive.box('pending_sales');
    final pendingData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'businessId': businessId,
      'userId': userId,
      'userEmail': userEmail,
      'items': items,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'paymentReference': paymentReference,
      'receiptNo': receiptNo,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await box.add(pendingData);
  }

  Future<void> syncPendingSalesForUser(String businessId, String userId) async {
    if (!Hive.isBoxOpen('pending_sales')) return;
    final box = Hive.box('pending_sales');
    final pendingList = box.values.where((sale) {
      return sale['businessId'] == businessId && sale['userId'] == userId;
    }).toList();

    if (pendingList.isEmpty) return;

    for (final pending in pendingList) {
      try {
        if (!await isOnline()) continue;

        // Re-validate items for expiry before syncing (pharmacy only)
        final itemsRaw = (pending['items'] as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
        bool expiredFound = false;

        // Get business category from auth box
        final boxAuth = Hive.box('auth');
        final businessCategory = boxAuth.get('businessCategory');
        
        if (businessCategory?.toString().toLowerCase() == 'pharmacy') {
          for (final saleItem in itemsRaw) {
            final itemId = saleItem['item_id'] as String?;
            if (itemId == null) continue;
            try {
              final itemRecord = await adminPb.collection('items').getOne(itemId);
              final customData = itemRecord.data['custom_data'] as Map<String, dynamic>?;
              if (customData != null) {
                final expiryRaw = customData['expiry_date'];
                if (expiryRaw != null) {
                  DateTime? expiryDate;
                  if (expiryRaw is String) expiryDate = DateTime.tryParse(expiryRaw);
                  else if (expiryRaw is DateTime) expiryDate = expiryRaw;
                  if (expiryDate != null && expiryDate.isBefore(DateTime.now())) {
                    expiredFound = true;
                    print('⚠️ Expired item detected during sync: ${saleItem['name']}');
                    break;
                  }
                }
              }
            } catch (e) {
              print('⚠️ Could not verify expiry for item $itemId during sync: $e');
            }
          }
        }

        if (expiredFound) {
          // Mark the pending sale as having expired items and skip
          pending['sync_error'] = 'Expired items detected';
          await box.put(pending.key, pending); // update record
          print('⚠️ Sync skipped for sale ${pending['receiptNo']}: expired items');
          continue;
        }

        final itemsForSale = itemsRaw.map((item) {
          return {
            'item_id': item['item_id'],
            'name': item['name'],
            'quantity': item['quantity'],
            'price': item['price'],
          };
        }).toList();

        await createSale(
          businessId: pending['businessId'],
          userId: pending['userId'],
          userEmail: pending['userEmail'],
          items: itemsForSale,
          totalAmount: pending['totalAmount'],
          paymentMethod: pending['paymentMethod'],
          paymentReference: pending['paymentReference'],
          receiptNo: pending['receiptNo'],
        );

        await pending.delete();
      } catch (e) {
        print('❌ Failed to sync pending sale ${pending['receiptNo']}: $e');
      }
    }
  }

  // ==================== PHASE 4: STAFF, AUDIT, LICENSE ====================

  // ---- Staff Management ----
  Future<String> createStaff({
    required String email,
    required String businessId,
  }) async {
    await ensureAdminAuth();
    final password = generateRandomPassword();

    print('🔧 Creating staff: email=$email, businessId=$businessId, password=$password');
    try {
      await adminPb.collection('user').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'role': 'staff',
        'business_id': businessId,
      });
      print('✅ Staff created successfully');
    } catch (e) {
      print('❌ Staff creation failed: $e');
      rethrow;
    }

    return password;
  }

  Future<List<RecordModel>> getStaffList(String businessId) async {
    if (!_isInitialized) _init();

    await ensureAdminAuth();   // ← Use superuser

    try {
      final result = await adminPb.collection('user').getList(
        filter: 'business_id = "$businessId" && role = "staff"',
        sort: '-created',
      );
      return result.items;
    } catch (e) {
      print('❌ getStaffList failed: $e');
      rethrow;
    }
  }

  // ---- Audit Logs ----
  Future<void> logAuditAction({
    required String userId,
    required String userEmail,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    if (!_isInitialized) _init();

    final currentUser = pb.authStore.model;
    if (currentUser == null) {
      print('⚠️ Skipping audit log: No authenticated user');
      return;
    }

    final businessId = currentUser.getStringValue('business_id');
    if (businessId.isEmpty) {
      print('⚠️ Skipping audit log: No business_id');
      return;
    }

    try {
      await adminPb.collection('audit_logs').create(body: {
        'business_id': businessId,
        'user': userId,           // Important: field name is "user"
        'user_email': userEmail,
        'action': action,
        'details': details ?? {},
      });
      print('✅ Audit log created: $action');
    } catch (e) {
      print('❌ Failed to log audit action: $e');
    }
  }

  Future<List<RecordModel>> getAuditLogs(String businessId) async {
    if (!_isInitialized) _init();

    await ensureAdminAuth();   // ← Must use superuser

    try {
      final result = await adminPb.collection('audit_logs').getList(
        filter: 'business_id = "$businessId"',
        sort: '-created',
        perPage: 50,
      );
      print('✅ Loaded ${result.items.length} audit logs');
      return result.items;
    } catch (e) {
      print('❌ getAuditLogs failed: $e');
      return [];   // Return empty list instead of crashing
    }
  }

  // ---- Admin Dashboard Methods ----
  Future<Map<String, dynamic>> getTodaySalesData(String businessId) async {
    await ensureAdminAuth();
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();

      final result = await adminPb.collection('sales').getList(
        filter: 'business_id = "$businessId" && created >= "$startOfDay" && created < "$endOfDay"',
        sort: '-created',
      );

      double totalSales = 0;
      for (final sale in result.items) {
        totalSales += sale.getDoubleValue('total_amount');
      }

      print('📊 getTodaySalesData: total=$totalSales, count=${result.items.length}');
      return {
        'total': totalSales,
        'count': result.items.length,
        'sales': result.items,
      };
    } catch (e) {
      print('❌ getTodaySalesData failed: $e');
      return {'total': 0.0, 'count': 0, 'sales': []};
    }
  }

  Future<List<RecordModel>> getLowStockItems(String businessId) async {
    await ensureAdminAuth();
    try {
      final result = await adminPb.collection('items').getList(
        filter: 'business_id = "$businessId" && stock_qty <= 10',
        sort: 'stock_qty',
      );
      return result.items;
    } catch (e) {
      print('❌ getLowStockItems failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getMonthlySalesData(String businessId, int year, int month) async {
    await ensureAdminAuth();
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 1);

      final result = await adminPb.collection('sales').getList(
        filter: 'business_id = "$businessId" && created >= "${startOfMonth.toUtc().toIso8601String()}" && created < "${endOfMonth.toUtc().toIso8601String()}"',
        sort: '-created',
      );

      double totalSales = 0;
      int totalTransactions = result.items.length;
      Map<String, double> dailySales = {};

      for (final sale in result.items) {
        totalSales += sale.getDoubleValue('total_amount');
        final saleDate = DateTime.parse(sale.created).toLocal();
        final dayKey = '${saleDate.year}-${saleDate.month.toString().padLeft(2, '0')}-${saleDate.day.toString().padLeft(2, '0')}';
        dailySales[dayKey] = (dailySales[dayKey] ?? 0) + sale.getDoubleValue('total_amount');
      }

      return {
        'total': totalSales,
        'count': totalTransactions,
        'total_sales': totalSales,
        'total_transactions': totalTransactions,
        'daily_sales': dailySales,
        'sales': result.items,
      };
    } catch (e) {
      print('❌ getMonthlySalesData failed: $e');
      return {'total': 0.0, 'count': 0, 'total_sales': 0.0, 'total_transactions': 0, 'daily_sales': {}, 'sales': []};
    }
  }

  Future<Map<String, dynamic>> getSalesByPaymentMethod(String businessId, DateTime startDate, DateTime endDate) async {
    await ensureAdminAuth();
    try {
      final result = await adminPb.collection('sales').getList(
        filter: 'business_id = "$businessId" && created >= "${startDate.toIso8601String()}" && created < "${endDate.toIso8601String()}"',
        sort: '-created',
      );

      Map<String, double> paymentMethodTotals = {};
      Map<String, int> paymentMethodCounts = {};

      for (final sale in result.items) {
        final method = sale.getStringValue('payment_method');
        final amount = sale.getDoubleValue('total_amount');

        paymentMethodTotals[method] = (paymentMethodTotals[method] ?? 0) + amount;
        paymentMethodCounts[method] = (paymentMethodCounts[method] ?? 0) + 1;
      }

      return {
        'totals': paymentMethodTotals,
        'counts': paymentMethodCounts,
        'sales': result.items,
      };
    } catch (e) {
      print('❌ getSalesByPaymentMethod failed: $e');
      return {'totals': {}, 'counts': {}, 'sales': []};
    }
  }

  // ---- Additional Admin Dashboard Methods ----
  Future<Map<String, dynamic>> getMonthSalesData(String businessId, int year, int month) async {
    await ensureAdminAuth();
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 1);

      final result = await adminPb.collection('sales').getList(
        filter: 'business_id = "$businessId" && created >= "${startOfMonth.toUtc().toIso8601String()}" && created < "${endOfMonth.toUtc().toIso8601String()}"',
        sort: '-created',
      );

      double totalSales = 0;
      int totalTransactions = result.items.length;

      for (final sale in result.items) {
        totalSales += sale.getDoubleValue('total_amount');
      }

      return {
        'total': totalSales,
        'count': totalTransactions,
      };
    } catch (e) {
      print('❌ getMonthSalesData failed: $e');
      return {'total': 0.0, 'count': 0};
    }
  }

  Future<int> getStaffCount(String businessId) async {
    await ensureAdminAuth();
    try {
      final result = await adminPb.collection('user').getList(
        filter: 'business_id = "$businessId" && role = "staff"',
        perPage: 1,
      );
      return result.totalItems;
    } catch (e) {
      print('❌ getStaffCount failed: $e');
      return 0;
    }
  }

  Future<List<RecordModel>> getRecentSales(String businessId, {int limit = 10}) async {
    await ensureAdminAuth();
    try {
      final result = await adminPb.collection('sales').getList(
        filter: 'business_id = "$businessId"',
        sort: '-created',
        perPage: limit,
      );
      return result.items;
    } catch (e) {
      print('❌ getRecentSales failed: $e');
      return [];
    }
  }

  // ---- License / Offline Kill-Switch ----
  Future<Map<String, dynamic>> getBusinessLicense(String businessId) async {
    if (!_isInitialized) _init();
    try {
      final business = await pb.collection('businesses').getOne(businessId);
      final trialEndStr = business.getStringValue('trial_end');
      DateTime? trialEnd;
      if (trialEndStr.isNotEmpty) {
        trialEnd = DateTime.tryParse(trialEndStr);
      }
      return {
        'trial_end': trialEnd,
        'subscription_active': business.getBoolValue('subscription_active'),
      };
    } catch (e) {
      print('Failed to fetch license info: $e');
      // Return a default license (30 days trial) to avoid blocking the user
      return {
        'trial_end': DateTime.now().add(const Duration(days: 30)),
        'subscription_active': true,
      };
    }
  }

  // ---- Pharmacy Expiry Tracking ----
  Future<List<RecordModel>> getExpiringSoonItems(String businessId, int daysThreshold) async {
    await ensureAdminAuth();
    try {
      final result = await adminPb.collection('items').getList(
        filter: 'business_id = "$businessId"',
        sort: 'name',
        perPage: 500,
      );

      final now = DateTime.now();
      final thresholdDate = now.add(Duration(days: daysThreshold));
      final expiringItems = <RecordModel>[];

      for (final item in result.items) {
        final customData = item.data['custom_data'] as Map<String, dynamic>?;
        if (customData == null) continue;
        final expiryRaw = customData['expiry_date'];
        if (expiryRaw == null) continue;

        DateTime? expiryDate;
        if (expiryRaw is String) expiryDate = DateTime.tryParse(expiryRaw);
        else if (expiryRaw is DateTime) expiryDate = expiryRaw;
        if (expiryDate == null) continue;

        final expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
        final today = DateTime(now.year, now.month, now.day);
        
        // Already expired? Skip (we want only expiring_soon, not expired)
        if (expiryDay.isBefore(today)) continue;
        
        // Beyond threshold? Skip
        if (expiryDay.isAfter(thresholdDate)) continue;

        expiringItems.add(item);
      }

      print('✅ Found ${expiringItems.length} items expiring within $daysThreshold days');
      return expiringItems;
    } catch (e) {
      print('❌ getExpiringSoonItems failed: $e');
      return [];
    }
  }

  String getExpiryStatus(RecordModel item) {
    final customData = item.data['custom_data'] as Map<String, dynamic>?;
    if (customData == null) return 'ok';
    final expiryRaw = customData['expiry_date'];
    if (expiryRaw == null) return 'ok';

    DateTime? expiryDate;
    if (expiryRaw is String) expiryDate = DateTime.tryParse(expiryRaw);
    else if (expiryRaw is DateTime) expiryDate = expiryRaw;
    if (expiryDate == null) return 'ok';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    
    if (expiryDay.isBefore(today)) return 'expired';
    if (expiryDay.difference(today).inDays <= 30) return 'expiring_soon';
    return 'ok';
  }

  bool isItemExpired(RecordModel item) => getExpiryStatus(item) == 'expired';

  /*
  // ---- Attendance (enhanced with business_id) ----
  Future<RecordModel?> getCurrentCheckin(String userId, String businessId) async {
    if (!_isInitialized) _init();
    try {
      final result = await pb.collection('attendance').getList(
        filter: 'user_id = "$userId" && business_id = "$businessId"',
        sort: '-checkin_time',
        perPage: 10, // fetch last few to find active shift
      );
      // Find the latest record with checkout_time == null (i.e., not clocked out)
      for (final record in result.items) {
        final checkoutRaw = record.data['checkout_time'];
        final checkoutTime = checkoutRaw is String
            ? (checkoutRaw.isEmpty ? null : DateTime.tryParse(checkoutRaw))
            : (checkoutRaw is DateTime ? checkoutRaw : null);
        if (checkoutTime == null) {
          return record;
        }
      }
      return null;
    } catch (e) {
      print('getCurrentCheckin error: $e');
      return null;
    }
  }

  Future<RecordModel> clockIn(String userId, String businessId) async {
    if (!_isInitialized) _init();
    try {
      final existing = await getCurrentCheckin(userId, businessId);
      if (existing != null) throw Exception('Already clocked in');
      final record = await pb.collection('attendance').create(body: {
        'user_id': userId,
        'business_id': businessId,
        'checkin_time': DateTime.now().toIso8601String(),
      });
      return record;
    } catch (e) {
      _handleError(e, 'Clock in failed: ');
    }
  }

  Future<RecordModel> clockOut(String userId, String businessId) async {
    if (!_isInitialized) _init();
    try {
      final checkin = await getCurrentCheckin(userId, businessId);
      if (checkin == null) throw Exception('Not clocked in');
      final updated = await pb.collection('attendance').update(checkin.id, body: {
        'checkout_time': DateTime.now().toIso8601String(),
      });
      return updated;
    } catch (e) {
      _handleError(e, 'Clock out failed: ');
    }
  }

  Future<List<RecordModel>> getAttendanceLogs(String businessId) async {
    if (!_isInitialized) _init();
    try {
      final result = await pb.collection('attendance').getList(
        filter: 'business_id = "$businessId"',
        sort: '-checkin_time',
      );
      return result.items;
    } catch (e) {
      _handleError(e, 'Fetch attendance logs failed: ');
    }
  }
  */

  // Business logo and profile methods
  Future<void> updateBusinessLogo(String businessId, String filePath) async {
    await ensureAdminAuth();
    // Short delay to ensure the business record is fully committed
    await Future.delayed(const Duration(milliseconds: 500));
    // Ensure the record exists
    await adminPb.collection('businesses').getOne(businessId);
    final file = await MultipartFile.fromPath('logo', filePath);
    await adminPb.collection('businesses').update(
      businessId,
      files: [file],   // ✅ Must be a List for SDK v0.18.1
    );
    print('✅ Logo uploaded for business $businessId');
  }

  Future<Map<String, dynamic>> getBusinessFull(String businessId) async {
    await ensureAdminAuth();
    final business = await adminPb.collection('businesses').getOne(businessId);
    final logoFilename = business.getStringValue('logo');
    return {
      'id': business.id,
      'business_name': business.getStringValue('business_name'),
      'phone': business.getStringValue('phone') ?? '',
      'address': business.getStringValue('address') ?? '',
      'email': business.getStringValue('email') ?? '',
      'country': business.getStringValue('country'),
      'currency_code': business.getStringValue('currency_code'),
      'logo_url': logoFilename.isNotEmpty
          ? adminPb.buildUrl('/api/files/businesses/${business.id}/$logoFilename').toString()
          : null,
    };
  }

  Future<void> updateBusinessProfile(String businessId, Map<String, dynamic> data) async {
    await ensureAdminAuth();
    await adminPb.collection('businesses').update(businessId, body: data);
  }

  // Add password reset for staff
  Future<String> resetStaffPassword(String email, String businessId) async {
    await ensureAdminAuth();
    print('resetStaffPassword: email="$email" businessId=$businessId');

    // Fetch staff by exact email (case-sensitive)
    var result = await adminPb.collection('user').getList(
      filter: 'email = "$email" && business_id = "$businessId" && role = "staff"',
      perPage: 1,
    );
    if (result.items.isNotEmpty) {
      final staff = result.items.first;
      final staffEmail = staff.data['email']?.toString() ?? '';
      print('✅ Exact match: $staffEmail');
      final newPassword = generateRandomPassword();
      await adminPb.collection('user').update(staff.id, body: {
        'password': newPassword,
        'passwordConfirm': newPassword,
      });
      return newPassword;
    }

    // Fallback: case-insensitive search
    result = await adminPb.collection('user').getList(
      filter: 'business_id = "$businessId" && role = "staff"',
      perPage: 100,
    );
    final staff = result.items.firstWhere(
      (u) => (u.data['email']?.toString() ?? '').toLowerCase() == email.toLowerCase(),
      orElse: () => throw Exception('Staff not found with email: $email'),
    );
    print('✅ Fallback match: ${staff.data['email']}');
    final newPassword = generateRandomPassword();
    await adminPb.collection('user').update(staff.id, body: {
      'password': newPassword,
      'passwordConfirm': newPassword,
    });
    return newPassword;
  }

  // ---- Subscription Management ----
  Future<void> activateSubscription(String businessId, String transactionRef) async {
    await ensureAdminAuth();
    final newTrialEnd = DateTime.now().add(const Duration(days: 30));
    await adminPb.collection('businesses').update(businessId, body: {
      'subscription_active': true,
      'trial_end': newTrialEnd.toIso8601String(),
      'paystack_transaction_ref': transactionRef,
    });
    print('✅ Subscription activated for business $businessId until $newTrialEnd');
  }

  // ---- Helper Methods ----
  String generateTransactionReference() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(100000);
    return 'txn_$timestamp$random';
  }
}