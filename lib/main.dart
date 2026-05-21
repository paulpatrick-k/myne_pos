import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/services/pocketbase_service.dart';
import 'shared/providers/auth_provider.dart';
import 'features/auth/welcome_screen.dart';
import 'features/auth/category_selection_screen.dart';
import 'features/auth/country_selection_screen.dart';
import 'features/auth/business_registration_screen.dart';
import 'features/auth/business_login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/cart/cart_provider.dart';
import 'features/cart/cart_screen.dart';
import 'features/subscription/paywall_screen.dart';

Future<void> _migrateBusinessesWithDefaults() async {
  final pbService = PocketBaseService();
  try {
    await pbService.ensureAdminAuth();
    final businesses = await pbService.adminPb.collection('businesses').getFullList();
    for (final business in businesses) {
      final country = business.getStringValue('country');
      final currency = business.getStringValue('currency_code');
      final updates = <String, dynamic>{};
      if (country.isEmpty) updates['country'] = 'Kenya';
      if (currency.isEmpty) updates['currency_code'] = 'KES';
      if (updates.isNotEmpty) {
        await pbService.adminPb.collection('businesses').update(business.id, body: updates);
        print('Migrated business ${business.id} with default country/currency');
      }
    }
  } catch (e) {
    print('Business migration failed: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env from assets (bundled in APK)
  await dotenv.load();
  print('Loaded .env from assets: POCKETBASE_URL = ${dotenv.env['POCKETBASE_URL']}');

  final appSupportDirectory = await getApplicationSupportDirectory();
  final hiveStorageDirectory = Directory(
    '${appSupportDirectory.path}${Platform.pathSeparator}myne_pos_hive',
  );
  if (!await hiveStorageDirectory.exists()) {
    await hiveStorageDirectory.create(recursive: true);
  }

  final hiveStoragePath = hiveStorageDirectory.path;
  await Hive.initFlutter(hiveStoragePath);

  // No adapter needed for pending sales as we use raw maps

  Future<Box?> openHiveBoxSafely(String name) async {
    try {
      return await Hive.openBox(name);
    } catch (error) {
      print('Warning: Could not open $name box: $error');
      final lockFile = File('$hiveStoragePath${Platform.pathSeparator}$name.lock');
      if (await lockFile.exists()) {
        try {
          await lockFile.delete();
          print('Deleted stale Hive lock file: ${lockFile.path}');
        } catch (deleteError) {
          print('Could not delete stale Hive lock file ${lockFile.path}: $deleteError');
        }
      }
      try {
        return await Hive.openBox(name);
      } catch (secondError) {
        print('Warning: Could not reopen $name box: $secondError');
        return null;
      }
    }
  }

  await openHiveBoxSafely('auth');
  await openHiveBoxSafely('items_cache');
  await Hive.openBox('pending_sales');

  // Initialise the singleton PocketBaseService (triggers internal init lazily)
  PocketBaseService();
  await _migrateBusinessesWithDefaults();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(PocketBaseService())..loadUserFromStorage(),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const MyApp(),
    ),
  );

  final pbService = PocketBaseService();
  final connectivity = Connectivity();
  connectivity.onConnectivityChanged.listen((event) async {
    final isOnline = await pbService.isOnline();
    if (isOnline) {
      print('Connectivity restored; pending sales sync is delegated to AuthProvider.');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MYNE POS',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WelcomeScreen(),
      routes: {
        '/category': (context) => const CategorySelectionScreen(),
        '/select-country': (context) => const CountrySelectionScreen(),
        '/register': (context) => const BusinessRegistrationScreen(),
        '/login': (context) => const BusinessLoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/cart': (context) => const CartScreen(),
        '/paywall': (context) => const PaywallScreen(),
      },
    );
  }
}