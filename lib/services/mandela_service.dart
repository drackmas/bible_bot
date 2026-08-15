import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/commentary.dart';

class MandelaService {
  static Map<String, Map<String, Commentary>>? _cache;

  static Future<void> _ensureLoaded() async {
    if (_cache != null) {
      return;
    }

    final file = File(
      p.join(
        'assets',
        'mandela_effect.json',
      ),
    );

    if (!await file.exists()) {
      _cache = {};
      return;
    }

    final raw = await file.readAsString();

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      _cache = {};
      return;
    }

    final data =
        Map<String, dynamic>.from(decoded);

    final rawCommentaries =
        data['commentaries'];

    if (rawCommentaries is! Map) {
      _cache = {};
      return;
    }

    final commentaries =
        Map<String, dynamic>.from(
      rawCommentaries,
    );

    final result =
        <String, Map<String, Commentary>>{};

    for (final entry in commentaries.entries) {
      final book = entry.key;
      final values = entry.value;

      if (values is! List) {
        continue;
      }

      final bookMap =
          <String, Commentary>{};

      for (final item in values) {
        if (item is! Map) {
          continue;
        }

        final commentary =
            Commentary.fromJson(
          Map<String, dynamic>.from(item),
        );

        if (commentary.chapter < 1 ||
            commentary.verse < 1) {
          continue;
        }

        final key = _key(
          commentary.chapter,
          commentary.verse,
        );

        bookMap[key] = commentary;
      }

      result[book] = bookMap;
    }

    _cache = result;
  }

  static String _key(
    int chapter,
    int verse,
  ) {
    return '$chapter:$verse';
  }

  static Future<Commentary?> get(
    String book,
    int chapter,
    int verse,
  ) async {
    await _ensureLoaded();

    final byVerse = _cache?[book];

    if (byVerse == null) {
      return null;
    }

    return byVerse[
      _key(chapter, verse)
    ];
  }

  static Future<Map<int, Commentary>> getChapter(
    String book,
    int chapter,
  ) async {
    await _ensureLoaded();

    final byVerse = _cache?[book];

    if (byVerse == null) {
      return {};
    }

    final result =
        <int, Commentary>{};

    for (final commentary
        in byVerse.values) {
      if (commentary.chapter == chapter) {
        result[commentary.verse] =
            commentary;
      }
    }

    return result;
  }

  /*
   * Useful while debugging the data file.
   *
   * This does not expose anything to Discord.
   */
  static Future<bool> hasCommentary(
    String book,
    int chapter,
    int verse,
  ) async {
    final commentary = await get(
      book,
      chapter,
      verse,
    );

    return commentary != null;
  }

  /*
   * Allows the application to force a reload if
   * mandela_effect.json is changed while the bot
   * is running.
   */
  static void clearCache() {
    _cache = null;
  }
}
