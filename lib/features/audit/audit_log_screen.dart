import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../core/services/pocketbase_service.dart';
import '../../shared/providers/auth_provider.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<RecordModel> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.businessId == null) return;

    setState(() => _loading = true);

    try {
      final logs = await PocketBaseService().getAuditLogs(auth.businessId!);
      setState(() {
        _logs = logs;
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _logs.isEmpty
                  ? const Center(child: Text('No audit logs yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) {
                        final log = _logs[i];
                        final action = log.getStringValue('action');
                        final email = log.getStringValue('user_email');
                        final time = log.created;
                        final details = log.data['details'] as Map?;

                        bool isSale = action == 'sale_completed';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          child: ListTile(
                            leading: Icon(
                              isSale ? Icons.receipt_long : Icons.person,
                              color: isSale ? Colors.green : Colors.blue,
                            ),
                            title: Text(
                              isSale ? 'Sale Completed' : action,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('By: $email'),
                                Text('Time: $time'),
                                if (isSale && details != null) ...[
                                    Text('Receipt: ${details['receipt_no'] ?? 'N/A'}'),
                                  Text('Amount: ${auth.formatPrice((details['total_amount'] is num ? (details['total_amount'] as num).toDouble() : double.tryParse('${details['total_amount']}') ?? 0.0))}'),
                                  Text('Payment: ${details['payment_method'] ?? 'Cash'}'),
                                  Text('Reference: ${details['payment_reference'] ?? 'N/A'}'),
                                ],
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
    );
  }
}