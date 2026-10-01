import 'package:flutter/material.dart';
import '../photo.dart';
import '../theme.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pocketbase_service.dart';

class InventoryListScreen extends StatefulWidget {
  final String department;
  final String category;
  
  const InventoryListScreen({
    super.key,
    required this.department,
    required this.category,
  });

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _pbService = PocketBaseService();
  List<RecordModel> _inventoryItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 'Uncategorized' is shown for items with an empty category
      final records = await _pbService.client.collection('inventory').getFullList(
            filter: _pbService.client.filter('department = {:d} && category = {:c}', {
              'd': widget.department,
              'c': widget.category == 'Uncategorized' ? '' : widget.category,
            }),
            sort: 'name',
          );
      
      if (mounted) {
        setState(() {
          _inventoryItems = records;
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
            content: Text('Couldn\'t load inventory. ${friendlyError(e)}'),
            backgroundColor: C.danger,
          ),
        );
      }
    }
  }

  /// How many of [item] the signed-in user has out: their check-outs minus their returns.
  Future<int> _heldByMe(RecordModel item) async {
    final me = _pbService.currentUser?.id;
    if (me == null) return 0;
    try {
      final logs = await _pbService.client.collection('inventory_logs').getFullList(
            filter: _pbService.client.filter(
              'user = {:me} && item = {:item} && '
              '(action = "Checked Out" || action = "Returned" || action = "Returned Damaged")',
              {'me': me, 'item': item.id},
            ),
            fields: 'action,quantity',
          );
      return logs.fold<int>(0, (n, l) =>
          n + (l.getStringValue('action') == 'Checked Out' ? 1 : -1) * l.getIntValue('quantity'));
    } catch (_) {
      return 0; // can't tell: hide Return rather than offer one the server would refuse
    }
  }

  Future<void> _showActionBottomSheet(RecordModel item) async {
    final held = await _heldByMe(item);
    if (!mounted) return;
    final isAdmin = _pbService.isAdmin;
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedAction;
    XFile? selectedImage;
    String? busy; // the action being submitted; all buttons lock until the server answers
    final ids = <String, String>{}; // one record id per action, reused if it's resubmitted

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final showNotesAndPhoto = selectedAction == 'Report Damaged';

            Future<void> submit(String action) async {
              if (busy != null) return;
              setModalState(() => busy = action);
              await _handleAction(
                item,
                action,
                quantityController.text,
                notes: notesController.text,
                photo: selectedImage,
                id: ids.putIfAbsent(action, PocketBaseService.newId),
              );
              // On success the sheet has closed; on failure unlock so they can fix and retry
              if (context.mounted) setModalState(() => busy = null);
            }

            Widget label(String action, String text) => busy == action
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(text);
            
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
                    Text(
                      item.data['name'] ?? 'Unknown Item',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available: ${item.data['available_quantity']} / ${item.data['total_quantity']}'
                      '${held > 0 ? '  ·  You have $held' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: C.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'How many?',
                        hintText: 'Enter quantity',
                      ),
                      keyboardType: TextInputType.number,
                      autofocus: true,
                    ),
                    if (showNotesAndPhoto) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Damage Notes',
                          hintText: 'Describe the damage...',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      PhotoField(
                        photo: selectedImage,
                        label: 'Add photo of the damage (optional)',
                        onChanged: (p) => setModalState(() => selectedImage = p),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: busy != null ? null : () => submit('Checked Out'),
                            child: label('Checked Out', 'Check Out'),
                          ),
                        ),
                        if (held > 0) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: busy != null ? null : () => submit('Returned'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: C.ok,
                                side: BorderSide(color: C.ok),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: label('Returned', 'Return ($held)'),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            // First tap reveals notes + photo, second tap submits
                            onPressed: busy != null
                                ? null
                                : () {
                                    if (!showNotesAndPhoto) {
                                      setModalState(() => selectedAction = 'Report Damaged');
                                      return;
                                    }
                                    submit('Damaged');
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: C.danger,
                              side: BorderSide(color: C.danger),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: label('Damaged', showNotesAndPhoto ? 'Submit' : 'Damaged'),
                          ),
                        ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: busy != null ? null : () => submit('Restocked'),
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: label('Restocked', 'Restock'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ],
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

  Future<void> _handleAction(
    RecordModel item,
    String action,
    String quantityText, {
    String? notes,
    XFile? photo,
    String? id,
  }) async {
    // Validate quantity
    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid quantity'),
          ),
        );
      }
      return;
    }

    try {
      final currentUserId = _pbService.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // The server (backend/pb_hooks) validates the quantity and updates
      // available_quantity in the same transaction as this log entry.
      await _pbService.client.collection('inventory_logs').create(
        body: {
          'id': ?id,
          'item': item.id,
          'user': currentUserId,
          'quantity': quantity,
          'action': action,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        files: [if (photo != null) await photoPart(photo)],
      );

      _actionDone(action);
    } catch (e) {
      if (PocketBaseService.isDuplicate(e)) return _actionDone(action);
      if (mounted) {
        // Show the server's reason (e.g. "Only 2 available.") rather than the raw exception
        final reason = e is ClientException ? e.response['message'] ?? e : e;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $reason'),
            backgroundColor: C.danger,
          ),
        );
      }
    }
  }

  void _actionDone(String action) {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action recorded')));
    _fetchInventory();
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final submitId = PocketBaseService.newId(); // one record per form, even if submitted twice
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text('Add Item to ${widget.department}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      hintText: 'Enter item name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Total Quantity',
                      hintText: 'Enter quantity',
                    ),
                    keyboardType: TextInputType.number,
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
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter an item name'),
                        ),
                      );
                      return;
                    }

                    final quantity = int.tryParse(quantityController.text);
                    if (quantity == null || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid quantity'),
                        ),
                      );
                      return;
                    }

                    try {
                      await PocketBaseService.createOnce(_pbService.client.collection('inventory'), submitId, {
                          'name': nameController.text.trim(),
                          'department': widget.department,
                          'category': widget.category == 'Uncategorized' ? '' : widget.category,
                          'total_quantity': quantity,
                          'available_quantity': quantity,
                        },
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Item added successfully'),
                          ),
                        );
                        _fetchInventory();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to add item: ${e.toString()}'),
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

  void _showEditItemDialog(RecordModel item) {
    final nameController = TextEditingController(text: item.getStringValue('name'));
    final totalController =
        TextEditingController(text: '${item.getIntValue('total_quantity')}');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        Future<void> run(Future<void> Function() op, String done) async {
          try {
            await op();
            if (context.mounted) Navigator.pop(context);
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text(done), backgroundColor: C.ok),
              );
              _fetchInventory();
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed: $e'), backgroundColor: C.danger),
              );
            }
          }
        }

        return AlertDialog(
          title: const Text('Edit Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: totalController,
                decoration: const InputDecoration(
                  labelText: 'Total Quantity',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final sure = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Delete Item'),
                    content: Text('Delete "${item.getStringValue('name')}"? '
                        'Its ledger entries stay but lose the item link.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        style: ElevatedButton.styleFrom(backgroundColor: C.danger),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (sure == true) {
                  await run(
                    () => _pbService.client.collection('inventory').delete(item.id),
                    'Item deleted',
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: C.danger),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            SubmitButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final newTotal = int.tryParse(totalController.text);
                // Keep the checked-out count the same: shift available by the change in total.
                final checkedOut = item.getIntValue('total_quantity') -
                    item.getIntValue('available_quantity');
                if (name.isEmpty || newTotal == null || newTotal < checkedOut) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Enter a name and a total of at least $checkedOut '
                          '(currently checked out or damaged)'),
                    ),
                  );
                  return;
                }
                await run(
                  () => _pbService.client.collection('inventory').update(
                    item.id,
                    body: {
                      'name': name,
                      'total_quantity': newTotal,
                      'available_quantity': newTotal - checkedOut,
                    },
                  ),
                  'Item updated',
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _pbService.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category} (${widget.department})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchInventory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _inventoryItems.isEmpty
              ? Center(
                  child: Text(
                    'No inventory found',
                    style: TextStyle(fontSize: 18, color: C.muted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchInventory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _inventoryItems.length,
                    itemBuilder: (context, index) {
                      final item = _inventoryItems[index];
                      final name = item.data['name'] ?? 'Unknown';
                      final availableQty = item.data['available_quantity'] ?? 0;
                      final totalQty = item.data['total_quantity'] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _showActionBottomSheet(item),
                          onLongPress: isAdmin ? () => _showEditItemDialog(item) : null,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Text(
                                  '$availableQty',
                                  style: mono.copyWith(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: availableQty > 0 ? C.text : C.danger,
                                  ),
                                ),
                                Text(' / $totalQty', style: mono.copyWith(color: C.muted)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _showAddItemDialog,
              tooltip: 'Add Item',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
