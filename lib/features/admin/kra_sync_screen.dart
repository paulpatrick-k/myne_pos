import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';

class KraSyncScreen extends StatefulWidget {
  const KraSyncScreen({super.key});

  @override
  State<KraSyncScreen> createState() => _KraSyncScreenState();
}

class _KraSyncScreenState extends State<KraSyncScreen> {
  List<RecordModel> _failedSales = [];
  List<RecordModel> _pendingSales = [];
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.businessId == null) return;
    setState(() => _loading = true);
    final pbService = PocketBaseService();
    await pbService.ensureAdminAuth();

    try {
      // Fetch failed sales
      final failed = await pbService.adminPb.collection('sales').getList(
        filter: 'business_id = "${auth.businessId}" && kra_status = "failed"',
        sort: '-created',
      );
      // Fetch pending sales (older than 5 minutes to avoid those just created)
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
      final pending = await pbService.adminPb.collection('sales').getList(
        filter: 'business_id = "${auth.businessId}" && kra_status = "pending" && created < "$fiveMinutesAgo"',
        sort: '-created',
      );
      setState(() {
        _failedSales = failed.items;
        _pendingSales = pending.items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading sales: $e')));
    }
  }

  Future<void> _retrySale(RecordModel sale) async {
    setState(() => _syncing = true);
    final pbService = PocketBaseService();
    await pbService.ensureAdminAuth();
    try {
      // Reset status to pending – the hook will re‑attempt
      await pbService.adminPb.collection('sales').update(sale.id, body: {
        'kra_status': 'pending',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retry triggered – check back in a moment')),
      );
      await _loadSales(); // refresh list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retry failed: $e')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _retryAll() async {
    setState(() => _syncing = true);
    final allSales = [..._failedSales, ..._pendingSales];
    final pbService = PocketBaseService();
    await pbService.ensureAdminAuth();
    for (final sale in allSales) {
      try {
        await pbService.adminPb.collection('sales').update(sale.id, body: {
          'kra_status': 'pending',
        });
      } catch (e) {
        print('Error resetting sale ${sale.id}: $e');
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Retrying ${allSales.length} sale(s) – check logs')),
    );
    await _loadSales();
    setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('KRA Sync (eTIMS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
          if ((_failedSales.isNotEmpty || _pendingSales.isNotEmpty) && !_syncing)
            TextButton.icon(
              onPressed: _retryAll,
              icon: const Icon(Icons.sync),
              label: const Text('Retry All'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_failedSales.isEmpty && _pendingSales.isEmpty)
              ? const Center(child: Text('No pending or failed KRA submissions'))
              : ListView(
                  children: [
                    if (_pendingSales.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Pending Submissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ..._pendingSales.map((sale) => _buildSaleTile(sale, auth)),
                    ],
                    if (_failedSales.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Failed Submissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                      ..._failedSales.map((sale) => _buildSaleTile(sale, auth)),
                    ],
                  ],
                ),
    );
  }

  Widget _buildSaleTile(RecordModel sale, AuthProvider auth) {
    final receiptNo = sale.getStringValue('receipt_no');
    final total = sale.getDoubleValue('total_amount');
    final status = sale.getStringValue('kra_status');
    final attempts = sale.getIntValue('kra_sync_attempts') ?? 0;
    final date = DateTime.tryParse(sale.created ?? '') ?? DateTime.now();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text('Receipt: $receiptNo'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${date.toLocal()}'),
            Text('Total: ${auth.formatPrice(total)}'),
            Text('Status: $status (attempts: $attempts)'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.sync),
          onPressed: _syncing ? null : () => _retrySale(sale),
          tooltip: 'Retry',
        ),
      ),
    );
  }
}