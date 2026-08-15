import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/commentary.dart';

class MandelaService {
  static Map<String, List<Commentary>>? _cache;

  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;

    final file = File(p.join('assets', 'mandela_effect.json'));
    if (!await file.exists()) {
      _cache = {};
      return;
    }

    final raw = await file.readAsString();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final commentaries = data['commentaries'] as Map<String, dynamic>? ?? {};

    _cache = {};
    for (final entry in commentaries.entries) {
      final book = entry.key;
      final list = (entry.value as List)
          .map((e) => Commentary.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache![book] = list;
    }
  }

  static Future<Commentary?> get(
    String book,
    int chapter,
    int verse,
  ) async {
    await _ensureLoaded();
    final list = _cache?[book];
    if (list == null) return null;

    try {
      return list.firstWhere(
        (c) => c.chapter == chapter && c.verse == verse,
      );
    } catch (_) {
      return null;
    }
  }
}
