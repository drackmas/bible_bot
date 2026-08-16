import '../models/bible_reference.dart';
import '../services/bible_service.dart';
import '../services/translation_service.dart';

class BibleReferenceParser {
  static Future<BibleReference> parse(
    String input,
  ) async {
    var cleaned = input
        .trim()
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        );

    if (cleaned.isEmpty) {
      throw const FormatException(
        'A Bible reference is required.\n\n'
        '**Example:**\n'
        '`!bible lookup Genesis 1:1`',
      );
    }

    var translation =
        TranslationService.defaultTranslation;

    final parts = cleaned.split(' ');

    if (parts.length >= 2) {
      final possibleTranslation =
          parts.last;

      if (await TranslationService.exists(
        possibleTranslation,
      )) {
        translation =
            possibleTranslation;

        parts.removeLast();

        cleaned =
            parts.join(' ').trim();
      }
    }

    if (cleaned.isEmpty) {
      throw const FormatException(
        'A Bible reference is required.\n\n'
        '**Example:**\n'
        '`!bible lookup Genesis 1:1`',
      );
    }

    final rangeMatch = RegExp(
      r'^(.+?)\s+(\d+)\s*:\s*(\d+)\s*-\s*(\d+)$',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (rangeMatch != null) {
      final bookRaw =
          rangeMatch.group(1)!.trim();

      final chapter =
          int.parse(
        rangeMatch.group(2)!,
      );

      final start =
          int.parse(
        rangeMatch.group(3)!,
      );

      final end =
          int.parse(
        rangeMatch.group(4)!,
      );

      if (chapter < 1) {
        throw const FormatException(
          'Chapter must be at least **1**.',
        );
      }

      if (start < 1 ||
          end < 1) {
        throw const FormatException(
          'Verse numbers must be at least **1**.',
        );
      }

      if (end < start) {
        throw const FormatException(
          'The ending verse cannot be before '
          'the starting verse.',
        );
      }

      return BibleReference(
        book: BibleService.normalizeBookName(
          bookRaw,
        ),
        chapter: chapter,
        startVerse: start,
        endVerse: end,
        translation: translation,
      );
    }

    final verseMatch = RegExp(
      r'^(.+?)\s+(\d+)\s*:\s*(\d+)$',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (verseMatch != null) {
      final bookRaw =
          verseMatch.group(1)!.trim();

      final chapter =
          int.parse(
        verseMatch.group(2)!,
      );

      final verse =
          int.parse(
        verseMatch.group(3)!,
      );

      if (chapter < 1) {
        throw const FormatException(
          'Chapter must be at least **1**.',
        );
      }

      if (verse < 1) {
        throw const FormatException(
          'Verse must be at least **1**.',
        );
      }

      return BibleReference(
        book: BibleService.normalizeBookName(
          bookRaw,
        ),
        chapter: chapter,
        startVerse: verse,
        endVerse: verse,
        translation: translation,
      );
    }

    final chapterMatch = RegExp(
      r'^(.+?)\s+(\d+)$',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (chapterMatch != null) {
      final bookRaw =
          chapterMatch.group(1)!.trim();

      final chapter =
          int.parse(
        chapterMatch.group(2)!,
      );

      if (chapter < 1) {
        throw const FormatException(
          'Chapter must be at least **1**.',
        );
      }

      return BibleReference(
        book: BibleService.normalizeBookName(
          bookRaw,
        ),
        chapter: chapter,
        startVerse: 1,
        endVerse: null,
        translation: translation,
      );
    }

    throw const FormatException(
      'I could not understand that Bible reference.\n\n'
      '**Examples:**\n'
      '`!bible lookup Genesis 1:1`\n'
      '`!bible lookup John 3:16`\n'
      '`!bible lookup Revelation 1:1`\n'
      '`!bible lookup Genesis 1:1 BSB`\n'
      '`!bible lookup John 3:16-18`',
    );
  }
}
