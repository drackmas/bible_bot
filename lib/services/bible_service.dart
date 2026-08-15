import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/verse.dart';

class BibleService {
  static const String _bibleFileName = 'AKJV.json';

  // Cache each book after it is loaded.
  static final Map<String, List<Verse>> _cache = {};

  // Cache the list of book names.
  static List<String>? _bookList;

  // ============================================================
  // Load the complete AKJV Bible JSON
  // ============================================================

  static Future<Map<String, dynamic>> _loadBibleJson() async {
    final file = File(
      p.join('assets', _bibleFileName),
    );

    if (!await file.exists()) {
      throw Exception(
        'assets/$_bibleFileName not found',
      );
    }

    final contents = await file.readAsString();

    final decoded = jsonDecode(contents);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Invalid $_bibleFileName format.',
      );
    }

    return decoded;
  }

  // ============================================================
  // Load list of books
  // ============================================================

  static Future<List<String>> loadBookList() async {
    if (_bookList != null) {
      return _bookList!;
    }

    final data = await _loadBibleJson();

    final books = data['books'];

    if (books is! List) {
      throw Exception(
        'No "books" array found in $_bibleFileName.',
      );
    }

    _bookList = books
        .whereType<Map<String, dynamic>>()
        .map(
          (book) => book['name']?.toString(),
        )
        .whereType<String>()
        .toList();

    return _bookList!;
  }

  // ============================================================
  // Load a single book from AKJV.json
  // ============================================================

  static Future<List<Verse>> loadBook(
    String bookName,
  ) async {
    // Return cached book if we already loaded it.
    if (_cache.containsKey(bookName)) {
      return _cache[bookName]!;
    }

    final data = await _loadBibleJson();

    final books = data['books'];

    if (books is! List) {
      throw Exception(
        'No "books" array found in $_bibleFileName.',
      );
    }

    Map<String, dynamic>? foundBook;

    for (final book in books) {
      if (book is! Map<String, dynamic>) {
        continue;
      }

      final name = book['name']?.toString();

      if (name == null) {
        continue;
      }

      if (name.toLowerCase() ==
          bookName.toLowerCase()) {
        foundBook = book;
        break;
      }
    }

    if (foundBook == null) {
      throw Exception(
        'Book not found: $bookName',
      );
    }

    final chapters = foundBook['chapters'];

    if (chapters is! List) {
      throw Exception(
        'No chapters found for $bookName.',
      );
    }

    final verses = <Verse>[];

    for (final chapterData in chapters) {
      if (chapterData is! Map<String, dynamic>) {
        continue;
      }

      final chapterNumber =
          int.tryParse(
        chapterData['chapter']?.toString() ?? '',
      );

      if (chapterNumber == null) {
        continue;
      }

      final chapterVerses =
          chapterData['verses'];

      if (chapterVerses is! List) {
        continue;
      }

      for (final verseData in chapterVerses) {
        if (verseData is! Map<String, dynamic>) {
          continue;
        }

        final verseNumber =
            int.tryParse(
          verseData['verse']?.toString() ?? '',
        );

        final text =
            verseData['text']?.toString();

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

    // Cache using the actual book name.
    _cache[bookName] = verses;

    return verses;
  }

  // ============================================================
  // Get a single verse
  // ============================================================

  static Future<Verse?> getVerse(
    String book,
    int chapter,
    int verse,
  ) async {
    final verses = await loadBook(book);

    try {
      return verses.firstWhere(
        (v) =>
            v.chapter == chapter &&
            v.verse == verse,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Get a range of verses
  //
  // Example:
  //
  // John 3:16-18
  // ============================================================

  static Future<List<Verse>> getVerseRange(
    String book,
    int chapter,
    int startVerse, [
    int? endVerse,
  ]) async {
    final verses = await loadBook(book);

    final end = endVerse ?? startVerse;

    return verses
        .where(
          (v) =>
              v.chapter == chapter &&
              v.verse >= startVerse &&
              v.verse <= end,
        )
        .toList();
  }

  // ============================================================
  // Get an entire chapter
  //
  // Example:
  //
  // John 3
  // ============================================================

  static Future<List<Verse>> getChapter(
    String book,
    int chapter,
  ) async {
    final verses = await loadBook(book);

    return verses
        .where(
          (v) => v.chapter == chapter,
        )
        .toList();
  }

  // ============================================================
  // Search
  //
  // !search love
  //
  // or:
  //
  // !search love Romans
  // ============================================================

  static Future<List<Verse>> search(
    String query, {
    String? book,
  }) async {
    final results = <Verse>[];

    final normalizedQuery =
        query.toLowerCase();

    final books = book != null
        ? [normalizeBookName(book)]
        : await loadBookList();

    for (final bookName in books) {
      try {
        final verses =
            await loadBook(bookName);

        for (final verse in verses) {
          if (verse.text
              .toLowerCase()
              .contains(normalizedQuery)) {
            results.add(verse);
          }
        }
      } catch (_) {
        // Ignore invalid/missing books.
      }
    }

    return results;
  }

  // ============================================================
  // Normalize book names
  //
  // Converts:
  //
  // john       -> John
  // 1 john     -> 1John
  // 1john      -> 1John
  // ps         -> Psalms
  // gen        -> Genesis
  // ============================================================

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

      '1kings': '1Kings',
      '1king': '1Kings',

      '2kings': '2Kings',
      '2king': '2Kings',

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

      'mark': 'Mark',
      'mk': 'Mark',

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

    final normalized =
        input
            .trim()
            .toLowerCase()
            .replaceAll(
              RegExp(r'[\s._-]'),
              '',
            );

    return map[normalized] ?? input.trim();
  }
}
