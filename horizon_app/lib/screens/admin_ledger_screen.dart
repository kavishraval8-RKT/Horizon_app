import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import '../theme.dart';

/// Every check-out, return, damage report and restock, newest first.
/// Lines from one bulk check-out/return share a `batch` tag and show as one entry.
class AdminLedgerScreen extends StatefulWidget {
  const AdminLedgerScreen({super.key});

  @override
  State<AdminLedgerScreen> createState() => _AdminLedgerScreenState();
}

/// One ledger entry: a single log, or every line of one bulk action.
class _Entry {
  final List<RecordModel> lines;
  _Entry(this.lines);
  RecordModel get first => lines.first;

  /// A return basket can mix good and damaged lines; it reads as one "returned" entry.
  String get action {
    final actions = lines.map((l) => l.getStringValue('action')).toSet();
    if (actions.length > 1 && actions.difference({'Returned', 'Returned Damaged'}).isEmpty) return 'Returned';
    return first.getStringValue('action');
  }

  bool get hasPhoto => lines.any((l) => l.getStringValue('photo').isNotEmpty);
  int get units => lines.fold(0, (n, l) => n + l.getIntValue('quantity'));
  int get parts => lines.map((l) => l.getStringValue('item')).toSet().length; // good + damaged of one part = 1
}

class _AdminLedgerScreenState extends State<AdminLedgerScreen> {
  final _pb = PocketBaseService();
  List<_Entry> _entries = [];
  bool _loading = true;
  String? _error;

  static final _when = DateFormat('MMM d · h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final logs = await _pb.client.collection('inventory_logs').getFullList(
            sort: '-created',
            expand: 'item,user',
          );
      // Group consecutive lines that share a batch tag (a bulk basket lands together)
      final entries = <_Entry>[];
      final byBatch = <String, _Entry>{};
      for (final l in logs) {
        final tag = l.getStringValue('batch');
        if (tag.isNotEmpty && byBatch.containsKey(tag)) {
          byBatch[tag]!.lines.add(l);
        } else {
          final e = _Entry([l]);
          entries.add(e);
          if (tag.isNotEmpty) byBatch[tag] = e;
        }
      }
      if (mounted) {
        setState(() {
          _entries = entries;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static (String verb, IconData icon, Color color) _style(String action) => switch (action) {
        'Checked Out' => ('checked out', Icons.north_east, C.accent),
        'Returned' => ('returned', Icons.south_west, C.ok),
        'Damaged' => ('reported damage on', Icons.report_gmailerrorred, C.danger),
        'Restocked' => ('restocked', Icons.add_box_outlined, C.text),
        'Returned Damaged' => ('returned damaged', Icons.broken_image_outlined, C.danger),
        _ => (action.toLowerCase(), Icons.info_outline, C.muted),
      };

  static String _who(RecordModel log) {
    final user = log.get<RecordModel?>('expand.user');
    if (user == null) return 'Someone';
    final name = user.getStringValue('name');
    return name.isNotEmpty ? name : user.getStringValue('email');
  }

  static String _item(RecordModel log) {
    final name = log.get<RecordModel?>('expand.item')?.getStringValue('name') ?? '';
    return name.isNotEmpty ? name : 'Deleted part';
  }

  static String _time(RecordModel log) {
    try {
      return _when.format(DateTime.parse(log.getStringValue('created')).toLocal());
    } catch (_) {
      return '';
    }
  }

  /// "MPU6050 ×2 · Teensy 4.1 ×1 · +2 more"
  static String _summary(_Entry e) {
    final parts = e.lines.map((l) => '${_item(l)} ×${l.getIntValue('quantity')}'
        '${l.getStringValue('action') == 'Returned Damaged' && e.action != 'Returned Damaged' ? ' (damaged)' : ''}').toList();
    return parts.length <= 3 ? parts.join(' · ') : '${parts.take(3).join(' · ')} · +${parts.length - 3} more';
  }

  Future<void> _open(_Entry e) async {
    final (verb, icon, color) = _style(e.action);
    final log = e.first;
    // Photos are private: viewing one needs a short-lived file token
    String? token;
    if (e.hasPhoto) {
      try {
        token = await _pb.client.files.getToken();
      } catch (_) {}
    }
    if (!mounted) return;

    String photoUrl(RecordModel l) =>
        _pb.client.files.getURL(l, l.getStringValue('photo'), token: token).toString();

    // Whole photo, never cropped; tap for full screen with pinch-to-zoom.
    Widget photo(RecordModel l) => GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (c) => Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Center(child: Image.network(photoUrl(l), fit: BoxFit.contain)),
                    ),
                  ),
                  SafeArea(
                    child: IconButton(
                      onPressed: () => Navigator.pop(c),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: double.infinity,
              color: C.tint(C.muted, 0.12),
              constraints: const BoxConstraints(maxHeight: 360),
              child: Image.network(
                photoUrl(l),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => SizedBox(
                  height: 100,
                  child: Center(child: Icon(Icons.broken_image_outlined, color: C.muted)),
                ),
              ),
            ),
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(icon, color, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_who(log)} $verb', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        Text(_time(log), style: TextStyle(color: C.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in e.lines) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(_item(l))),
                            if (l.getStringValue('action') == 'Returned Damaged' && e.action != 'Returned Damaged')
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: StatusTag('Damaged', C.danger, icon: Icons.broken_image_outlined),
                              ),
                            Text('×${l.getIntValue('quantity')}', style: mono.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      if (l.getStringValue('notes').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('“${l.getStringValue('notes')}”', style: TextStyle(color: C.muted)),
                        ),
                      if (l.getStringValue('photo').isNotEmpty)
                        Padding(padding: const EdgeInsets.only(bottom: 10), child: photo(l)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(_Entry e) {
    final (verb, icon, color) = _style(e.action);
    final multi = e.lines.length > 1;
    final damaged = e.lines
        .where((l) => l.getStringValue('action') == 'Returned Damaged')
        .fold(0, (n, l) => n + l.getIntValue('quantity'));
    final headline = multi
        ? '$verb ${e.parts} part${e.parts == 1 ? '' : 's'} · ${e.units} units'
            '${damaged > 0 && e.action == 'Returned' ? ' ($damaged damaged)' : ''}'
        : '$verb ${_item(e.first)} ×${e.units}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _open(e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon, color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: _who(e.first), style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: ' $headline', style: TextStyle(color: color == C.text ? C.text : color)),
                      ]),
                    ),
                    if (multi) ...[
                      const SizedBox(height: 4),
                      Text(_summary(e),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: C.text)),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(_time(e.first), style: TextStyle(fontSize: 12, color: C.muted)),
                        if (e.hasPhoto) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.photo_camera_outlined, size: 14, color: C.muted),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: C.muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ledger')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null && _entries.isEmpty) ...[
                    const SizedBox(height: 48),
                    Icon(Icons.cloud_off_outlined, size: 44, color: C.muted),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                    const SizedBox(height: 16),
                    Center(child: SubmitButton(onPressed: _load, child: const Text('Try again'))),
                  ] else if (_entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Text('Nothing has been checked out yet.',
                          textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                    )
                  else
                    for (final e in _entries) _card(e),
                ],
              ),
            ),
    );
  }
}
