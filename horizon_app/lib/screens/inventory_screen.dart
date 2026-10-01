import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import '../theme.dart';
import 'category_screen.dart';
import 'inventory_list_screen.dart';

/// Inventory home: search, stock readouts, departments, and what's running low.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const _departments = [
    ('Avionics', 'Electronics, sensors, flight computers'),
    ('Mechanical', 'Structures, fasteners, tooling'),
  ];

  final _pb = PocketBaseService();
  final _search = TextEditingController();
  List<RecordModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ponytail: loads every item once; fine for a club store, paginate past a few thousand
  Future<void> _load() async {
    try {
      final items = await _pb.client.collection('inventory').getFullList(
            sort: 'name',
            fields: 'id,name,department,category,available_quantity,total_quantity',
          );
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load inventory: $e'), backgroundColor: C.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int _avail(RecordModel r) => r.getIntValue('available_quantity');
  static int _total(RecordModel r) => r.getIntValue('total_quantity');
  static bool _out(RecordModel r) => _avail(r) <= 0;
  static bool _low(RecordModel r) => !_out(r) && _avail(r) * 4 <= _total(r); // ≤ 25% left

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load(); // counts may have changed
  }

  void _openItem(RecordModel r) {
    final category = r.getStringValue('category');
    _open(InventoryListScreen(
      department: r.getStringValue('department'),
      category: category.isEmpty ? 'Uncategorized' : category,
    ));
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(text, style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
      );

  Widget _readout(String label, int value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: C.surface,
            border: Border.all(color: C.line),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: mono.copyWith(fontSize: 26, fontWeight: FontWeight.w600, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: C.muted, fontSize: 11, letterSpacing: 1)),
            ],
          ),
        ),
      );

  Widget _itemRow(RecordModel r) {
    final out = _out(r);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openItem(r),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.getStringValue('name'), style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      [r.getStringValue('department'), r.getStringValue('category')]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(color: C.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text('${_avail(r)}',
                  style: mono.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: out ? C.danger : (_low(r) ? C.warn : C.text),
                  )),
              Text(' / ${_total(r)}', style: mono.copyWith(color: C.muted)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final results = query.isEmpty
        ? const <RecordModel>[]
        : _items.where((r) => r.getStringValue('name').toLowerCase().contains(query)).toList();
    final lowList = _items.where((r) => _out(r) || _low(r)).toList()
      ..sort((a, b) => (_avail(a) / (_total(a) == 0 ? 1 : _total(a)))
          .compareTo(_avail(b) / (_total(b) == 0 ? 1 : _total(b))));

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: 'Search parts',
                      prefixIcon: Icon(Icons.search, color: C.muted, size: 20),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _search.clear,
                            ),
                    ),
                  ),
                  if (query.isNotEmpty) ...[
                    _label('${results.length} RESULT${results.length == 1 ? '' : 'S'}'),
                    for (final r in results) _itemRow(r),
                  ] else ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _readout('ITEMS', _items.length, C.text),
                        const SizedBox(width: 8),
                        _readout('LOW', _items.where(_low).length, C.warn),
                        const SizedBox(width: 8),
                        _readout('OUT', _items.where(_out).length, C.danger),
                      ],
                    ),
                    _label('DEPARTMENTS'),
                    for (final (name, blurb) in _departments) ...() {
                      final dept = _items.where((r) => r.getStringValue('department') == name);
                      final attention = dept.where((r) => _out(r) || _low(r)).length;
                      return [
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _open(CategoryScreen(department: name)),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(blurb, style: TextStyle(color: C.muted, fontSize: 13)),
                                        const SizedBox(height: 10),
                                        Text.rich(
                                          TextSpan(children: [
                                            TextSpan(text: '${dept.length}', style: mono),
                                            const TextSpan(text: ' items'),
                                            if (attention > 0) ...[
                                              const TextSpan(text: '  ·  '),
                                              TextSpan(
                                                text: '$attention',
                                                style: mono.copyWith(color: C.warn),
                                              ),
                                              TextSpan(text: ' need restock', style: TextStyle(color: C.warn)),
                                            ],
                                          ]),
                                          style: TextStyle(fontSize: 13, color: C.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward, color: C.muted, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ];
                    }(),
                    _label('RUNNING LOW'),
                    if (lowList.isEmpty)
                      Text('Everything is well stocked.', style: TextStyle(color: C.muted))
                    else
                      for (final r in lowList.take(6)) _itemRow(r),
                  ],
                ],
              ),
            ),
    );
  }
}
