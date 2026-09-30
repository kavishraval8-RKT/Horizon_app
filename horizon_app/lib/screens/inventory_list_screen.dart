import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
  final _imagePicker = ImagePicker();
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
            content: Text('Failed to load inventory: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showActionBottomSheet(RecordModel item) {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();
    String? selectedAction;
    XFile? selectedImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final showNotesAndPhoto = selectedAction == 'Report Damaged';
            
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
                      'Available: ${item.data['available_quantity']} / ${item.data['total_quantity']}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'How many?',
                        hintText: 'Enter quantity',
                        border: OutlineInputBorder(),
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
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final XFile? image = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1920,
                              maxHeight: 1080,
                              imageQuality: 85,
                            );
                            setModalState(() {
                              selectedImage = image;
                            });
                          } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to pick image: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          }
                        },
                        icon: const Icon(Icons.photo_camera),
                        label: Text(selectedImage == null 
                            ? 'Upload Photo (Optional)' 
                            : 'Photo Selected'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                      if (selectedImage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.network(
                                    selectedImage!.path,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(selectedImage!.path),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _handleAction(
                                item,
                                'Checked Out',
                                quantityController.text,
                                notes: notesController.text,
                                photo: selectedImage,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text('Check Out'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _handleAction(
                                item,
                                'Returned',
                                quantityController.text,
                                notes: notesController.text,
                                photo: selectedImage,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Return'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            // First tap reveals notes + photo, second tap submits
                            onPressed: () {
                              if (!showNotesAndPhoto) {
                                setModalState(() {
                                  selectedAction = 'Report Damaged';
                                });
                                return;
                              }
                              _handleAction(
                                item,
                                'Damaged',
                                quantityController.text,
                                notes: notesController.text,
                                photo: selectedImage,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: Text(showNotesAndPhoto ? 'Submit Damage' : 'Damaged'),
                          ),
                        ),
                      ],
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

  Future<void> _handleAction(
    RecordModel item,
    String action,
    String quantityText, {
    String? notes,
    XFile? photo,
  }) async {
    // Validate quantity
    final quantity = int.tryParse(quantityText);
    if (quantity == null || quantity <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid quantity'),
            backgroundColor: Colors.orange,
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
          'item': item.id,
          'user': currentUserId,
          'quantity': quantity,
          'action': action,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
        files: [
          if (photo != null)
            http.MultipartFile.fromBytes(
              'photo',
              await photo.readAsBytes(),
              filename: photo.name,
            ),
        ],
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action successful'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchInventory();
      }
    } catch (e) {
      if (mounted) {
        // Show the server's reason (e.g. "Only 2 available.") rather than the raw exception
        final reason = e is ClientException ? e.response['message'] ?? e : e;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $reason'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
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
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Total Quantity',
                      hintText: 'Enter quantity',
                      border: OutlineInputBorder(),
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
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter an item name'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final quantity = int.tryParse(quantityController.text);
                    if (quantity == null || quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid quantity'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    try {
                      await _pbService.client.collection('inventory').create(
                        body: {
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
                            backgroundColor: Colors.green,
                          ),
                        );
                        _fetchInventory();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to add item: ${e.toString()}'),
                            backgroundColor: Colors.red,
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
                SnackBar(content: Text(done), backgroundColor: Colors.green),
              );
              _fetchInventory();
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
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
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: totalController,
                decoration: const InputDecoration(
                  labelText: 'Total Quantity',
                  border: OutlineInputBorder(),
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
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
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
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                run(
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
              ? const Center(
                  child: Text(
                    'No inventory found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
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
                      final department = item.data['department'] ?? 'N/A';
                      final availableQty = item.data['available_quantity'] ?? 0;
                      final totalQty = item.data['total_quantity'] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        child: InkWell(
                          onTap: () => _showActionBottomSheet(item),
                          onLongPress: isAdmin ? () => _showEditItemDialog(item) : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        department,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$availableQty / $totalQty',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: availableQty > 0 ? Colors.green : Colors.red,
                                  ),
                                ),
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
