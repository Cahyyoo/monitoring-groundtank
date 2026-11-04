import 'dart:convert';
import 'dart:ffi' show Abi;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A published version, with the APK that fits this phone.
@immutable
class AppRelease {
  const AppRelease({
    required this.version,
    required this.notes,
    required this.apkUrl,
    required this.sizeBytes,
  });

  /// Without the tag's leading `v`.
  final String version;
  final String notes;
  final String apkUrl;
  final int sizeBytes;
}

/// Whether [candidate] is a later version than [current], compared number by
/// number so that 1.10.0 comes after 1.9.0. A leading `v` and a `+build` or
/// `-suffix` are ignored; anything else unreadable is never "newer".
bool isNewerVersion(String candidate, String current) {
  List<int>? parts(String version) {
    final core = version
        .trim()
        .replaceFirst(RegExp('^v'), '')
        .split(RegExp(r'[+-]'));
    final numbers = core.first.split('.').map(int.tryParse).toList();
    if (numbers.contains(null)) return null;
    return [...numbers.nonNulls, 0, 0, 0].take(3).toList();
  }

  final a = parts(candidate);
  final b = parts(current);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// The asset name `flutter build apk --split-per-abi` gives this phone's
/// architecture; a release must upload the files under these names.
String? apkNameFor(Abi abi) => switch (abi) {
  Abi.androidArm64 => 'app-arm64-v8a-release.apk',
  Abi.androidArm => 'app-armeabi-v7a-release.apk',
  Abi.androidX64 => 'app-x86_64-release.apk',
  _ => null,
};

/// Reads a GitHub release. Null when it has no version or no APK for [abi].
AppRelease? parseRelease(Map<String, dynamic> json, Abi abi) {
  final tag = json['tag_name'];
  final name = apkNameFor(abi);
  final assets = json['assets'];
  if (tag is! String || name == null || assets is! List) return null;

  for (final asset in assets) {
    if (asset is! Map<String, dynamic> || asset['name'] != name) continue;
    final url = asset['browser_download_url'];
    if (url is! String) return null;
    final body = json['body'];
    final size = asset['size'];
    return AppRelease(
      version: tag.replaceFirst(RegExp('^v'), ''),
      notes: body is String ? body.trim() : '',
      apkUrl: url,
      sizeBytes: size is int ? size : 0,
    );
  }
  return null;
}

/// Asks GitHub whether a version newer than [currentVersion] is out.
///
/// Null covers every failure too: offline, no release yet, GitHub's rate
/// limit. Someone watching a tank has no use for hearing about those.
Future<AppRelease?> fetchNewerRelease(
  String currentVersion, {
  http.Client? client,
  Abi? abi,
}) async {
  const url =
      'https://api.github.com/repos/Cahyyoo/monitoring-groundtank/releases/latest';
  final http.Client httpClient = client ?? http.Client();
  try {
    final response = await httpClient
        .get(
          Uri.parse(url),
          headers: const {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      debugPrint('Update check: HTTP ${response.statusCode}');
      return null;
    }
    final release = parseRelease(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
      abi ?? Abi.current(),
    );
    if (release == null || !isNewerVersion(release.version, currentVersion)) {
      return null;
    }
    return release;
  } on Exception catch (e) {
    debugPrint('Update check failed: $e');
    return null;
  } finally {
    if (client == null) httpClient.close();
  }
}
