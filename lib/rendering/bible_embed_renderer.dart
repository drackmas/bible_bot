import 'package:nyxx/nyxx.dart';

import '../models/commentary.dart';
import '../models/verse.dart';
import '../services/mandela_service.dart';

class BibleRenderPage {
  final List<Verse> verses;
  final String description;

  const BibleRenderPage({
    required this.verses,
    required this.description,
  });
}

class BibleEmbedRenderer {
  static const int descriptionLimit = 3900;

  static const DiscordColor bibleColor =
      DiscordColor(0x7850C8);

  static Future<List<BibleRenderPage>>
      renderPages({
    required String book,
    required int chapter,
    required String translation,
    required List<Verse> verses,
  }) async {
    final pages = <BibleRenderPage>[];

    var currentVerses = <Verse>[];
    var currentText = '';

    for (final verse in verses) {
      final rendered =
          await renderVerse(
        book: book,
        chapter: chapter,
        translation: translation,
        verse: verse,
      );

      final candidate =
          currentText.isEmpty
              ? rendered
              : '$currentText\n\n$rendered';

      if (candidate.length <=
          descriptionLimit) {
        currentVerses.add(verse);
        currentText = candidate;
        continue;
      }

      if (currentVerses.isNotEmpty) {
        pages.add(
          BibleRenderPage(
            verses: List.unmodifiable(
              currentVerses,
            ),
            description: currentText,
          ),
        );
      }

      currentVerses = [verse];
      currentText = rendered;

      if (currentText.length >
          descriptionLimit) {
        final chunks =
            splitOversized(currentText);

        for (var i = 0;
            i < chunks.length;
            i++) {
          pages.add(
            BibleRenderPage(
              verses: i == 0
                  ? [verse]
                  : const [],
              description: chunks[i],
            ),
          );
        }

        currentVerses = [];
        currentText = '';
      }
    }

    if (currentVerses.isNotEmpty) {
      pages.add(
        BibleRenderPage(
          verses: List.unmodifiable(
            currentVerses,
          ),
          description: currentText,
        ),
      );
    }

    if (pages.isEmpty) {
      pages.add(
        const BibleRenderPage(
          verses: [],
          description:
              'No verses were found.',
        ),
      );
    }

    return pages;
  }

  static Future<String> renderVerse({
    required String book,
    required int chapter,
    required String translation,
    required Verse verse,
  }) async {
    final isKjv =
        translation.toUpperCase() == 'KJV';

    Commentary? commentary;

    if (isKjv) {
      commentary =
          await MandelaService.get(
        book,
        chapter,
        verse.verse,
      );
    }

    var text =
        escapeDiscord(verse.text);

    if (isKjv &&
        commentary != null &&
        commentary.highlights.isNotEmpty) {
      text = applyHighlights(
        text,
        commentary.highlights,
      );
    }

    final buffer = StringBuffer();

    buffer.write(
      '**${verse.verse}** $text',
    );

    if (isKjv && commentary != null) {
      if (commentary.hashtags.isNotEmpty) {
        final tags =
            commentary.hashtags.map(
          (tag) {
            final emoji =
                tag.color.toLowerCase() ==
                        'red'
                    ? '🔴'
                    : '🟢';

            return '$emoji #${tag.text}';
          },
        ).join('  ');

        buffer
          ..write('\n')
          ..write(tags);
      }

      if (commentary.text.trim().isNotEmpty) {
        buffer
          ..write('\n')
          ..write(
            '> *${escapeDiscord(commentary.text.trim())}*',
          );
      }
    }

    return buffer.toString();
  }

  static EmbedBuilder buildEmbed({
    required String book,
    required int chapter,
    required String translation,
    required BibleRenderPage page,
    required int pageNumber,
    required int totalPages,
  }) {
    final verses = page.verses;

    String title;

    if (verses.isEmpty) {
      title = '$book $chapter';
    } else if (verses.length == 1) {
      title =
          '$book $chapter:${verses.first.verse}';
    } else {
      title =
          '$book $chapter:${verses.first.verse}-${verses.last.verse}';
    }

    return EmbedBuilder(
      title: title,
      description: page.description,
      color: bibleColor,
      footer: EmbedFooterBuilder(
        text:
            '${translation.toUpperCase()} • Page $pageNumber/$totalPages',
      ),
    );
  }

  static String applyHighlights(
    String text,
    List<Highlight> highlights,
  ) {
    final sorted =
        List<Highlight>.from(
          highlights,
        )..sort(
            (a, b) =>
                b.text.length.compareTo(
              a.text.length,
            ),
          );

    var result = text;

    for (final highlight in sorted) {
      final target =
          highlight.text.trim();

      if (target.isEmpty) {
        continue;
      }

      result = result.replaceAllMapped(
        RegExp(
          RegExp.escape(target),
          caseSensitive: false,
        ),
        (match) {
          return '**${match[0]}**';
        },
      );
    }

    return result;
  }

  static String escapeDiscord(
    String text,
  ) {
    return text
        .replaceAll(
          '\\',
          r'\\',
        )
        .replaceAll(
          '`',
          r'\`',
        );
  }

  static List<String> splitOversized(
    String text,
  ) {
    final result = <String>[];

    var remaining = text;

    while (remaining.length >
        descriptionLimit) {
      var splitAt =
          remaining.lastIndexOf(
        ' ',
        descriptionLimit,
      );

      if (splitAt <= 0) {
        splitAt = descriptionLimit;
      }

      result.add(
        remaining.substring(
          0,
          splitAt,
        ),
      );

      remaining =
          remaining.substring(
        splitAt,
      ).trimLeft();
    }

    if (remaining.isNotEmpty) {
      result.add(remaining);
    }

    return result;
  }
}
