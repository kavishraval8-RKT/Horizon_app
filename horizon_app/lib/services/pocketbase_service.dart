import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  late final PocketBase _pb;
  bool _initialized = false;

  factory PocketBaseService() {
    return _instance;
  }

  PocketBaseService._internal();

  /// Initialize PocketBase with persistent auth storage
  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final store = AsyncAuthStore(
      save: (String data) async {
        await prefs.setString('pb_auth', data);
      },
      initial: prefs.getString('pb_auth'),
    );

    _pb = PocketBase(serverUrl, authStore: store);
    _initialized = true;

    // Re-fetch the user in the background so role changes apply without logging
    // in again. Not awaited: the app opens instantly even when offline.
    if (_pb.authStore.isValid) {
      _pb.collection('users').authRefresh().catchError((Object e) {
        // Only log out when the server rejects the token (e.g. password changed).
        // Offline, server off, Cloudflare 5xx: keep the saved login.
        if (e is ClientException && const [401, 403, 404].contains(e.statusCode)) {
          _pb.authStore.clear();
        }
        return RecordAuth();
      });
    }
  }

  /// Build with `--dart-define=PB_URL=https://your-server` for real devices.
  /// Defaults point at a PocketBase running on this computer.
  static String get serverUrl {
    const fromBuild = String.fromEnvironment('PB_URL');
    if (fromBuild.isNotEmpty) return fromBuild;
    // The Android emulator reaches the host computer at 10.0.2.2.
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8090'
        : 'http://127.0.0.1:8090';
  }

  PocketBase get client => _pb;

  /// Authenticate user with email and password
  Future<RecordAuth> login(String email, String password) async {
    try {
      final authData = await _pb.collection('users').authWithPassword(
            email,
            password,
          );
      return authData;
    } catch (e) {
      rethrow;
    }
  }

  /// Logout current user
  void logout() {
    _pb.authStore.clear();
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _pb.authStore.isValid;

  /// Get current user record
  RecordModel? get currentUser => _pb.authStore.record;

  /// Get authentication token
  String get token => _pb.authStore.token;

  /// Check if current user is an admin
  bool get isAdmin {
    try {
      final role = _pb.authStore.record?.get<String>('role');
      return role == 'admin';
    } catch (e) {
      return false;
    }
  }

  /// A record id made on the device when a form opens and sent with the create.
  /// If the same submit reaches the server twice (double tap, retry after a lost
  /// reply), the second is rejected as a duplicate instead of creating a copy.
  static String newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(15, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// True when the server says this id already exists, i.e. the submit already went through.
  static bool isDuplicate(Object e) =>
      e is ClientException && (e.response['data'] as Map?)?['id']?['code'] == 'validation_not_unique';

  /// Create a record at most once: a repeat of the same [id] counts as success.
  static Future<void> createOnce(RecordService collection, String id, Map<String, dynamic> body) async {
    try {
      await collection.create(body: {...body, 'id': id});
    } catch (e) {
      if (!isDuplicate(e)) rethrow;
    }
  }
}

/// Turns a failed request into something a member can act on.
String friendlyError(Object e) {
  if (e is ClientException) {
    final code = e.statusCode;
    if (code == 0) return 'No internet connection. Check your Wi-Fi or data and try again.';
    // 502/503/504 from the server, 520-530 from Cloudflare when the club server is off or unreachable
    if (code == 502 || code == 503 || code == 504 || (code >= 520 && code <= 530)) {
      return 'The Horizon server is offline right now. Try again in a few minutes.';
    }
    if (code == 401) return 'Your login has expired. Log out and back in.';
    final reason = serverReason(e.response);
    if (reason != null) return reason;
  }
  return 'Something went wrong. Please try again.';
}

/// The most specific reason in a PocketBase error body: a field's own message
/// (e.g. the photo's file type) beats the generic "Failed to create record."
String? serverReason(Map? response) {
  final fields = response?['data'];
  if (fields is Map) {
    for (final f in fields.values) {
      if (f is Map && f['message'] is String) return f['message'] as String;
    }
  }
  final msg = response?['message'];
  return msg is String && msg.isNotEmpty ? msg : null;
}
