import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';
import '../theme.dart';

/// User details + change password.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _pb = PocketBaseService();
  late final _nameController =
      TextEditingController(text: _pb.currentUser?.getStringValue('name'));
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _savingName = false;
  bool _savingPassword = false;

  @override
  void dispose() {
    for (final c in [_nameController, _oldPassword, _newPassword, _confirmPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? C.danger : null),
    );
  }

  String _reason(Object e) {
    if (e is! ClientException) return '$e';
    // Field errors (e.g. "oldPassword: Missing or invalid old password.") beat the generic message
    final data = e.response['data'];
    if (data is Map && data.isNotEmpty) {
      final first = data.values.first;
      if (first is Map && first['message'] != null) return first['message'];
    }
    return e.response['message'] ?? '$e';
  }

  Future<void> _saveName() async {
    final user = _pb.currentUser;
    if (user == null) return;
    setState(() => _savingName = true);
    try {
      // The SDK updates the stored login record when you update yourself.
      await _pb.client.collection('users').update(user.id, body: {
        'name': _nameController.text.trim(),
        'emailVisibility': true, // required field; old accounts may have it off
      });
      if (mounted) _toast('Name saved');
    } catch (e) {
      if (mounted) _toast(_reason(e), error: true);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _changePassword() async {
    final user = _pb.currentUser;
    if (user == null) return;
    if (_newPassword.text.length < 8) {
      _toast('New password must be at least 8 characters', error: true);
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      _toast("New passwords don't match", error: true);
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await _pb.client.collection('users').update(user.id, body: {
        'oldPassword': _oldPassword.text,
        'password': _newPassword.text,
        'passwordConfirm': _confirmPassword.text,
        'emailVisibility': true,
      });
      // Changing the password invalidates every login, including this one: sign straight back in.
      await _pb.login(user.getStringValue('email'), _newPassword.text);
      for (final c in [_oldPassword, _newPassword, _confirmPassword]) {
        c.clear();
      }
      if (mounted) _toast('Password changed. Other devices have been signed out.');
    } catch (e) {
      if (mounted) _toast(_reason(e), error: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 28),
        child: Text(text, style: TextStyle(color: C.muted, fontSize: 12, letterSpacing: 1.2)),
      );

  Widget _readout(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 72, child: Text(label, style: TextStyle(color: C.muted))),
            Expanded(child: Text(value)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = _pb.currentUser;
    final role = user?.getStringValue('role') ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _label('DETAILS'),
          _readout('Email', user?.getStringValue('email') ?? ''),
          _readout('Role', role.isEmpty ? 'member' : role),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _savingName ? null : _saveName,
              child: Text(_savingName ? 'Saving…' : 'Save name'),
            ),
          ),
          _label('CHANGE PASSWORD'),
          TextField(
            controller: _oldPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password (8+ characters)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirm new password'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _savingPassword ? null : _changePassword,
            child: Text(_savingPassword ? 'Changing…' : 'Change password'),
          ),
        ],
      ),
    );
  }
}
