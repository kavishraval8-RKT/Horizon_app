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

    // Re-fetch the user so role changes apply without logging out and in again.
    if (_pb.authStore.isValid) {
      try {
        await _pb.collection('users').authRefresh();
      } on ClientException catch (e) {
        // 0 = offline/server down: keep the cached login. Anything else = token is dead.
        if (e.statusCode != 0) _pb.authStore.clear();
      }
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
}
