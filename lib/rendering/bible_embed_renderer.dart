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

  static Future<List<BibleRenderPage>> renderPages({
    required String book,
    required int chapter,
    required String translation,
    required List<Verse> verses,
  }) async {
    final pages = <BibleRenderPage>[];

    var currentVerses = <Verse>[];
    var currentText = '';

    for (final verse in verses) {
      final rendered = await renderVerse(
        book: book,
        chapter: chapter,
        translation: translation,
        verse: verse,
      );

      final candidate = currentText.isEmpty
          ? rendered
          : '$currentText\n\n$rendered';

      if (candidate.length <= descriptionLimit) {
        currentVerses.add(verse);
        currentText = candidate;
        continue;
      }

      if (currentVerses.isNotEmpty) {
        pages.add(
          BibleRenderPage(
            verses: List.unmodifiable(currentVerses),
            description: currentText,
          ),
        );
      }

      currentVerses = [verse];
      currentText = rendered;

      if (currentText.length > descriptionLimit) {
        final chunks = splitOversized(currentText);

        for (var i = 0; i < chunks.length; i++) {
          pages.add(
            BibleRenderPage(
              verses: i == 0 ? [verse] : const [],
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
          verses: List.unmodifiable(currentVerses),
          description: currentText,
        ),
      );
    }

    if (pages.isEmpty) {
      pages.add(
        const BibleRenderPage(
          verses: [],
          description: 'No verses were found.',
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
    /*
     * Commentary/highlights only apply to KJV.
     *
     * This is deliberately based on the translation ID passed to the
     * renderer, not on the Bible file name.
     */
    final isKjv = translation.trim().toUpperCase() == 'KJV';

    Commentary? commentary;

    if (isKjv) {
      commentary = await MandelaService.get(
        book,
        chapter,
        verse.verse,
      );
    }

    /*
     * Always start highlighting from the ORIGINAL verse text.
     *
     * Do not highlight an already-highlighted string. Doing that causes
     * later highlights to interact with the ** markdown inserted by
     * earlier highlights.
     */
    final originalText = verse.text;

    final escapedText = escapeDiscord(originalText);

    final highlightedText = isKjv && commentary != null
        ? applyHighlights(
            escapedText,
            commentary.highlights,
          )
        : escapedText;

    final buffer = StringBuffer();

    buffer.write(
      '**${verse.verse}** $highlightedText',
    );

    /*
     * Commentary metadata is only displayed for KJV.
     */
    if (isKjv && commentary != null) {
      /*
       * Hashtags are separate from highlights.
       *
       * A hashtag appearing in the verse does NOT automatically become
       * a highlight. Only entries in "highlights" are verse highlights.
       */
      if (commentary.hashtags.isNotEmpty) {
        final hashtags = commentary.hashtags
            .map(
              (tag) {
                final color =
                    tag.color.trim().toLowerCase();

                final emoji = color == 'red'
                    ? '🔴'
                    : '🟢';

                return '$emoji #${tag.text.trim()}';
              },
            )
            .join('  ');

        buffer
          ..write('\n')
          ..write(hashtags);
      }

      /*
       * Commentary itself appears beneath the hashtags.
       */
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

  /*
   * Finds all highlight ranges against the ORIGINAL text and then builds
   * the final Markdown exactly once.
   *
   * This fixes the previous implementation's biggest problem:
   *
   *     text -> highlight A -> highlight B -> highlight C
   *
   * could cause B/C to match inside the "**" inserted by A.
   *
   * Instead we now do:
   *
   *     original text
   *          |
   *          +-- find A
   *          +-- find B
   *          +-- find C
   *          |
   *          v
   *     build final string once
   */
  static String applyHighlights(
    String text,
    List<Highlight> highlights,
  ) {
    if (text.isEmpty || highlights.isEmpty) {
      return text;
    }

    final ranges = <_HighlightRange>[];

    for (final highlight in highlights) {
      final target = highlight.text.trim();

      if (target.isEmpty) {
        continue;
      }

      final matches = _findMatches(
        text,
        target,
      );

      for (final match in matches) {
        ranges.add(
          _HighlightRange(
            start: match.start,
            end: match.end,
          ),
        );
      }
    }

    if (ranges.isEmpty) {
      return text;
    }

    /*
     * Sort by:
     *
     * 1. Starting position
     * 2. Longer match first when two matches start together
     */
    ranges.sort(
      (a, b) {
        final startCompare =
            a.start.compareTo(b.start);

        if (startCompare != 0) {
          return startCompare;
        }

        return b.end.compareTo(a.end);
      },
    );

    /*
     * Merge overlapping ranges.
     *
     * Example:
     *
     * "John the Baptist"
     * "John Baptist"
     *
     * should not produce broken nested Markdown.
     */
    final merged = <_HighlightRange>[];

    for (final range in ranges) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }

      final previous = merged.last;

      if (range.start <= previous.end) {
        if (range.end > previous.end) {
          merged[merged.length - 1] =
              _HighlightRange(
            start: previous.start,
            end: range.end,
          );
        }

        continue;
      }

      merged.add(range);
    }

    /*
     * Build the result once.
     */
    final buffer = StringBuffer();

    var cursor = 0;

    for (final range in merged) {
      if (range.start > cursor) {
        buffer.write(
          text.substring(
            cursor,
            range.start,
          ),
        );
      }

      buffer.write('**');

      buffer.write(
        text.substring(
          range.start,
          range.end,
        ),
      );

      buffer.write('**');

      cursor = range.end;
    }

    if (cursor < text.length) {
      buffer.write(
        text.substring(cursor),
      );
    }

    return buffer.toString();
  }

  /*
   * Finds case-insensitive occurrences of target.
   *
   * We intentionally do NOT use word boundaries here.
   *
   * Your data contains highlights such as:
   *
   *     ":"
   *     "repent: hath"
   *     "it? or"
   *
   * Word-boundary matching would break those.
   */
  static List<_HighlightMatch> _findMatches(
    String text,
    String target,
  ) {
    final matches = <_HighlightMatch>[];

    if (text.isEmpty || target.isEmpty) {
      return matches;
    }

    final lowerText = text.toLowerCase();
    final lowerTarget = target.toLowerCase();

    var searchStart = 0;

    while (searchStart <=
        lowerText.length - lowerTarget.length) {
      final index = lowerText.indexOf(
        lowerTarget,
        searchStart,
      );

      if (index == -1) {
        break;
      }

      matches.add(
        _HighlightMatch(
          start: index,
          end: index + lowerTarget.length,
        ),
      );

      /*
       * Move forward by one character rather than the entire target.
       *
       * This allows overlapping matches to be discovered.
       */
      searchStart = index + 1;
    }

    return matches;
  }

  static String escapeDiscord(String text) {
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

    while (remaining.length > descriptionLimit) {
      var splitAt = remaining.lastIndexOf(
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

      remaining = remaining
          .substring(splitAt)
          .trimLeft();
    }

    if (remaining.isNotEmpty) {
      result.add(remaining);
    }

    return result;
  }
}

class _HighlightRange {
  final int start;
  final int end;

  const _HighlightRange({
    required this.start,
    required this.end,
  });
}

class _HighlightMatch {
  final int start;
  final int end;

  const _HighlightMatch({
    required this.start,
    required this.end,
  });
}
