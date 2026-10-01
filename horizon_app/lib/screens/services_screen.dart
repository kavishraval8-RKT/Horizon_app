import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import '../theme.dart';

IconData _equipmentIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('print')) return Icons.print_outlined;
  if (n.contains('solder')) return Icons.electrical_services;
  if (n.contains('drill') || n.contains('lathe') || n.contains('mill')) return Icons.precision_manufacturing_outlined;
  if (n.contains('laser') || n.contains('cut')) return Icons.content_cut;
  if (n.contains('scope') || n.contains('meter')) return Icons.monitor_heart_outlined;
  return Icons.handyman_outlined;
}

String _reason(Object e) =>
    e is ClientException ? (e.response['message'] ?? '$e').toString() : '$e';

/// Services: shared equipment that members book in time slots.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _pb = PocketBaseService();
  List<RecordModel> _equipment = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _pb.client.collection('equipment').getFullList(sort: 'name');
      if (mounted) setState(() => _equipment = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't load. ${friendlyError(e)}"), backgroundColor: C.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addEquipment() async {
    final name = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add equipment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. 3D printer'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Location, rules'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await _pb.client.collection('equipment').create(
        body: {'name': name.text.trim(), 'notes': notes.text.trim()},
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_reason(e)), backgroundColor: C.danger),
        );
      }
    }
  }

  Future<void> _deleteEquipment(RecordModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove equipment'),
        content: Text('Remove "${item.getStringValue('name')}" and all its bookings?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: C.danger, foregroundColor: C.text),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _pb.client.collection('equipment').delete(item.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_reason(e)), backgroundColor: C.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _pb.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('EQUIPMENT BOOKING',
                      style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  if (_equipment.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Text(
                        isAdmin
                            ? 'No equipment yet. Tap + to add the first one.'
                            : 'No bookable equipment yet. Ask an admin to add some.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: C.muted),
                      ),
                    ),
                  for (final item in _equipment) ...[
                    Card(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EquipmentBookingsScreen(equipment: item)),
                        ),
                        onLongPress: isAdmin ? () => _deleteEquipment(item) : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              IconTile(_equipmentIcon(item.getStringValue('name')), C.text, size: 40),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.getStringValue('name'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                    if (item.getStringValue('notes').isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(item.getStringValue('notes'),
                                          style: TextStyle(color: C.muted, fontSize: 13)),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: C.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _addEquipment,
              tooltip: 'Add equipment',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// Upcoming bookings for one piece of equipment, plus "Book a slot".
class EquipmentBookingsScreen extends StatefulWidget {
  final RecordModel equipment;
  const EquipmentBookingsScreen({super.key, required this.equipment});

  @override
  State<EquipmentBookingsScreen> createState() => _EquipmentBookingsScreenState();
}

class _EquipmentBookingsScreenState extends State<EquipmentBookingsScreen> {
  final _pb = PocketBaseService();
  List<RecordModel> _bookings = [];
  bool _loading = true;

  static final _day = DateFormat('EEE d MMM');
  static final _time = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: error ? C.danger : null),
      );

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _pb.client.collection('bookings').getFullList(
            filter: _pb.client.filter('equipment = {:eq} && end >= {:now}', {
              'eq': widget.equipment.id,
              'now': DateTime.now().toUtc(),
            }),
            sort: 'start',
            expand: 'user',
          );
      if (mounted) setState(() => _bookings = items);
    } catch (e) {
      if (mounted) _toast("Couldn't load. ${friendlyError(e)}", error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _local(RecordModel b, String field) =>
      DateTime.parse(b.getStringValue(field)).toLocal();

  String _who(RecordModel b) {
    final user = b.get<RecordModel?>('expand.user');
    if (user == null) return 'Someone';
    final name = user.getStringValue('name');
    return name.isNotEmpty ? name : user.getStringValue('email');
  }

  Future<void> _book() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final from = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour + 1 > 23 ? 23 : now.hour + 1, minute: 0),
      helpText: 'START TIME',
    );
    if (from == null || !mounted) return;
    final to = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: from.hour + 1 > 23 ? 23 : from.hour + 1, minute: from.minute),
      helpText: 'END TIME',
    );
    if (to == null || !mounted) return;

    final purpose = TextEditingController();
    final start = DateTime(date.year, date.month, date.day, from.hour, from.minute);
    final end = DateTime(date.year, date.month, date.day, to.hour, to.minute);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.equipment.getStringValue('name'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${_day.format(start)}  ${_time.format(start)}–${_time.format(end)}', style: mono),
            const SizedBox(height: 16),
            TextField(
              controller: purpose,
              decoration: const InputDecoration(labelText: 'Purpose (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Book')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // The server rejects overlaps and end-before-start (backend/pb_hooks/bookings.pb.js)
      await _pb.client.collection('bookings').create(body: {
        'equipment': widget.equipment.id,
        'user': _pb.currentUser?.id,
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'purpose': purpose.text.trim(),
      });
      if (mounted) _toast('Booked');
      _load();
    } catch (e) {
      if (mounted) _toast(_reason(e), error: true);
    }
  }

  Future<void> _cancel(RecordModel b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: C.danger, foregroundColor: C.text),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _pb.client.collection('bookings').delete(b.id);
      _load();
    } catch (e) {
      if (mounted) _toast(_reason(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _pb.currentUser?.id;
    final isAdmin = _pb.isAdmin;
    String? lastDay;

    return Scaffold(
      appBar: AppBar(title: Text(widget.equipment.getStringValue('name'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (_bookings.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Text('Free. No upcoming bookings.',
                          textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                    ),
                  for (final b in _bookings) ...() {
                    final start = _local(b, 'start');
                    final end = _local(b, 'end');
                    final day = _day.format(start);
                    final mine = b.getStringValue('user') == me;
                    final header = day != lastDay;
                    lastDay = day;
                    return [
                      if (header)
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(day.toUpperCase(),
                              style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
                        ),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(color: mine ? C.accent : C.line),
                        ),
                        child: InkWell(
                          onTap: (mine || isAdmin) ? () => _cancel(b) : null,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_time.format(start)}\n${_time.format(end)}',
                                    style: mono.copyWith(fontSize: 15, height: 1.4)),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(mine ? 'You' : _who(b),
                                          style: const TextStyle(fontWeight: FontWeight.w500)),
                                      if (b.getStringValue('purpose').isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(b.getStringValue('purpose'),
                                            style: TextStyle(color: C.muted, fontSize: 13)),
                                      ],
                                      if (mine || isAdmin) ...[
                                        const SizedBox(height: 6),
                                        Text('Tap to cancel',
                                            style: TextStyle(color: C.muted, fontSize: 11)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ];
                  }(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book,
        icon: const Icon(Icons.add),
        label: const Text('Book a slot'),
      ),
    );
  }
}
