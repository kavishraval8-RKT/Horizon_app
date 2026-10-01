import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import '../theme.dart';

/// Everything the signed-in member currently has out (their check-outs minus returns),
/// returned in one batch: all lines go back together, or none do.
/// The server re-checks each line against the member's own ledger (pb_hooks/inventory.pb.js).
class ReturnPartsScreen extends StatefulWidget {
  const ReturnPartsScreen({super.key});

  @override
  State<ReturnPartsScreen> createState() => _ReturnPartsScreenState();
}

class _Held {
  final RecordModel item;
  final int out; // how many this member has out
  int qty; // how many they're returning now
  final String id; // record id for this return line, so a resend can't double up
  _Held(this.item, this.out, this.qty, this.id);
}

class _ReturnPartsScreenState extends State<ReturnPartsScreen> {
  final _pb = PocketBaseService();
  List<_Held> _held = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = _pb.currentUser?.id;
    if (me == null) return;
    try {
      final logs = await _pb.client.collection('inventory_logs').getFullList(
            filter: _pb.client.filter(
              'user = {:me} && (action = "Checked Out" || action = "Returned")',
              {'me': me},
            ),
            expand: 'item',
            fields: 'item,action,quantity,expand.item.id,expand.item.name,'
                'expand.item.category,expand.item.department',
          );

      final out = <String, int>{};
      final items = <String, RecordModel>{};
      for (final l in logs) {
        final item = l.get<RecordModel?>('expand.item');
        if (item == null) continue; // part was deleted since
        final q = l.getIntValue('quantity');
        out[item.id] = (out[item.id] ?? 0) + (l.getStringValue('action') == 'Returned' ? -q : q);
        items[item.id] = item;
      }

      final previous = {for (final h in _held) h.item.id: h};
      final held = [
        for (final e in out.entries)
          if (e.value > 0)
            _Held(
              items[e.key]!,
              e.value,
              // keep the member's chosen amount across refreshes; default to returning everything
              (previous[e.key]?.qty ?? e.value).clamp(0, e.value),
              previous[e.key]?.id ?? PocketBaseService.newId(),
            ),
      ]..sort((a, b) => a.item.getStringValue('name').compareTo(b.item.getStringValue('name')));

      if (mounted) {
        setState(() {
          _held = held;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _units => _held.fold(0, (s, h) => s + h.qty);
  int get _parts => _held.where((h) => h.qty > 0).length;

  void _toast(String msg, {bool error = false}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? C.danger : null));

  Future<void> _submit() async {
    final lines = _held.where((h) => h.qty > 0).toList();
    final me = _pb.currentUser?.id;
    if (lines.isEmpty || me == null) return;

    final batch = _pb.client.createBatch();
    for (final h in lines) {
      batch.collection('inventory_logs').create(body: {
        'id': h.id,
        'item': h.item.id,
        'user': me,
        'quantity': h.qty,
        'action': 'Returned',
      });
    }

    try {
      await batch.send();
      _done(lines.length);
    } on ClientException catch (e) {
      final failed = (e.response['data'] as Map?)?['requests'] as Map?;
      if (failed != null && failed.isNotEmpty) {
        final index = int.tryParse(failed.keys.first.toString()) ?? -1;
        final res = (failed.values.first as Map?)?['response'] as Map?;
        if (((res?['data'] as Map?)?['id'] as Map?)?['code'] == 'validation_not_unique') {
          return _done(lines.length); // went through on an earlier attempt
        }
        if (index >= 0 && index < lines.length) {
          _toast('Nothing was returned. ${lines[index].item.getStringValue('name')}: '
              '${res?['message'] ?? 'was rejected'}', error: true);
          _load();
          return;
        }
      }
      _toast(friendlyError(e), error: true);
    } catch (e) {
      _toast(friendlyError(e), error: true);
    }
  }

  void _done(int parts) {
    if (!mounted) return;
    Navigator.of(context).pop('Returned $parts part${parts == 1 ? '' : 's'}');
  }

  Widget _row(_Held h) {
    final dept = h.item.getStringValue('department');
    final category = h.item.getStringValue('category');
    Widget btn(IconData icon, VoidCallback? onTap) => InkResponse(
          onTap: onTap,
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 18, color: onTap == null ? C.line : C.text),
          ),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: h.qty > 0 ? C.ok : C.line),
      ),
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
                  Text(h.item.getStringValue('name'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'You have '),
                      TextSpan(text: '${h.out}', style: mono.copyWith(color: C.text)),
                      if (category.isNotEmpty || dept.isNotEmpty)
                        TextSpan(text: ' · ${[dept, category].where((s) => s.isNotEmpty).join(' · ')}'),
                    ]),
                    style: TextStyle(color: C.muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: h.qty > 0 ? C.ok : C.line),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  btn(Icons.remove, h.qty > 0 ? () => setState(() => h.qty--) : null),
                  SizedBox(
                    width: 28,
                    child: Text('${h.qty}',
                        textAlign: TextAlign.center,
                        style: mono.copyWith(fontWeight: FontWeight.w600, color: h.qty > 0 ? C.text : C.muted)),
                  ),
                  btn(Icons.add, h.qty < h.out ? () => setState(() => h.qty++) : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _held.isNotEmpty && _held.every((h) => h.qty == h.out);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Return parts'),
        actions: [
          if (_held.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                for (final h in _held) {
                  h.qty = allSelected ? 0 : h.out;
                }
              }),
              child: Text(allSelected ? 'Clear' : 'Return all'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (_error != null && _held.isEmpty) ...[
                    const SizedBox(height: 48),
                    Icon(Icons.cloud_off_outlined, size: 44, color: C.muted),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                    const SizedBox(height: 16),
                    Center(child: SubmitButton(onPressed: _load, child: const Text('Try again'))),
                  ] else if (_held.isEmpty) ...[
                    const SizedBox(height: 48),
                    Icon(Icons.check_circle_outline, size: 44, color: C.ok),
                    const SizedBox(height: 12),
                    Text("You don't have any parts checked out.",
                        textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Set how many of each you are bringing back.',
                          style: TextStyle(color: C.muted, fontSize: 13)),
                    ),
                    for (final h in _held) _row(h),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: _held.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.line))),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SubmitButton(
                    onPressed: _units == 0 ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: C.ok, foregroundColor: C.p.onAccent),
                    child: Text(_units == 0
                        ? 'Choose what to return'
                        : 'Return $_units unit${_units == 1 ? '' : 's'} · $_parts part${_parts == 1 ? '' : 's'}'),
                  ),
                ),
              ),
            ),
    );
  }
}
