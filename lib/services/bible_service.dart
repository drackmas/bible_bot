import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/translation.dart';
import '../models/verse.dart';
import 'translation_service.dart';

class BibleService {
  static const String defaultVersion = 'KJV';

  static final Map<
      String,
      Map<String, List<Verse>>> _cache = {};

  static final Map<String, List<String>>
      _bookListCache = {};

  static Future<List<BibleTranslation>>
      loadAvailableVersions() async {
    return TranslationService.load();
  }

  static Future<BibleTranslation> getTranslation(
    String? version,
  ) async {
    return TranslationService.get(
      version ?? defaultVersion,
    );
  }

  static Future<String> _resolveFileName(
    String versionId,
  ) async {
    final translation =
        await TranslationService.get(
      versionId,
    );

    return translation.file;
  }

  static Future<List<Verse>> loadBook(
    String bookName, {
    String? version,
  }) async {
    final ver =
        await TranslationService.normalize(
      version,
    );

    final normalizedBook =
        normalizeBookName(bookName);

    final versionCache = _cache[ver];

    if (versionCache != null &&
        versionCache.containsKey(normalizedBook)) {
      return versionCache[normalizedBook]!;
    }

    final fileName =
        await _resolveFileName(ver);

    final file = File(
      p.join('assets', fileName),
    );

    if (!await file.exists()) {
      throw StateError(
        'Bible file not found: $fileName',
      );
    }

    final decoded = jsonDecode(
      await file.readAsString(),
    );

    if (decoded is! Map) {
      throw StateError(
        '$fileName contains invalid Bible JSON.',
      );
    }

    final data =
        Map<String, dynamic>.from(decoded);

    final books =
        data['books'] as List? ?? [];

    Map<String, dynamic>? found;

    for (final rawBook in books) {
      if (rawBook is! Map) {
        continue;
      }

      final currentName =
          rawBook['name']?.toString() ?? '';

      final normalizedCurrent =
          normalizeBookName(currentName);

      if (normalizedCurrent.toLowerCase() ==
          normalizedBook.toLowerCase()) {
        found =
            Map<String, dynamic>.from(
          rawBook,
        );
        break;
      }
    }

    if (found == null) {
      throw StateError(
        'Book "$bookName" was not found in $ver.',
      );
    }

    final verses = <Verse>[];

    final chapters =
        found['chapters'] as List? ?? [];

    for (final rawChapter in chapters) {
      if (rawChapter is! Map) {
        continue;
      }

      final chapterNumber =
          int.tryParse(
        rawChapter['chapter']?.toString() ?? '',
      );

      if (chapterNumber == null) {
        continue;
      }

      final chapterVerses =
          rawChapter['verses'] as List? ?? [];

      for (final rawVerse in chapterVerses) {
        if (rawVerse is! Map) {
          continue;
        }

        final verseNumber =
            int.tryParse(
          rawVerse['verse']?.toString() ?? '',
        );

        final text =
            rawVerse['text']?.toString();

        if (verseNumber == null ||
            text == null) {
          continue;
        }

        verses.add(
          Verse(
            chapter: chapterNumber,
            verse: verseNumber,
            text: text,
          ),
        );
      }
    }

    verses.sort(
      (a, b) {
        final chapterCompare =
            a.chapter.compareTo(b.chapter);

        if (chapterCompare != 0) {
          return chapterCompare;
        }

        return a.verse.compareTo(b.verse);
      },
    );

    _cache.putIfAbsent(
      ver,
      () => {},
    );

    _cache[ver]![normalizedBook] =
        verses;

    return verses;
  }

  static Future<List<Verse>> getVerseRange(
    String book,
    int chapter,
    int start,
    int end, {
    String? version,
  }) async {
    if (chapter < 1) {
      throw StateError(
        'Chapter must be at least 1.',
      );
    }

    if (start < 1) {
      throw StateError(
        'Verse must be at least 1.',
      );
    }

    if (end < start) {
      throw StateError(
        'Ending verse cannot be before starting verse.',
      );
    }

    final verses = await loadBook(
      book,
      version: version,
    );

    final result = verses
        .where(
          (verse) =>
              verse.chapter == chapter &&
              verse.verse >= start &&
              verse.verse <= end,
        )
        .toList();

    if (result.isEmpty) {
      throw StateError(
        '$book $chapter:$start-$end was not found.',
      );
    }

    return result;
  }

  static Future<List<Verse>> getChapter(
    String book,
    int chapter, {
    String? version,
  }) async {
    if (chapter < 1) {
      throw StateError(
        'Chapter must be at least 1.',
      );
    }

    final verses = await loadBook(
      book,
      version: version,
    );

    final result = verses
        .where(
          (verse) =>
              verse.chapter == chapter,
        )
        .toList();

    if (result.isEmpty) {
      throw StateError(
        '$book $chapter was not found.',
      );
    }

    return result;
  }

  static Future<List<String>> loadBookList({
    String? version,
  }) async {
    final ver =
        await TranslationService.normalize(
      version,
    );

    final cached =
        _bookListCache[ver];

    if (cached != null) {
      return cached;
    }

    final fileName =
        await _resolveFileName(ver);

    final file = File(
      p.join('assets', fileName),
    );

    if (!await file.exists()) {
      throw StateError(
        'Bible file not found: $fileName',
      );
    }

    final decoded = jsonDecode(
      await file.readAsString(),
    );

    if (decoded is! Map) {
      throw StateError(
        '$fileName contains invalid JSON.',
      );
    }

    final data =
        Map<String, dynamic>.from(decoded);

    final books =
        data['books'] as List? ?? [];

    final names = <String>[];

    for (final rawBook in books) {
      if (rawBook is! Map) {
        continue;
      }

      final name =
          rawBook['name']?.toString();

      if (name != null &&
          name.isNotEmpty) {
        names.add(name);
      }
    }

    _bookListCache[ver] = names;

    return names;
  }

  static Future<List<Verse>> search(
    String query, {
    String? book,
    String? version,
  }) async {
    final normalizedQuery =
        query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return [];
    }

    final results = <Verse>[];

    if (book != null) {
      final verses = await loadBook(
        normalizeBookName(book),
        version: version,
      );

      for (final verse in verses) {
        if (verse.text
            .toLowerCase()
            .contains(normalizedQuery)) {
          results.add(verse);
        }
      }

      return results;
    }

    final books =
        await loadBookList(
      version: version,
    );

    for (final bookName in books) {
      final verses = await loadBook(
        bookName,
        version: version,
      );

      for (final verse in verses) {
        if (verse.text
            .toLowerCase()
            .contains(normalizedQuery)) {
          results.add(verse);
        }
      }
    }

    return results;
  }

  static String normalizeBookName(
    String input,
  ) {
    final map = <String, String>{
      'gen': 'Genesis',
      'genesis': 'Genesis',
      'ex': 'Exodus',
      'exo': 'Exodus',
      'exodus': 'Exodus',
      'lev': 'Leviticus',
      'leviticus': 'Leviticus',
      'num': 'Numbers',
      'numbers': 'Numbers',
      'deut': 'Deuteronomy',
      'deuteronomy': 'Deuteronomy',
      'josh': 'Joshua',
      'joshua': 'Joshua',
      'judg': 'Judges',
      'judges': 'Judges',
      'ruth': 'Ruth',
      '1sam': '1Samuel',
      '1samuel': '1Samuel',
      '2sam': '2Samuel',
      '2samuel': '2Samuel',
      '1king': '1Kings',
      '1kings': '1Kings',
      '2king': '2Kings',
      '2kings': '2Kings',
      '1chron': '1Chronicles',
      '1chronicles': '1Chronicles',
      '2chron': '2Chronicles',
      '2chronicles': '2Chronicles',
      'ezra': 'Ezra',
      'neh': 'Nehemiah',
      'nehemiah': 'Nehemiah',
      'est': 'Esther',
      'esther': 'Esther',
      'job': 'Job',
      'ps': 'Psalms',
      'psalm': 'Psalms',
      'psalms': 'Psalms',
      'prov': 'Proverbs',
      'proverbs': 'Proverbs',
      'eccl': 'Ecclesiastes',
      'ecclesiastes': 'Ecclesiastes',
      'song': 'SongofSolomon',
      'songofsolomon': 'SongofSolomon',
      'songofsongs': 'SongofSolomon',
      'isa': 'Isaiah',
      'isaiah': 'Isaiah',
      'jer': 'Jeremiah',
      'jeremiah': 'Jeremiah',
      'lam': 'Lamentations',
      'lamentations': 'Lamentations',
      'ezek': 'Ezekiel',
      'ezekiel': 'Ezekiel',
      'dan': 'Daniel',
      'daniel': 'Daniel',
      'hos': 'Hosea',
      'hosea': 'Hosea',
      'joel': 'Joel',
      'amos': 'Amos',
      'obad': 'Obadiah',
      'obadiah': 'Obadiah',
      'jonah': 'Jonah',
      'mic': 'Micah',
      'micah': 'Micah',
      'nah': 'Nahum',
      'nahum': 'Nahum',
      'hab': 'Habakkuk',
      'habakkuk': 'Habakkuk',
      'zeph': 'Zephaniah',
      'zephaniah': 'Zephaniah',
      'hag': 'Haggai',
      'haggai': 'Haggai',
      'zech': 'Zechariah',
      'zechariah': 'Zechariah',
      'mal': 'Malachi',
      'malachi': 'Malachi',
      'matt': 'Matthew',
      'mat': 'Matthew',
      'matthew': 'Matthew',
      'mk': 'Mark',
      'mark': 'Mark',
      'luke': 'Luke',
      'lk': 'Luke',
      'john': 'John',
      'jn': 'John',
      'acts': 'Acts',
      'act': 'Acts',
      'rom': 'Romans',
      'romans': 'Romans',
      '1cor': '1Corinthians',
      '1corinthians': '1Corinthians',
      '2cor': '2Corinthians',
      '2corinthians': '2Corinthians',
      'gal': 'Galatians',
      'galatians': 'Galatians',
      'eph': 'Ephesians',
      'ephesians': 'Ephesians',
      'phil': 'Philippians',
      'philippians': 'Philippians',
      'col': 'Colossians',
      'colossians': 'Colossians',
      '1thess': '1Thessalonians',
      '1thessalonians': '1Thessalonians',
      '2thess': '2Thessalonians',
      '2thessalonians': '2Thessalonians',
      '1tim': '1Timothy',
      '1timothy': '1Timothy',
      '2tim': '2Timothy',
      '2timothy': '2Timothy',
      'tit': 'Titus',
      'titus': 'Titus',
      'philem': 'Philemon',
      'philemon': 'Philemon',
      'heb': 'Hebrews',
      'hebrews': 'Hebrews',
      'james': 'James',
      'jas': 'James',
      '1pet': '1Peter',
      '1peter': '1Peter',
      '2pet': '2Peter',
      '2peter': '2Peter',
      '1john': '1John',
      '2john': '2John',
      '3john': '3John',
      'jude': 'Jude',
      'rev': 'Revelation',
      'revelation': 'Revelation',
    };

    final key = input
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'[\s._-]'),
          '',
        );

    return map[key] ?? input.trim();
  }
}
