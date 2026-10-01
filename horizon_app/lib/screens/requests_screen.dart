import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _pbService = PocketBaseService();
  List<RecordModel> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  String getUserDisplayName(RecordModel record) {
    String displayName = "Unknown User";
    try {
      if (record.expand.containsKey('requested_by') && record.expand['requested_by']!.isNotEmpty) {
        final userRecord = record.expand['requested_by']![0];
        
        // 1. Prioritize email
        displayName = userRecord.getStringValue('email');
        
        // 2. Fallbacks if email is hidden by PocketBase privacy
        if (displayName.isEmpty) displayName = userRecord.getStringValue('username');
        if (displayName.isEmpty) displayName = userRecord.getStringValue('name');
        if (displayName.isEmpty) displayName = 'User ID: ${userRecord.id}';
      }
    } catch (e) {
      // Use default 'Unknown User'
    }
    return displayName;
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // The server's list rule returns only the member's own requests (admins see all)
      final records = await _pbService.client
          .collection('procurement_requests')
          .getFullList(
            sort: '-created',
            expand: 'requested_by',
          );

      if (mounted) {
        setState(() {
          _requests = records;
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
            content: Text('Couldn\'t load requests. ${friendlyError(e)}'),
            backgroundColor: C.danger,
          ),
        );
      }
    }
  }

  void _showSubmitRequestSheet() {
    final itemNameController = TextEditingController();
    final submitId = PocketBaseService.newId(); // one record per form, even if submitted twice
    final quantityController = TextEditingController();
    final justificationController = TextEditingController();
    final linkController = TextEditingController();
    String selectedDepartment = 'Avionics';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Submit Procurement Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: itemNameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        hintText: 'What do you need?',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        hintText: 'How many?',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Avionics',
                          child: Text('Avionics'),
                        ),
                        DropdownMenuItem(
                          value: 'Mechanical',
                          child: Text('Mechanical'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setModalState(() {
                            selectedDepartment = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: justificationController,
                      decoration: const InputDecoration(
                        labelText: 'Justification',
                        hintText: 'Why is this needed?',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: linkController,
                      decoration: const InputDecoration(
                        labelText: 'Purchase Link',
                        hintText: 'Where can we buy it?',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SubmitButton(
                      onPressed: () async {
                        if (itemNameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter item name'),
                            ),
                          );
                          return;
                        }

                        final quantity = int.tryParse(quantityController.text);
                        if (quantity == null || quantity <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter valid quantity'),
                            ),
                          );
                          return;
                        }

                        if (justificationController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter justification'),
                            ),
                          );
                          return;
                        }

                        try {
                          final userId = _pbService.currentUser?.id;
                          if (userId == null) {
                            throw Exception('User not authenticated');
                          }

                          await PocketBaseService.createOnce(_pbService.client.collection('procurement_requests'), submitId, {
                              'requested_by': userId,
                              'item_name': itemNameController.text.trim(),
                              'quantity': quantity,
                              'department': selectedDepartment,
                              'justification': justificationController.text.trim(),
                              'vendor_link': linkController.text.trim(),
                              'status': 'Pending',
                            },
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Request submitted successfully'),
                              ),
                            );
                            _fetchRequests();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to submit: ${e.toString()}'),
                                backgroundColor: C.danger,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Submit Request'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUpdateStatusDialog(RecordModel request) {
    String selectedStatus = request.data['status'] ?? 'Pending';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Update Request Status?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Status:'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'Approved', child: Text('Approved')),
                      DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
                      DropdownMenuItem(value: 'Ordered', child: Text('Ordered')),
                      DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setDialogState(() {
                          selectedStatus = newValue;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                SubmitButton(
                  onPressed: () async {
                    try {
                      await _pbService.client.collection('procurement_requests').update(
                        request.id,
                        body: {
                          'status': selectedStatus,
                        },
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Status updated successfully'),
                          ),
                        );
                        _fetchRequests();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update: ${e.toString()}'),
                            backgroundColor: C.danger,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _statusIcon(String status) => switch (status) {
        'Approved' => Icons.check,
        'Rejected' => Icons.close,
        'Ordered' => Icons.local_shipping_outlined,
        'Delivered' => Icons.inventory_2_outlined,
        _ => Icons.schedule,
      };

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return C.warn;
      case 'Approved':
        return C.ok;
      case 'Rejected':
        return C.danger;
      case 'Ordered':
        return C.text; // in transit: neutral, the truck icon carries it
      case 'Delivered':
        return C.muted; // done: recedes
      default:
        return C.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _pbService.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Procurement Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _requests.isEmpty
              ? Center(
                  child: Text(
                    'No requests yet',
                    style: TextStyle(fontSize: 18, color: C.muted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      final itemName = request.getStringValue('item_name');
                      final quantity = request.getIntValue('quantity');
                      final department = request.getStringValue('department');
                      final justification = request.getStringValue('justification');
                      final link = request.getStringValue('vendor_link');
                      final status = request.getStringValue('status');
                      final userDisplayName = getUserDisplayName(request);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: isAdmin ? () => _showUpdateStatusDialog(request) : null,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${quantity}x $itemName',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Requested by: $userDisplayName • $department',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: C.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusTag(status, _getStatusColor(status), icon: _statusIcon(status)),
                                  ],
                                ),
                                const Divider(height: 24),
                                const Text(
                                  'Justification:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  justification,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (link.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Purchase Link:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () {
                                      // Member-entered link: only ever open web pages, never other app schemes
                                      final uri = Uri.tryParse(link);
                                      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                                        launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Text(
                                      link,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: C.accent,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                                if (isAdmin) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tap to update status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: C.muted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showSubmitRequestSheet,
        tooltip: 'Submit Request',
        child: const Icon(Icons.add),
      ),
    );
  }
}
