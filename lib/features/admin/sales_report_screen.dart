import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _reportData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReportData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final businessId = authProvider.businessId!;
      final pbService = PocketBaseService();

      if (_tabController.index == 0) {
        // Daily report
        final todayData = await pbService.getTodaySalesData(businessId);
        setState(() {
          _reportData = todayData;
          _isLoading = false;
        });
      } else {
        // Monthly report
        final monthlyData = await pbService.getMonthlySalesData(
          businessId,
          _selectedDate.year,
          _selectedDate.month,
        );
        setState(() {
          _reportData = monthlyData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading report data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {});
            _loadReportData();
          },
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Monthly'),
          ],
        ),
        actions: [
          if (_tabController.index == 1) // Monthly tab
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDailyReport(),
                _buildMonthlyReport(),
              ],
            ),
    );
  }

  Widget _buildDailyReport() {
    final auth = Provider.of<AuthProvider>(context);
    final sales = _reportData['sales'] as List<dynamic>? ?? [];
    final totalSales = _reportData['total'] as double? ?? 0.0;
    final totalTransactions = _reportData['count'] as int? ?? 0;

    return RefreshIndicator(
      onRefresh: _loadReportData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    auth.formatPrice(totalSales),
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Transactions',
                    '$totalTransactions',
                    Icons.receipt,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Sales List
            const Text(
              'Today\'s Sales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (sales.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sales recorded today'),
                ),
              )
            else
              ...sales.map((sale) {
                final date = DateTime.tryParse(sale.created?.toString() ?? '')?.toLocal() ?? DateTime.now();
                final paymentReference = sale.getStringValue('payment_reference');
                return Card(
                  child: ListTile(
                    title: Text('Receipt: ${sale.getStringValue('receipt_no')}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${sale.getStringValue('user_email')} • ${sale.getStringValue('payment_method')}'),
                        Text('${DateFormat.yMMMd().add_jm().format(date)}'),
                        if (paymentReference.isNotEmpty) Text('Ref: $paymentReference'),
                      ],
                    ),
                    trailing: Text(
                      auth.formatPrice(sale.getDoubleValue('total_amount')),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyReport() {
    final auth = Provider.of<AuthProvider>(context);
    final totalSales = _reportData['total'] as double? ?? 0.0;
    final totalTransactions = _reportData['count'] as int? ?? 0;
    final dailySales = _reportData['daily_sales'] as Map<String, dynamic>? ?? {};
    final sales = _reportData['sales'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      onRefresh: _loadReportData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header
            Center(
              child: Text(
                '${_selectedDate.year} - ${_selectedDate.month.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Sales',
                    auth.formatPrice(totalSales),
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Transactions',
                    '$totalTransactions',
                    Icons.receipt,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Daily Breakdown
            const Text(
              'Daily Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (dailySales.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sales data for this month'),
                ),
              )
            else
              ...dailySales.entries.map((entry) => Card(
                    child: ListTile(
                      title: Text('Day ${entry.key.split('-').last}'),
                      trailing: Text(
                        auth.formatPrice(entry.value as double),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )),
            if (sales.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Sales this month',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...sales.take(10).map((sale) {
                final date = DateTime.tryParse(sale.created?.toString() ?? '')?.toLocal() ?? DateTime.now();
                final paymentReference = sale.getStringValue('payment_reference');
                return Card(
                  child: ListTile(
                    title: Text('Receipt: ${sale.getStringValue('receipt_no')}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${sale.getStringValue('payment_method')} • ${sale.getStringValue('user_email')}'),
                        Text('${DateFormat.yMMMd().add_jm().format(date)}'),
                        if (paymentReference.isNotEmpty) Text('Ref: $paymentReference'),
                      ],
                    ),
                    trailing: Text(
                      auth.formatPrice(sale.getDoubleValue('total_amount')),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}