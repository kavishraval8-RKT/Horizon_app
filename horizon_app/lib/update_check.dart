import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Members install the APK from GitHub Releases, so nothing updates it for them.
/// On launch, compare our version with the latest release and offer the download.

/// Set by build_release.sh from pubspec.yaml. Empty in debug builds: no check.
const appVersion = String.fromEnvironment('APP_VERSION');
const _repo = 'kavishraval8-RKT/Horizon_app';
const downloadUrl = 'https://github.com/$_repo/releases/latest/download/Horizon.apk';

/// "v1.10.0" > "1.9.2". Non-numeric parts count as 0.
bool isNewer(String latest, String current) {
  List<int> parts(String v) =>
      v.replaceFirst(RegExp(r'^v'), '').split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final a = parts(latest), b = parts(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

Future<void> checkForUpdate(BuildContext context) async {
  if (appVersion.isEmpty) return;
  try {
    final res = await http
        .get(Uri.parse('https://api.github.com/repos/$_repo/releases/latest'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return;
    final latest = (jsonDecode(res.body) as Map<String, dynamic>)['tag_name'] as String? ?? '';
    if (!isNewer(latest, appVersion) || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        content: Text('Horizon $latest is available (you have v$appVersion)'),
        action: SnackBarAction(
          label: 'Download',
          onPressed: () => launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication),
        ),
      ),
    );
  } catch (_) {
    // Offline or GitHub unreachable: try again next launch.
  }
}
