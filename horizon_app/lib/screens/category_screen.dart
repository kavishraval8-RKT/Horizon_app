import 'package:flutter/material.dart';
import '../theme.dart';
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
            backgroundColor: C.danger,
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
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    hintText: 'e.g., MPU6050, M3 Screws',
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
                    ),
                  );
                  return;
                }

                // Validate item name
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter an item name'),
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
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _pbService.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.department),
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
              ? Center(
                  child: Text(
                    'No categories found',
                    style: TextStyle(fontSize: 18, color: C.muted),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchCategories,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildCategoryCard(_categories[index]),
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
    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InventoryListScreen(
              department: widget.department,
              category: category,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: category == 'Uncategorized' ? C.muted : C.text,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: C.muted),
            ],
          ),
        ),
      ),
    );
  }
}
