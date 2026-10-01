import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:intl/intl.dart';
import '../services/pocketbase_service.dart';

class AdminLedgerScreen extends StatefulWidget {
  const AdminLedgerScreen({super.key});

  @override
  State<AdminLedgerScreen> createState() => _AdminLedgerScreenState();
}

class _AdminLedgerScreenState extends State<AdminLedgerScreen> {
  final _pbService = PocketBaseService();
  List<RecordModel> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final records = await _pbService.client.collection('inventory_logs').getFullList(
            sort: '-created',
            expand: 'item,user',
          );
      
      if (mounted) {
        setState(() {
          _logs = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load logs: ${e.toString()}'),
            backgroundColor: C.danger,
          ),
        );
      }
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'Checked Out':
        return C.warn;
      case 'Returned':
        return C.ok;
      case 'Damaged':
        return C.danger;
      default:
        return C.muted;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'Checked Out':
        return Icons.logout;
      case 'Returned':
        return Icons.login;
      case 'Damaged':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateTime).toLocal();
      return DateFormat('MMM d, y • h:mm a').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showLogDetails(RecordModel log) {
    final action = log.data['action'] ?? 'Unknown';
    final quantity = log.data['quantity'] ?? 0;
    final notes = log.data['notes'] ?? '';
    final photo = log.data['photo'];
    final created = log.data['created'];

    String userEmail = 'Unknown User';
    try {
      final email = log.get<String>('expand.user.email');
      if (email.isNotEmpty) {
        userEmail = email;
      }
    } catch (e) {
      // Use default
    }

    String itemName = 'Unknown Item';
    try {
      final name = log.get<String>('expand.item.name');
      if (name.isNotEmpty) {
        itemName = name;
      }
    } catch (e) {
      // Use default
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getActionIcon(action),
                      color: _getActionColor(action),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _getActionColor(action),
                            ),
                          ),
                          Text(
                            _formatDateTime(created),
                            style: TextStyle(
                              fontSize: 12,
                              color: C.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildDetailRow('User', userEmail),
                _buildDetailRow('Item', itemName),
                _buildDetailRow('Quantity', '$quantity'),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Notes:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
                if (photo != null && photo.toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Photo:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      '${_pbService.client.baseURL}/api/files/${log.collectionId}/${log.id}/$photo',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 100,
                          color: C.line,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 50),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _logs.isEmpty
              ? Center(
                  child: Text(
                    'No logs found',
                    style: TextStyle(fontSize: 18, color: C.muted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final action = log.data['action'] ?? 'Unknown';
                      final quantity = log.data['quantity'] ?? 0;
                      final created = log.data['created'];

                      String userEmail = 'Unknown User';
                      try {
                        final email = log.get<String>('expand.user.email');
                        if (email.isNotEmpty) {
                          userEmail = email;
                        }
                      } catch (e) {
                        // Use default
                      }

                      String itemName = 'Unknown Item';
                      try {
                        final name = log.get<String>('expand.item.name');
                        if (name.isNotEmpty) {
                          itemName = name;
                        }
                      } catch (e) {
                        // Use default
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _showLogDetails(log),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Icon(_getActionIcon(action), color: _getActionColor(action), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(context).style,
                                          children: [
                                            TextSpan(
                                              text: userEmail.length > 20 
                                                  ? '${userEmail.substring(0, 17)}...' 
                                                  : userEmail,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' $action ',
                                              style: TextStyle(
                                                color: _getActionColor(action),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '${quantity}x ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(text: itemName),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDateTime(created),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: C.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: C.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
