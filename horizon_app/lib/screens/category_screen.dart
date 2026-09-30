import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import 'inventory_list_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String department;

  const CategoryScreen({
    super.key,
    required this.department,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _pbService = PocketBaseService();
  List<String> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all items for this department
      final records = await _pbService.client.collection('inventory').getFullList(
            filter: _pbService.client.filter('department = {:d}', {'d': widget.department}),
          );

      // Extract unique categories
      final Set<String> categorySet = {};
      for (var record in records) {
        final category = record.data['category'];
        if (category != null && category.toString().isNotEmpty) {
          categorySet.add(category.toString());
        } else {
          categorySet.add('Uncategorized');
        }
      }

      if (mounted) {
        setState(() {
          _categories = categorySet.toList()..sort();
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
            content: Text('Failed to load categories: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddItemToNewCategoryDialog() {
    final categoryController = TextEditingController();
    final nameController = TextEditingController();
    final quantityController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Item to New Category'),
          content: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g., Sensors, Fasteners',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g., MPU6050, M3 Screws',
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate category name
                if (categoryController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a category name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Validate item name
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an item name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Validate quantity
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
                      'category': categoryController.text.trim(),
                      'total_quantity': quantity,
                      'available_quantity': quantity,
                    },
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item and category added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Refresh the categories list
                    _fetchCategories();
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
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _pbService.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.department} Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchCategories,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _categories.isEmpty
              ? const Center(
                  child: Text(
                    'No categories found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchCategories,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return _buildCategoryCard(category);
                    },
                  ),
                ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _showAddItemToNewCategoryDialog,
              tooltip: 'Add Item to New Category',
              child: const Icon(Icons.create_new_folder),
            )
          : null,
    );
  }

  Widget _buildCategoryCard(String category) {
    // Choose icon and color based on category
    IconData icon = Icons.folder;
    Color color = Colors.teal;

    if (category == 'Uncategorized') {
      icon = Icons.folder_open;
      color = Colors.grey;
    } else if (category.toLowerCase().contains('sensor')) {
      icon = Icons.sensors;
      color = Colors.green;
    } else if (category.toLowerCase().contains('motor')) {
      icon = Icons.settings;
      color = Colors.orange;
    } else if (category.toLowerCase().contains('electronic')) {
      icon = Icons.memory;
      color = Colors.blue;
    } else if (category.toLowerCase().contains('tool')) {
      icon = Icons.build;
      color = Colors.brown;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InventoryListScreen(
                department: widget.department,
                category: category,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                category,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
