import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../../core/data/country_data.dart';
import '../../core/services/pocketbase_service.dart';

class AuthProvider extends ChangeNotifier {
  final PocketBaseService pbService;
  bool _isLoading = false;
  String? _error;
  String? _businessCode;
  String? _businessId;
  String? _userId;
  String? _role;
  String? _businessCategory;
  String? _currencyCode;
  String? _currencySymbol;

  // Business profile fields
  String? _businessName;
  String? _businessPhone;
  String? _businessAddress;
  String? _businessEmail;
  String? _businessLogoUrl;

  // License expiry cache (offline kill-switch)
  DateTime? _licenseExpiry;
  bool _subscriptionActive = false;

  String? get currencyCode => _currencyCode;
  String? get currencySymbol => _currencySymbol;

  // Business profile getters
  String? get businessName => _businessName;
  String? get businessPhone => _businessPhone;
  String? get businessAddress => _businessAddress;
  String? get businessEmail => _businessEmail;
  String? get businessLogoUrl => _businessLogoUrl;

  bool get _hasAuthBox => Hive.isBoxOpen('auth');

  AuthProvider(this.pbService) {
    loadUserFromStorage();
    loadLicenseFromStorage(); // load cached expiry
    Connectivity().onConnectivityChanged.listen((event) async {
      final online = await PocketBaseService().isOnline();
      if (online && _businessId != null) {
        await refreshLicenseFromServer();
        await syncPendingSales();
      }
    });
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get businessCode => _businessCode;
  String? get businessId => _businessId;
  String? get userId => _userId;
  String? get userEmail => pbService.currentUserEmail;
  String? get role => _role;
  String? get businessCategory => _businessCategory;
  bool get isLoggedIn => pbService.isLoggedIn;

  /// Returns true if the license is expired (offline check)
  /// Checks both subscription_active flag AND trial_end date
  bool isLicenseExpired() {
    if (_licenseExpiry == null) return false; // no expiry = allowed
    return DateTime.now().isAfter(_licenseExpiry!);
  }

  Future<void> loadUserFromStorage() async {
    if (!_hasAuthBox) {
      print('AuthProvider: auth box not open; skipping loadUserFromStorage');
      return;
    }
    final box = Hive.box('auth');
    _businessCode = box.get('businessCode');
    _businessId = box.get('businessId');
    _userId = box.get('userId');
    _role = box.get('role');
    _businessCategory = box.get('businessCategory');
    _currencyCode = box.get('currencyCode');
    _currencySymbol = box.get('currencySymbol');
    _businessName = box.get('businessName');
    _businessPhone = box.get('businessPhone');
    _businessAddress = box.get('businessAddress');
    _businessEmail = box.get('businessEmail');
    _businessLogoUrl = box.get('businessLogoUrl');
    notifyListeners();
  }

  void loadLicenseFromStorage() {
    if (!_hasAuthBox) return;
    final box = Hive.box('auth');
    final expiryStr = box.get('license_expiry');
    if (expiryStr != null && expiryStr is String) {
      _licenseExpiry = DateTime.tryParse(expiryStr);
    } else {
      _licenseExpiry = null;
    }
    _subscriptionActive = box.get('subscription_active') ?? false;
  }

  Future<void> refreshLicenseFromServer() async {
    if (_businessId == null) return;
    try {
      final license = await pbService.getBusinessLicense(_businessId!);
      // license['trial_end'] may be DateTime? or String
      dynamic expiryValue = license['trial_end'];
      if (expiryValue is DateTime) {
        _licenseExpiry = expiryValue;
      } else if (expiryValue is String) {
        _licenseExpiry = DateTime.tryParse(expiryValue);
      } else {
        _licenseExpiry = null;
      }
      _subscriptionActive = license['subscription_active'] as bool? ?? false;

      // If still null, assume not expired (or set a default future date)
      if (_licenseExpiry == null) {
        _licenseExpiry = DateTime.now().add(const Duration(days: 30));
        print('⚠️ License expiry missing, assuming 30 days trial');
      }

      if (_hasAuthBox) {
        final box = Hive.box('auth');
        await box.put('license_expiry', _licenseExpiry?.toIso8601String());
        await box.put('subscription_active', _subscriptionActive);
      }
      notifyListeners();
    } catch (e) {
      print('Failed to refresh license: $e');
    }
  }

  Future<bool> login({
    required String businessCode,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await pbService.login(
        businessCode: businessCode,
        email: email,
        password: password,
      );

      _businessCode = result['businessCode'];
      _businessId = result['businessId'];
      _userId = result['userId'];
      _role = result['role'];
      _businessCategory = result['businessCategory'];

      print('AuthProvider.login success: businessId=$_businessId userId=$_userId role=$_role businessCode=$_businessCode');

      // ---- NEW: fetch business record for currency info
      try {
        await pbService.ensureAdminAuth();
        final business = await pbService.adminPb.collection('businesses').getOne(_businessId!);
        _currencyCode = business.getStringValue('currency_code');
        final businessCountry = business.getStringValue('country');
        _currencySymbol = _getCurrencySymbolFromBusiness(businessCountry, _currencyCode);

        // Load business profile details
        _businessName = business.getStringValue('business_name');
        _businessPhone = business.getStringValue('phone');
        _businessAddress = business.getStringValue('address');
        _businessEmail = business.getStringValue('email'); // optional, ensure you have this in businesses schema
        final logoFilename = business.getStringValue('logo');
        if (logoFilename.isNotEmpty) {
          _businessLogoUrl = pbService.adminPb.buildUrl('/api/files/businesses/$_businessId/$logoFilename').toString();
        } else {
          _businessLogoUrl = null;
        }
      } catch (e) {
        print('Failed to load currency info: $e');
        _currencyCode ??= 'KES';
        _currencySymbol ??= _getCurrencySymbolFromBusiness(null, _currencyCode);
      }

      // Fetch and cache license expiry
      await refreshLicenseFromServer();

      if (_hasAuthBox) {
        final box = Hive.box('auth');
        await box.put('businessCode', _businessCode);
        await box.put('businessId', _businessId);
        await box.put('userId', _userId);
        await box.put('role', _role);
        await box.put('businessCategory', _businessCategory);
        await box.put('currencyCode', _currencyCode);
        await box.put('currencySymbol', _currencySymbol);
        await box.put('businessName', _businessName);
        await box.put('businessPhone', _businessPhone);
        await box.put('businessAddress', _businessAddress);
        await box.put('businessEmail', _businessEmail);
        await box.put('businessLogoUrl', _businessLogoUrl);
      }

      await syncPendingSales();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _getCurrencySymbolFromBusiness(String? country, String? currencyCode) {
    if (country != null && country.isNotEmpty) {
      final symbol = CountryData.getCurrencySymbol(country);
      if (symbol != '\u00024' || currencyCode == 'USD') {
        return symbol;
      }
    }

    if (currencyCode != null && currencyCode.isNotEmpty) {
      final currency = CountryData.countries.firstWhere(
        (c) => c['currency'] == currencyCode,
        orElse: () => {'symbol': currencyCode},
      );
      return currency['symbol']!;
    }

    return 'KSh';
  }

  String formatPrice(double amount) {
    final symbol = _currencySymbol ?? _currencyCode ?? 'KES';
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '${formatter.format(amount)} $symbol';
  }

  Future<void> syncPendingSales() async {
    if (_businessId != null && _userId != null) {
      await PocketBaseService().syncPendingSalesForUser(_businessId!, _userId!);
    }
  }

  Future<void> refreshBusinessDetails() async {
    if (_businessId == null) return;
    final pbService = PocketBaseService();
    final data = await pbService.getBusinessFull(_businessId!);
    _businessName = data['business_name'];
    _businessPhone = data['phone'];
    _businessAddress = data['address'];
    _businessEmail = data['email'];
    _businessLogoUrl = data['logo_url'] as String?;
    if (_hasAuthBox) {
      final box = Hive.box('auth');
      await box.put('businessName', _businessName);
      await box.put('businessPhone', _businessPhone);
      await box.put('businessAddress', _businessAddress);
      await box.put('businessEmail', _businessEmail);
      await box.put('businessLogoUrl', _businessLogoUrl);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    pbService.logout();
    _businessCode = null;
    _businessId = null;
    _userId = null;
    _role = null;
    _businessCategory = null;
    _licenseExpiry = null;
    _subscriptionActive = false;
    _businessName = null;
    _businessPhone = null;
    _businessAddress = null;
    _businessEmail = null;
    _businessLogoUrl = null;

    if (_hasAuthBox) {
      final box = Hive.box('auth');
      await box.clear();
    }

    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}