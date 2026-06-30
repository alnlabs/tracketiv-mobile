import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists last successful API payloads for offline read access.
class OfflineCache {
  OfflineCache({Directory? directory}) : _directory = directory;

  Directory? _directory;

  Future<Directory> _dir() async {
    _directory ??= await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${_directory!.path}/offline_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  String _safeKey(String key) => key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  Future<void> setJsonList(String key, List<Map<String, dynamic>> rows) async {
    final file = File('${(await _dir()).path}/${_safeKey(key)}.json');
    await file.writeAsString(jsonEncode({'items': rows}));
  }

  Future<List<Map<String, dynamic>>?> getJsonList(String key) async {
    final file = File('${(await _dir()).path}/${_safeKey(key)}.json');
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) return null;
    final items = decoded['items'];
    if (items is! List) return null;
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    final file = File('${(await _dir()).path}/${_safeKey(key)}.json');
    await file.writeAsString(jsonEncode(value));
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final file = File('${(await _dir()).path}/${_safeKey(key)}.json');
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }
}
