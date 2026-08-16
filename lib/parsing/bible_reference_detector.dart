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
        final references =
            <DetectedBibleReference>[];

        /*
         * Longest book names first.
         *
         * This is important for:
         *
         *     1 John 1:1
         *
         * so that it doesn't get detected as:
         *
         *     John 1:1
         */
        final sortedBooks = [
            ..._books,
        ]..sort(
            (a, b) => b.length.compareTo(
                a.length,
            ),
        );

        for (final book in sortedBooks) {
            final escapedBook =
                RegExp.escape(book);

            /*
             * Detect:
             *
             * John 1
             * John 1:1
             * John 1:1-3
             */
            final pattern = RegExp(
                '\\b($escapedBook)\\s+'
                '(\\d+)'
                '(?:\\s*:\\s*(\\d+)'
                '(?:\\s*-\\s*(\\d+))?)?',
                caseSensitive: false,
            );

            for (final match
                in pattern.allMatches(message)) {
                final bookName =
                    match.group(1);

                final chapter =
                    match.group(2);

                final startVerse =
                    match.group(3);

                final endVerse =
                    match.group(4);

                if (bookName == null ||
                    chapter == null) {
                    continue;
                }

                /*
                 * Determine whether this is a full chapter.
                 */
                final isFullChapter =
                    startVerse == null;

                /*
                 * Build the basic reference.
                 */
                final buffer =
                    StringBuffer();

                buffer.write(
                    '$bookName $chapter',
                );

                if (startVerse != null) {
                    buffer.write(
                        ':$startVerse',
                    );

                    if (endVerse != null) {
                        buffer.write(
                            '-$endVerse',
                        );
                    }
                }

                /*
                 * Look immediately after the match
                 * for a possible translation.
                 *
                 * Example:
                 *
                 * John 1:1 KJV
                 *          ^^^
                 */
                String? translation;

                final matchEnd =
                    match.end;

                final remaining =
                    message.substring(
                        matchEnd,
                    );

                final translationMatch =
                    RegExp(
                        r'^\s+([A-Za-z0-9]+)\b',
                    ).firstMatch(
                        remaining,
                    );

                if (translationMatch != null) {
                    final possibleTranslation =
                        translationMatch.group(1);

                    if (possibleTranslation !=
                            null &&
                        await TranslationService
                            .exists(
                                possibleTranslation,
                            )) {
                        translation =
                            possibleTranslation;
                    }
                }

                if (translation != null) {
                    buffer.write(
                        ' $translation',
                    );
                }

                final reference =
                    DetectedBibleReference(
                        text: buffer.toString(),
                        isFullChapter:
                            isFullChapter,
                    );

                /*
                 * Don't add the same reference twice.
                 */
                final duplicate =
                    references.any(
                        (existing) =>
                            existing.text
                                .toLowerCase() ==
                            reference.text
                                .toLowerCase(),
                    );

                if (duplicate) {
                    continue;
                }

                references.add(
                    reference,
                );

                /*
                 * Don't allow automatic messages
                 * to generate unlimited responses.
                 */
                if (references.length >=
                    maxAutomaticReferences) {
                    return references;
                }
            }
        }

        return references;
    }
}
