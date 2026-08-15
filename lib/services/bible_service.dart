import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/verse.dart';

class BibleService {
  static String defaultVersion = 'AKJV';

  // versionId → bookName → List<Verse>
  static final Map<String, Map<String, List<Verse>>> _cache = {};

  static Future<List<Map<String, dynamic>>> loadAvailableVersions() async {
    final file = File(p.join('assets', 'referencebibles.json'));
    if (!await file.exists()) {
      throw Exception('assets/referencebibles.json not found');
    }
    final data = jsonDecode(await file.readAsString()) as List;
    return data.cast<Map<String, dynamic>>();
  }

  static Future<String> _resolveFileName(String versionId) async {
    final versions = await loadAvailableVersions();
    final match = versions.firstWhere(
      (v) => v['id'].toString().toUpperCase() == versionId.toUpperCase(),
      orElse: () => throw Exception('Unknown version: $versionId'),
    );
    return match['file'] as String;
  }

  static Future<List<Verse>> loadBook(
    String bookName, {
    String? version,
  }) async {
    final ver = (version ?? defaultVersion).toUpperCase();

    if (_cache[ver]?[bookName] != null) {
      return _cache[ver]![bookName]!;
    }

    final fileName = await _resolveFileName(ver);
    final file = File(p.join('assets', fileName));

    if (!await file.exists()) {
      throw Exception('Bible file not found: $fileName');
    }

    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final books = data['books'] as List? ?? [];

    Map<String, dynamic>? found;
    for (final b in books) {
      if (b is Map &&
          b['name'].toString().toLowerCase() == bookName.toLowerCase()) {
        found = Map<String, dynamic>.from(b);
        break;
      }
    }

    if (found == null) {
      throw Exception('Book "$bookName" not found in $ver');
    }

    final verses = <Verse>[];
    final chapters = found['chapters'] as List? ?? [];

    for (final ch in chapters) {
      if (ch is! Map) continue;
      final chapterNum = int.tryParse(ch['chapter'].toString());
      if (chapterNum == null) continue;

      final chVerses = ch['verses'] as List? ?? [];
      for (final v in chVerses) {
        if (v is! Map) continue;
        final verseNum = int.tryParse(v['verse'].toString());
        final text = v['text']?.toString();
        if (verseNum == null || text == null) continue;

        verses.add(Verse(
          chapter: chapterNum,
          verse: verseNum,
          text: text,
        ));
      }
    }

    _cache.putIfAbsent(ver, () => {});
    _cache[ver]![bookName] = verses;
    return verses;
  }

  static Future<List<Verse>> getVerseRange(
    String book,
    int chapter,
    int start, [
    int? end,
    String? version,
  ]) async {
    final verses = await loadBook(book, version: version);
    final endVerse = end ?? start;
    return verses
        .where((v) =>
            v.chapter == chapter &&
            v.verse >= start &&
            v.verse <= endVerse)
        .toList();
  }

  static Future<List<Verse>> getChapter(
    String book,
    int chapter, {
    String? version,
  }) async {
    final verses = await loadBook(book, version: version);
    return verses.where((v) => v.chapter == chapter).toList();
  }

  static Future<List<Verse>> search(
    String query, {
    String? book,
    String? version,
  }) async {
    final results = <Verse>[];
    final q = query.toLowerCase();

    // For simplicity we only search the requested book or the whole Bible of one version
    if (book != null) {
      final verses = await loadBook(book, version: version);
      for (final v in verses) {
        if (v.text.toLowerCase().contains(q)) results.add(v);
      }
    } else {
      // Search across all books is expensive – limit for now
      final books = await loadBookList(version: version);
      for (final b in books.take(20)) { // safety limit
        try {
          final verses = await loadBook(b, version: version);
          for (final v in verses) {
            if (v.text.toLowerCase().contains(q)) results.add(v);
          }
        } catch (_) {}
      }
    }
    return results;
  }

  static Future<List<String>> loadBookList({String? version}) async {
    final ver = (version ?? defaultVersion).toUpperCase();
    final fileName = await _resolveFileName(ver);
    final file = File(p.join('assets', fileName));
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final books = data['books'] as List? ?? [];
    return books
        .whereType<Map>()
        .map((b) => b['name']?.toString())
        .whereType<String>()
        .toList();
  }

  static String normalizeBookName(String input) {
    final map = {
      'gen': 'Genesis', 'genesis': 'Genesis',
      'ex': 'Exodus', 'exo': 'Exodus', 'exodus': 'Exodus',
      'lev': 'Leviticus', 'leviticus': 'Leviticus',
      'num': 'Numbers', 'numbers': 'Numbers',
      'deut': 'Deuteronomy', 'deuteronomy': 'Deuteronomy',
      'josh': 'Joshua', 'joshua': 'Joshua',
      'judg': 'Judges', 'judges': 'Judges',
      'ruth': 'Ruth',
      '1sam': '1Samuel', '1samuel': '1Samuel',
      '2sam': '2Samuel', '2samuel': '2Samuel',
      '1kings': '1Kings', '1king': '1Kings',
      '2kings': '2Kings', '2king': '2Kings',
      '1chron': '1Chronicles', '1chronicles': '1Chronicles',
      '2chron': '2Chronicles', '2chronicles': '2Chronicles',
      'ezra': 'Ezra',
      'neh': 'Nehemiah', 'nehemiah': 'Nehemiah',
      'est': 'Esther', 'esther': 'Esther',
      'job': 'Job',
      'ps': 'Psalms', 'psalm': 'Psalms', 'psalms': 'Psalms',
      'prov': 'Proverbs', 'proverbs': 'Proverbs',
      'eccl': 'Ecclesiastes', 'ecclesiastes': 'Ecclesiastes',
      'song': 'SongofSolomon', 'songofsolomon': 'SongofSolomon',
      'isa': 'Isaiah', 'isaiah': 'Isaiah',
      'jer': 'Jeremiah', 'jeremiah': 'Jeremiah',
      'lam': 'Lamentations', 'lamentations': 'Lamentations',
      'ezek': 'Ezekiel', 'ezekiel': 'Ezekiel',
      'dan': 'Daniel', 'daniel': 'Daniel',
      'hos': 'Hosea', 'hosea': 'Hosea',
      'joel': 'Joel',
      'amos': 'Amos',
      'obad': 'Obadiah', 'obadiah': 'Obadiah',
      'jonah': 'Jonah',
      'mic': 'Micah', 'micah': 'Micah',
      'nah': 'Nahum', 'nahum': 'Nahum',
      'hab': 'Habakkuk', 'habakkuk': 'Habakkuk',
      'zeph': 'Zephaniah', 'zephaniah': 'Zephaniah',
      'hag': 'Haggai', 'haggai': 'Haggai',
      'zech': 'Zechariah', 'zechariah': 'Zechariah',
      'mal': 'Malachi', 'malachi': 'Malachi',
      'matt': 'Matthew', 'mat': 'Matthew', 'matthew': 'Matthew',
      'mark': 'Mark', 'mk': 'Mark',
      'luke': 'Luke', 'lk': 'Luke',
      'john': 'John', 'jn': 'John',
      'acts': 'Acts', 'act': 'Acts',
      'rom': 'Romans', 'romans': 'Romans',
      '1cor': '1Corinthians', '1corinthians': '1Corinthians',
      '2cor': '2Corinthians', '2corinthians': '2Corinthians',
      'gal': 'Galatians', 'galatians': 'Galatians',
      'eph': 'Ephesians', 'ephesians': 'Ephesians',
      'phil': 'Philippians', 'philippians': 'Philippians',
      'col': 'Colossians', 'colossians': 'Colossians',
      '1thess': '1Thessalonians', '1thessalonians': '1Thessalonians',
      '2thess': '2Thessalonians', '2thessalonians': '2Thessalonians',
      '1tim': '1Timothy', '1timothy': '1Timothy',
      '2tim': '2Timothy', '2timothy': '2Timothy',
      'tit': 'Titus', 'titus': 'Titus',
      'philem': 'Philemon', 'philemon': 'Philemon',
      'heb': 'Hebrews', 'hebrews': 'Hebrews',
      'james': 'James', 'jas': 'James',
      '1pet': '1Peter', '1peter': '1Peter',
      '2pet': '2Peter', '2peter': '2Peter',
      '1john': '1John', '2john': '2John', '3john': '3John',
      'jude': 'Jude',
      'rev': 'Revelation', 'revelation': 'Revelation',
    };

    final key = input.trim().toLowerCase().replaceAll(RegExp(r'[\s._-]'), '');
    return map[key] ?? input.trim();
  }
}
