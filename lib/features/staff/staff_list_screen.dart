import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final _emailController = TextEditingController();
  List<dynamic> _staff = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.businessId == null) return;
    setState(() => _loading = true);
    try {
      final staff = await PocketBaseService().getStaffList(auth.businessId!);
      setState(() {
        _staff = staff;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addStaff() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valid email required')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final password = await PocketBaseService().createStaff(
        email: email,
        businessId: auth.businessId!,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Staff Created'),
          content: Text('Email: $email\nPassword: $password\n\nPlease share this password with the staff member. It will not be shown again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      _emailController.clear();
      await _loadStaff();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetStaffPassword(RecordModel staff) async {
    final email = staff.data['email']?.toString() ?? '';
    
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read staff email')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Text('Reset password for $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pbService = PocketBaseService();
    try {
      final newPassword = await pbService.resetStaffPassword(email, auth.businessId!);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Password Reset'),
          content: Text('New password for $email:\n\n$newPassword'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      await _loadStaff();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Management')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Staff Email',
                                hintText: 'staff@example.com',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addStaff,
                            child: const Text('Add Staff'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _staff.length,
                        itemBuilder: (ctx, i) {
                          final staff = _staff[i];
                          return ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(staff.getStringValue('email')),
                            subtitle: const Text('Role: Staff'),
                            trailing: IconButton(
                              icon: const Icon(Icons.lock_reset),
                              onPressed: () => _resetStaffPassword(staff),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}