import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import '../theme.dart';
import 'bulk_checkout_screen.dart';
import 'category_screen.dart';
import 'return_parts_screen.dart';
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
  String? _error; // set when the last load failed

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
      if (mounted) setState(() {
        _items = items;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
      // Already showing data from earlier: keep it on screen and just say the refresh failed
      if (_items.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't refresh. $_error"), backgroundColor: C.danger),
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

  Future<void> _bulkCheckout() => _openFlow(const BulkCheckoutScreen());
  Future<void> _returnParts() => _openFlow(const ReturnPartsScreen());

  /// Opens a checkout/return screen; it pops with a confirmation message on success.
  Future<void> _openFlow(Widget screen) async {
    final done = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (done != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    }
    _load();
  }

  void _openItem(RecordModel r) {
    final category = r.getStringValue('category');
    _open(InventoryListScreen(
      department: r.getStringValue('department'),
      category: category.isEmpty ? 'Uncategorized' : category,
    ));
  }

  /// The signature moment: stock health as a gauge that fills on load,
  /// split into in-stock / running low / out segments.
  Widget _gauge() {
    final out = _items.where(_out).length;
    final low = _items.where(_low).length;
    final ok = _items.length - out - low;
    final headline = _items.isEmpty
        ? 'No parts yet'
        : (out + low == 0
            ? 'All ${_items.length} parts in stock'
            : '${out + low} of ${_items.length} parts need restock');

    Widget legend(IconData icon, Color color, int n, String label) => Expanded(
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text('$n', style: mono.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: C.text)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: C.muted)),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            HealthBar(ok: ok, low: low, out: out, okColor: C.ok, height: 8),
            const SizedBox(height: 12),
            Row(
              children: [
                legend(Icons.check_circle_outline, C.ok, ok, 'in stock'),
                legend(Icons.trending_down, C.warn, low, 'low'),
                legend(Icons.remove_circle_outline, C.danger, out, 'out'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(RecordModel r) {
    final out = _out(r);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openItem(r),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              IconTile(
                categoryIcon(r.getStringValue('category').isEmpty ? 'uncategorized' : r.getStringValue('category')),
                C.dept(r.getStringValue('department')),
                size: 36,
              ),
              const SizedBox(width: 12),
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
                    SectionTitle('Results', trailing: '${results.length}'),
                    if (results.isEmpty)
                      Text('No part matches "${_search.text.trim()}".', style: TextStyle(color: C.muted)),
                    for (final r in results) _itemRow(r),
                  ] else if (_error != null && _items.isEmpty) ...[
                    // Never show "No parts / all stocked" when we simply couldn't ask
                    const SizedBox(height: 48),
                    Icon(Icons.cloud_off_outlined, size: 44, color: C.muted),
                    const SizedBox(height: 16),
                    Text("Can't reach Horizon",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                    const SizedBox(height: 20),
                    Center(
                      child: SubmitButton(
                        onPressed: _load,
                        child: const Text('Try again'),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    // Twin actions: same size, side by side. Orange takes parts out, green brings them back.
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _bulkCheckout,
                            icon: const Icon(Icons.shopping_basket_outlined, size: 20),
                            label: const Text('Check out'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _returnParts,
                            icon: const Icon(Icons.assignment_return_outlined, size: 20),
                            label: const Text('Return'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: C.ok,
                              foregroundColor: C.p.onAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _gauge(),
                    const SectionTitle('Departments'),
                    for (final (name, blurb) in _departments) ...() {
                      final dept = _items.where((r) => r.getStringValue('department') == name).toList();
                      final out = dept.where(_out).length;
                      final low = dept.where(_low).length;
                      final tone = C.dept(name);
                      return [
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => _open(CategoryScreen(department: name)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      IconTile(deptIcon(name), tone, size: 44),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name,
                                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 2),
                                            Text(blurb, style: TextStyle(color: C.muted, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.arrow_forward, color: tone, size: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  HealthBar(ok: dept.length - out - low, low: low, out: out, okColor: tone, height: 4),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text('${dept.length}', style: mono.copyWith(fontSize: 13)),
                                      Text(' parts', style: TextStyle(fontSize: 13, color: C.muted)),
                                      const Spacer(),
                                      if (out + low > 0) ...[
                                        Icon(Icons.trending_down, size: 14, color: C.warn),
                                        const SizedBox(width: 4),
                                        Text('${out + low} need restock',
                                            style: TextStyle(fontSize: 13, color: C.warn)),
                                      ] else
                                        Text('all stocked', style: TextStyle(fontSize: 13, color: C.muted)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ];
                    }(),
                    SectionTitle('Running low', trailing: lowList.isEmpty ? null : '${lowList.length}'),
                    if (lowList.isEmpty)
                      Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: C.ok, size: 20),
                          const SizedBox(width: 8),
                          Text('Everything is well stocked.', style: TextStyle(color: C.muted)),
                        ],
                      )
                    else
                      for (final r in lowList.take(6)) _itemRow(r),
                  ],
                ],
              ),
            ),
    );
  }
}
