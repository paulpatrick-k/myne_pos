import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/auth_provider.dart';
import '../items/item_list_screen.dart';
import '../staff/staff_list_screen.dart';
import '../audit/audit_log_screen.dart';
import '../staff/staff_home_screen.dart';
import '../admin/admin_dashboard.dart';
import '../admin/admin_account_screen.dart';
import '../admin/sales_report_screen.dart';
import '../admin/business_profile_screen.dart';
import '../admin/kra_sync_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isLicenseExpired()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/paywall');
      });
      return const SizedBox.shrink();
    }

    final isAdmin = authProvider.role == 'admin';
    final isStaff = authProvider.role == 'staff';

    if (isStaff) {
      return const StaffHomeScreen();
    }

    if (isAdmin) {
      return DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: Consumer<AuthProvider>(
              builder: (_, auth, __) => Row(
                children: [
                  if (auth.businessLogoUrl != null && auth.businessLogoUrl!.isNotEmpty)
                    Image.network(auth.businessLogoUrl!, height: 40, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  const SizedBox(width: 8),
                  const Text('MYNE POS - Admin'),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }
                },
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
                Tab(icon: Icon(Icons.bar_chart), text: 'Reports'),
                Tab(icon: Icon(Icons.people), text: 'Staff'),
                Tab(icon: Icon(Icons.settings), text: 'Manage'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              AdminDashboard(),
              SalesReportScreen(),
              StaffListScreen(),
              AdminManagementTab(),
            ],
          ),
        ),
      );
    }

    // Fallback
    return Scaffold(
      appBar: AppBar(title: const Text('MYNE POS')),
      body: const Center(child: Text('Unknown role')),
    );
  }
}

class AdminManagementTab extends StatelessWidget {
  const AdminManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              children: [
                _buildNavTile(
                  context,
                  icon: Icons.business,
                  title: 'Business Profile',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BusinessProfileScreen()),
                  ),
                ),
                _buildNavTile(
                  context,
                  icon: Icons.history,
                  title: 'Audit Logs',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                  ),
                ),
                _buildNavTile(
                  context,
                  icon: Icons.inventory,
                  title: 'Manage Items',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ItemListScreen()),
                  ),
                ),
                _buildNavTile(
                  context,
                  icon: Icons.assignment,
                  title: 'KRA Sync (eTIMS)',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KraSyncScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontSize: 18)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}