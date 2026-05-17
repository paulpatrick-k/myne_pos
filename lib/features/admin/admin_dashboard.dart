import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../models/item_model.dart';
import '../items/item_form_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with AutomaticKeepAliveClientMixin {
  final pbService = PocketBaseService();
  late String businessId;
  TabController? _tabController;

  double _todayTotal = 0;
  int _todayCount = 0;
  double _monthTotal = 0;
  int _monthCount = 0;
  List<RecordModel> _lowStockItems = [];
  int _staffCount = 0;
  List<RecordModel> _recentSales = [];
  List<RecordModel> _expiringSoonItems = [];  // NEW
  bool _loadingExpiring = false;  // NEW
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    businessId = auth.businessId!;
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.maybeOf(context);
    if (controller != null && _tabController != controller) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = controller;
      _tabController!.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (_tabController != null &&
        _tabController!.indexIsChanging &&
        _tabController!.index == 0) {
      print('🔄 Dashboard tab activated - reloading data');
      _loadData(); // reload when Dashboard tab becomes active
    }
  }

  Future<void> _loadData() async {
    if (_loading) return;
    setState(() => _loading = true);
    print('📊 Loading dashboard data for business: $businessId');
    try {
      final todayData = await pbService.getTodaySalesData(businessId);
      final monthData = await pbService.getMonthSalesData(
        businessId,
        DateTime.now().year,
        DateTime.now().month,
      );
      final lowStock = await pbService.getLowStockItems(businessId);
      final staffCount = await pbService.getStaffCount(businessId);
      final recentSales = await pbService.getRecentSales(businessId);

      // Load expiring items if pharmacy
      final auth = Provider.of<AuthProvider>(context, listen: false);
      List<RecordModel> expiringSoon = [];
      if (auth.businessCategory?.toLowerCase() == 'pharmacy') {
        expiringSoon = await pbService.getExpiringSoonItems(businessId, 30);
      }

      setState(() {
        _todayTotal = todayData['total'];
        _todayCount = todayData['count'];
        _monthTotal = monthData['total'];
        _monthCount = monthData['count'];
        _lowStockItems = lowStock;
        _staffCount = staffCount;
        _recentSales = recentSales;
        _expiringSoonItems = expiringSoon;
        _loading = false;
        print('✅ Dashboard loaded: today=$_todayTotal, month=$_monthTotal, staff=$_staffCount, lowStock=${_lowStockItems.length}, expiring=${_expiringSoonItems.length}');
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = Provider.of<AuthProvider>(context);
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _loading && _todayTotal == 0 && _lowStockItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Today\'s Sales',
                          auth.formatPrice(_todayTotal),
                          '$_todayCount transactions',
                          Icons.today,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'This Month',
                          auth.formatPrice(_monthTotal),
                          '$_monthCount transactions',
                          Icons.calendar_month,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Staff',
                          '$_staffCount',
                          'active staff members',
                          Icons.people,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Low Stock Items',
                          '${_lowStockItems.length}',
                          'items below threshold',
                          Icons.warning_amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_lowStockItems.isNotEmpty) ...[
                    const Text(
                      'Low Stock Alerts',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._lowStockItems.map((record) {
                      if (record == null) return const SizedBox.shrink();
                      final item = ItemModel.fromRecord(record);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.inventory),
                          title: Text(item.name),
                          subtitle: Text('Stock: ${item.stockQty} units'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ItemFormScreen(item: item),
                                ),
                              ).then((_) => _loadData());
                            },
                            child: const Text('Restock'),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                  if (_expiringSoonItems.isNotEmpty) ...[
                    const Text(
                      'Expiring Soon',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._expiringSoonItems.map((record) {
                      if (record == null) return const SizedBox.shrink();
                      final item = ItemModel.fromRecord(record);
                      final daysRemaining = item.expiryDate != null
                          ? item.expiryDate!.difference(DateTime.now()).inDays
                          : 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: daysRemaining <= 7
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                        child: ListTile(
                          leading: Icon(
                            Icons.warning_outlined,
                            color: daysRemaining <= 7
                                ? Colors.red
                                : Colors.orange,
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            'Batch: ${item.batchNumber ?? 'N/A'} • Expires in $daysRemaining days (${item.expiryDate != null ? DateFormat('MMM dd').format(item.expiryDate!) : 'N/A'})',
                          ),
                          trailing: Text(
                            'Stock: ${item.stockQty}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                  const Text(
                    'Recent Sales',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_recentSales.isEmpty)
                    const Text('No sales yet')
                  else
                    ..._recentSales.map((sale) {
                      if (sale == null) return const SizedBox.shrink();
                      final receiptNo = sale.getStringValue('receipt_no');
                      final total = sale.getDoubleValue('total_amount');
                      final method = sale.getStringValue('payment_method');
                      final reference = sale.getStringValue('payment_reference');
                      final dateStr = sale.created;
                      if (dateStr == null) return const SizedBox.shrink();
                      final date = DateTime.tryParse(dateStr.toString()) ?? DateTime.now();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.receipt),
                          title: Text('Receipt: $receiptNo'),
                          subtitle: Text(
                            '${DateFormat.yMMMd().add_jm().format(date)} • $method${reference.isNotEmpty ? '\nRef: $reference' : ''}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: Text(auth.formatPrice(total)),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, String subtitle, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}