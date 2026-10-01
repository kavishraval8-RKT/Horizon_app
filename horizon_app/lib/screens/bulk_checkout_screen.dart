import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import '../theme.dart';

/// Check out several parts from any department in one go.
/// The basket is sent as one PocketBase batch, which runs in a single transaction:
/// every line is checked out, or (if any line fails) none are.
class BulkCheckoutScreen extends StatefulWidget {
  const BulkCheckoutScreen({super.key});

  static const maxParts = 10;

  @override
  State<BulkCheckoutScreen> createState() => _BulkCheckoutScreenState();
}

class _Line {
  final RecordModel item;
  int qty;
  final String id; // stable per line (kept across refreshes), so a resend can't double up
  _Line(this.item, this.qty, [String? id]) : id = id ?? PocketBaseService.newId();
}

class _BulkCheckoutScreenState extends State<BulkCheckoutScreen> {
  final _pb = PocketBaseService();
  final _search = TextEditingController();
  List<RecordModel> _items = [];
  final _basket = <String, _Line>{}; // item id -> line, in the order added
  String _dept = 'All';
  bool _loading = true;
  String? _error;
  String? _failedItemId; // the line the server rejected, highlighted until it changes

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

  Future<void> _load() async {
    try {
      final items = await _pb.client.collection('inventory').getFullList(
            sort: 'name',
            fields: 'id,name,department,category,available_quantity,total_quantity',
          );
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        // Refresh basket lines with current stock; trim quantities that no longer fit
        for (final line in _basket.values.toList()) {
          final fresh = items.where((i) => i.id == line.item.id).firstOrNull;
          if (fresh == null || _avail(fresh) == 0) {
            _basket.remove(line.item.id);
          } else {
            _basket[line.item.id] = _Line(fresh, line.qty.clamp(1, _avail(fresh)), line.id);
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int _avail(RecordModel r) => r.getIntValue('available_quantity');

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? C.danger : null));
  }

  void _add(RecordModel item) {
    if (_basket.length >= BulkCheckoutScreen.maxParts) {
      _toast('Up to ${BulkCheckoutScreen.maxParts} different parts per checkout');
      return;
    }
    setState(() => _basket[item.id] = _Line(item, 1));
  }

  void _setQty(RecordModel item, int qty) {
    setState(() {
      if (item.id == _failedItemId) _failedItemId = null;
      if (qty <= 0) {
        _basket.remove(item.id);
      } else {
        _basket[item.id]!.qty = qty.clamp(1, _avail(item));
      }
    });
  }

  int get _units => _basket.values.fold(0, (sum, l) => sum + l.qty);

  Future<void> _submit() async {
    final lines = _basket.values.toList();
    final userId = _pb.currentUser?.id;
    if (lines.isEmpty || userId == null) return;

    final batch = _pb.client.createBatch();
    for (final l in lines) {
      batch.collection('inventory_logs').create(body: {
        'id': l.id,
        'item': l.item.id,
        'user': userId,
        'quantity': l.qty,
        'action': 'Checked Out',
      });
    }

    try {
      await batch.send();
      _done(lines);
    } on ClientException catch (e) {
      // The server names the failing line: data.requests.{index}.response
      final failed = (e.response['data'] as Map?)?['requests'] as Map?;
      if (failed != null && failed.isNotEmpty) {
        final index = int.tryParse(failed.keys.first.toString()) ?? -1;
        final res = (failed.values.first as Map?)?['response'] as Map?;
        final dupId = ((res?['data'] as Map?)?['id'] as Map?)?['code'] == 'validation_not_unique';
        // An already-used line id means this basket went through on an earlier attempt
        if (dupId) return _done(lines);
        if (index >= 0 && index < lines.length) {
          final name = lines[index].item.getStringValue('name');
          final why = res?['message'] ?? 'was rejected';
          setState(() => _failedItemId = lines[index].item.id);
          if (mounted) Navigator.of(context).pop(); // close the review sheet
          _toast('Nothing was checked out. $name: $why', error: true);
          _load(); // show current stock
          return;
        }
      }
      if (mounted) _toast(friendlyError(e), error: true);
    } catch (e) {
      if (mounted) _toast(friendlyError(e), error: true);
    }
  }

  void _done(List<_Line> lines) {
    if (!mounted) return;
    setState(_basket.clear);
    // Both pops are synchronous and in order: review sheet first, then this screen with
    // the message for the home screen. (maybePop is async: it used to lose this race.)
    Navigator.of(context)
      ..pop()
      ..pop('Checked out ${lines.length} part${lines.length == 1 ? '' : 's'}');
  }

  Widget _stepper(RecordModel item, int qty) {
    Widget btn(IconData icon, VoidCallback? onTap) => InkResponse(
          onTap: onTap,
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: onTap == null ? C.line : C.text),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: C.accent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(qty == 1 ? Icons.delete_outline : Icons.remove, () => _setQty(item, qty - 1)),
          SizedBox(
            width: 28,
            child: Text('$qty', textAlign: TextAlign.center, style: mono.copyWith(fontWeight: FontWeight.w600)),
          ),
          btn(Icons.add, qty < _avail(item) ? () => _setQty(item, qty + 1) : null),
        ],
      ),
    );
  }

  Widget _row(RecordModel item) {
    final line = _basket[item.id];
    final avail = _avail(item);
    final dept = item.getStringValue('department');
    final category = item.getStringValue('category');
    final failed = item.id == _failedItemId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: failed ? C.danger : (line != null ? C.accent : C.line)),
      ),
      child: InkWell(
        onTap: line == null && avail > 0 ? () => _add(item) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              IconTile(categoryIcon(category.isEmpty ? 'uncategorized' : category), C.dept(dept), size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.getStringValue('name'),
                        style: TextStyle(fontWeight: FontWeight.w500, color: avail == 0 ? C.muted : C.text)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '$avail', style: mono.copyWith(color: avail == 0 ? C.danger : C.text)),
                        TextSpan(text: ' available · ${[dept, category].where((s) => s.isNotEmpty).join(' · ')}'),
                      ]),
                      style: TextStyle(color: C.muted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (line != null)
                _stepper(item, line.qty)
              else if (avail == 0)
                Text('Out', style: TextStyle(color: C.danger, fontSize: 13))
              else
                Icon(Icons.add_circle_outline, color: C.accent),
            ],
          ),
        ),
      ),
    );
  }

  void _review() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final lines = _basket.values.toList();
          void change(RecordModel item, int qty) {
            _setQty(item, qty);
            setSheet(() {});
            if (_basket.isEmpty) Navigator.pop(sheetContext);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Check out ${lines.length} part${lines.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('All of these are checked out together, or none are.',
                      style: TextStyle(color: C.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final l in lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                IconTile(categoryIcon(l.item.getStringValue('category')),
                                    C.dept(l.item.getStringValue('department')),
                                    size: 32),
                                const SizedBox(width: 12),
                                Expanded(child: Text(l.item.getStringValue('name'))),
                                StatefulBuilder(
                                  builder: (_, _) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(l.qty == 1 ? Icons.delete_outline : Icons.remove, size: 18),
                                        onPressed: () => change(l.item, l.qty - 1),
                                      ),
                                      Text('${l.qty}', style: mono.copyWith(fontWeight: FontWeight.w600)),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.add, size: 18),
                                        onPressed: l.qty < _avail(l.item) ? () => change(l.item, l.qty + 1) : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SubmitButton(
                    onPressed: _submit,
                    child: Text('Check out $_units unit${_units == 1 ? '' : 's'}'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final shown = _items
        .where((r) => _dept == 'All' || r.getStringValue('department') == _dept)
        .where((r) => q.isEmpty || r.getStringValue('name').toLowerCase().contains(q))
        .toList();

    Widget chip(String label) {
      final on = _dept == label;
      final tone = label == 'All' ? C.accent : C.dept(label);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => _dept = label),
          child: AnimatedContainer(
            duration: motion(context, 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? C.tint(tone, 0.2) : Colors.transparent,
              border: Border.all(color: on ? tone : C.line),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: on ? tone : C.muted)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Check out parts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.cloud_off_outlined, size: 44, color: C.muted),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                      const SizedBox(height: 16),
                      SubmitButton(onPressed: _load, child: const Text('Try again')),
                    ]),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _search,
                        decoration: InputDecoration(
                          hintText: 'Search parts',
                          prefixIcon: Icon(Icons.search, color: C.muted, size: 20),
                          suffixIcon: q.isEmpty
                              ? null
                              : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _search.clear),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(children: [chip('All'), chip('Avionics'), chip('Mechanical')]),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: shown.isEmpty
                            ? ListView(children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 48),
                                  child: Text('No parts match.',
                                      textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                                ),
                              ])
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                children: [for (final r in shown) _row(r)],
                              ),
                      ),
                    ),
                  ],
                ),
      // Basket bar slides up once something is in it
      bottomNavigationBar: AnimatedSize(
        duration: motion(context, 240),
        curve: easeOutExpo,
        child: _basket.isEmpty
            ? const SizedBox(width: double.infinity)
            : Container(
                decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_basket_outlined, color: C.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${_basket.length}', style: mono.copyWith(fontWeight: FontWeight.w600)),
                              TextSpan(text: ' part${_basket.length == 1 ? '' : 's'} · '),
                              TextSpan(text: '$_units', style: mono.copyWith(fontWeight: FontWeight.w600)),
                              TextSpan(text: ' unit${_units == 1 ? '' : 's'}'),
                            ]),
                            style: TextStyle(color: C.text),
                          ),
                        ),
                        ElevatedButton(onPressed: _review, child: const Text('Review')),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
