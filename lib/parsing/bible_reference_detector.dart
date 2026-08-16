import '../services/bible_service.dart';
import '../services/translation_service.dart';

class DetectedBibleReference {
  final String text;
  final bool isFullChapter;

  const DetectedBibleReference({
    required this.text,
    required this.isFullChapter,
  });
}

class BibleReferenceDetector {
  static const int maxAutomaticReferences = 5;

  /*
   * Bible books ordered from longest/more specific names
   * to shorter names.
   *
   * This prevents things like:
   *
   *     1 John 3:16
   *
   * from being incorrectly detected as:
   *
   *     John 3:16
   */
  static const List<String> _books = [
    '1 Chronicles',
    '2 Chronicles',
    '1 Corinthians',
    '2 Corinthians',
    '1 Thessalonians',
    '2 Thessalonians',
    '1 Timothy',
    '2 Timothy',
    '1 Peter',
    '2 Peter',
    '1 John',
    '2 John',
    '3 John',

    'Song of Solomon',
    'Song of Songs',

    'Genesis',
    'Exodus',
    'Leviticus',
    'Numbers',
    'Deuteronomy',
    'Joshua',
    'Judges',
    'Ruth',
    '1 Samuel',
    '2 Samuel',
    '1 Kings',
    '2 Kings',
    'Ezra',
    'Nehemiah',
    'Esther',
    'Job',
    'Psalms',
    'Psalm',
    'Proverbs',
    'Ecclesiastes',
    'Isaiah',
    'Jeremiah',
    'Lamentations',
    'Ezekiel',
    'Daniel',
    'Hosea',
    'Joel',
    'Amos',
    'Obadiah',
    'Jonah',
    'Micah',
    'Nahum',
    'Habakkuk',
    'Zephaniah',
    'Haggai',
    'Zechariah',
    'Malachi',
    'Matthew',
    'Mark',
    'Luke',
    'John',
    'Acts',
    'Romans',
    'Galatians',
    'Ephesians',
    'Philippians',
    'Colossians',
    'Philemon',
    'Hebrews',
    'James',
    'Jude',
    'Revelation',
  ];

  static Future<List<DetectedBibleReference>> detect(
    String message,
  ) async {
    final references = <DetectedBibleReference>[];

    /*
     * We search for:
     *
     * Book Chapter
     *
     * Book Chapter:Verse
     *
     * Book Chapter:Verse-Verse
     *
     * with an optional translation ID.
     *
     * Example:
     *
     * Genesis 1
     * Genesis 1 KJV
     * Genesis 1:1
     * Genesis 1:1 KJV
     * Genesis 1:1-3 BSB
     */
    for (final book in _books) {
      final escapedBook = RegExp.escape(book);

      final pattern = RegExp(
        '\\b($escapedBook)\\s+'
        '(\\d+)'
        '(?:\\s*:\\s*(\\d+)\\s*'
        '(?:-\\s*(\\d+))?)?'
        '(?:\\s+([A-Za-z0-9]+))?',
        caseSensitive: false,
      );

      for (final match in pattern.allMatches(message)) {
        final fullMatch = match.group(0);

        if (fullMatch == null) {
          continue;
        }

        final chapter = match.group(2);
        final startVerse = match.group(3);
        final endVerse = match.group(4);
        final possibleTranslation = match.group(5);

        if (chapter == null) {
          continue;
        }

        /*
         * If the final word after the reference is something
         * like "says", "is", "and", etc., it obviously isn't
         * a Bible translation.
         *
         * Only accept it if it actually exists in
         * referencebibles.json.
         */
        String? translation;

        if (possibleTranslation != null &&
            await TranslationService.exists(
              possibleTranslation,
            )) {
          translation = possibleTranslation;
        }

        /*
         * Build the exact reference text that will be sent
         * to BibleReferenceParser.
         */
        final buffer = StringBuffer();

        buffer.write(
          '${match.group(1)} $chapter',
        );

        if (startVerse != null) {
          buffer.write(':$startVerse');

          if (endVerse != null) {
            buffer.write('-$endVerse');
          }
        }

        if (translation != null) {
          buffer.write(' $translation');
        }

        final referenceText = buffer.toString();

        /*
         * Make sure the reference isn't already contained
         * inside another detected reference.
         */
        final alreadyDetected = references.any(
          (existing) =>
              _referencesOverlap(
                existing.text,
                referenceText,
              ),
        );

        if (alreadyDetected) {
          continue;
        }

        references.add(
          DetectedBibleReference(
            text: referenceText,
            isFullChapter: startVerse == null,
          ),
        );

        /*
         * Don't allow an individual message to generate
         * an unlimited number of Bible responses.
         */
        if (references.length >= maxAutomaticReferences) {
          return references;
        }
      }
    }

    /*
     * Remove duplicate references.
     */
    final unique = <String, DetectedBibleReference>{};

    for (final reference in references) {
      final key = reference.text.toLowerCase();

      unique[key] = reference;
    }

    return unique.values.toList();
  }

  static bool _referencesOverlap(
    String first,
    String second,
  ) {
    return first.toLowerCase() == second.toLowerCase();
  }
}
