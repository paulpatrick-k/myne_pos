import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';

class BusinessRegistrationScreen extends StatefulWidget {
  const BusinessRegistrationScreen({super.key});

  @override
  State<BusinessRegistrationScreen> createState() =>
      _BusinessRegistrationScreenState();
}

class _BusinessRegistrationScreenState
    extends State<BusinessRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedCategory;
  String? _country;
  String? _currencyCode;
  File? _logoFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _selectedCategory == null) {
      _selectedCategory = args['category'] as String?;
      _country = args['country'] as String?;
      _currencyCode = args['currencyCode'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _logoFile = File(picked.path));
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) return;

    setState(() => _isLoading = true);

    if (_country == null || _currencyCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Country and currency selection required.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final pbService = PocketBaseService();
    try {
      final result = await pbService.createBusinessAndAdmin(
        businessName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        category: _selectedCategory!,
        country: _country!,
        currencyCode: _currencyCode!,
      );

      final businessId = result['businessId']!;

      // Upload logo now that business exists
      if (_logoFile != null) {
        // Retry up to 3 times
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            await pbService.updateBusinessLogo(businessId, _logoFile!.path);
            break; // success
          } catch (e) {
            print('Logo upload attempt $attempt failed: $e');
            if (attempt == 3) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Business created but logo upload failed. You can upload it later.')),
              );
            }
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
        }
      }

      if (!mounted) return;

      // SHOW CREDENTIALS FIRST
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Business Created Successfully!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please save these credentials:'),
              const SizedBox(height: 12),
              Text('Business Code: ${result['businessCode']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Admin Email: ${_emailController.text.trim()}'),
              Text('Admin Password: ${result['adminPassword']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 12),
              const Text('You will need this password to log in and change it later.', style: TextStyle(color: Colors.red)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Now auto login
                _autoLogin(result);
              },
              child: const Text('I have saved them → Login'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autoLogin(Map<String, String> result) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      businessCode: result['businessCode']!,
      email: _emailController.text.trim(),
      password: result['adminPassword']!,
    );

    if (success && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Your Business')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_selectedCategory != null)
                Text('Category: $_selectedCategory',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
              ),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.image),
                label: Text(_logoFile == null ? 'Upload Business Logo' : 'Change Logo'),
              ),
              if (_logoFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Image.file(_logoFile!, height: 80),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Business'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}