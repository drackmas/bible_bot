import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/commentary.dart';
import '../models/tag.dart';

class MandelaService {
  static Map<String, Map<String, Commentary>>? _cache;

  static List<BibleTag>? _tags;

  static Future<void> _ensureLoaded() async {
    if (_cache != null && _tags != null) {
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
      _tags = [];
      return;
    }

    final raw = await file.readAsString();

    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      _cache = {};
      _tags = [];
      return;
    }

    final data =
        Map<String, dynamic>.from(decoded);

    _loadCommentaries(data);

    _loadTags(data);
  }

  static void _loadCommentaries(
    Map<String, dynamic> data,
  ) {
    final commentaries =
        data['commentaries']
            as Map<String, dynamic>? ??
        {};

    final result =
        <String, Map<String, Commentary>>{};

    for (final entry
        in commentaries.entries) {
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
          Map<String, dynamic>.from(
            item,
          ),
        );

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

  static void _loadTags(
    Map<String, dynamic> data,
  ) {
    final rawTags =
        data['tags'] as List? ?? [];

    final result = <BibleTag>[];

    for (final item in rawTags) {
      if (item is! Map) {
        continue;
      }

      final tag = BibleTag.fromJson(
        Map<String, dynamic>.from(
          item,
        ),
      );

      if (tag.searchTerms.isEmpty) {
        continue;
      }

      result.add(tag);
    }

    _tags = result;
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
      _key(
        chapter,
        verse,
      )
    ];
  }

  static Future<Map<int, Commentary>>
      getChapter(
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
      if (commentary.chapter ==
          chapter) {
        result[commentary.verse] =
            commentary;
      }
    }

    return result;
  }

  /// Returns every global tag from
  /// mandela_effect.json.
  static Future<List<BibleTag>>
      getTags() async {
    await _ensureLoaded();

    return List.unmodifiable(
      _tags ?? const [],
    );
  }

  /// Returns global tags whose phrase or
  /// one of their variants actually occurs
  /// in [text].
  ///
  /// This is case-insensitive and uses
  /// whole-word/whole-phrase matching.
  static Future<List<BibleTag>>
      findTagsInText(
    String text,
  ) async {
    await _ensureLoaded();

    final result = <BibleTag>[];

    for (final tag in _tags ?? const []) {
      if (_tagOccursInText(
        text,
        tag,
      )) {
        result.add(tag);
      }
    }

    return result;
  }

  static bool _tagOccursInText(
    String text,
    BibleTag tag,
  ) {
    for (final term
        in tag.searchTerms) {
      if (_containsWholePhrase(
        text,
        term,
      )) {
        return true;
      }
    }

    return false;
  }

  static bool _containsWholePhrase(
    String text,
    String target,
  ) {
    final value =
        target.trim();

    if (value.isEmpty) {
      return false;
    }

    final pattern = RegExp(
      r'(?<![A-Za-z0-9])' +
          RegExp.escape(value) +
          r'(?![A-Za-z0-9])',
      caseSensitive: false,
    );

    return pattern.hasMatch(text);
  }
}
