import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

final _log = Logger('CacheService');

class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  Future<String> get _dir async {
    final d = await getApplicationSupportDirectory();
    return d.path;
  }

  Future<void> save(String key, List<Map<String, dynamic>> data) async {
    try {
      final path = await _dir;
      await File('$path/atc_$key.json')
          .writeAsString(jsonEncode(data), flush: true);
    } catch (e, s) {
      _log.warning('save($key) failed', e, s);
    }
  }

  Future<List<Map<String, dynamic>>?> load(String key) async {
    try {
      final path = await _dir;
      final file = File('$path/atc_$key.json');
      if (!await file.exists()) return null;
      final list = jsonDecode(await file.readAsString()) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e, s) {
      _log.warning('load($key) failed', e, s);
      return null;
    }
  }
}
