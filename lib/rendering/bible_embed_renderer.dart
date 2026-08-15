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
            verses: List.unmodifiable(
              currentVerses,
            ),
            description: currentText,
          ),
        );
      }

      currentVerses = [verse];
      currentText = rendered;

      if (currentText.length > descriptionLimit) {
        final chunks = splitOversized(
          currentText,
        );

        for (var i = 0; i < chunks.length; i++) {
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
    final isKjv =
        translation.trim().toUpperCase() == 'KJV';

    Commentary? commentary;

    if (isKjv) {
      commentary = await MandelaService.get(
        book,
        chapter,
        verse.verse,
      );
    }

    final originalText = verse.text;

    /*
     * KJV:
     *
     *   Existing highlights are highlighted.
     *   Tags are also highlighted if they occur in
     *   the verse and aren't already covered by an
     *   existing highlight.
     *
     * Non-KJV:
     *
     *   Absolutely no Mandela metadata.
     */
    final highlightedText = isKjv && commentary != null
        ? applyHighlightsAndTags(
            originalText,
            commentary.highlights,
            commentary.tags,
          )
        : escapeDiscord(originalText);

    final buffer = StringBuffer();

    buffer.write(
      '**${verse.verse}** $highlightedText',
    );

    if (isKjv && commentary != null) {
      /*
       * HASHTAGS
       *
       * These remain completely separate from tags.
       */
      if (commentary.hashtags.isNotEmpty) {
        final hashtags = commentary.hashtags
            .map(
              (hashtag) {
                final emoji =
                    hashtag.color
                                .trim()
                                .toLowerCase() ==
                            'red'
                        ? '🔴'
                        : '🟢';

                return '$emoji #${hashtag.text.trim()}';
              },
            )
            .join('  ');

        buffer
          ..write('\n')
          ..write(hashtags);
      }

      /*
       * TAGS
       *
       * Tags do NOT get a # prefix.
       *
       * They are deliberately displayed on their
       * own line underneath hashtags.
       */
      if (commentary.tags.isNotEmpty) {
        final tags = commentary.tags
            .map(
              (tag) => tag.text.trim(),
            )
            .where(
              (text) => text.isNotEmpty,
            )
            .join(', ');

        if (tags.isNotEmpty) {
          buffer
            ..write('\n')
            ..write('Tags: $tags');
        }
      }

      /*
       * COMMENTARY
       *
       * Commentary remains underneath the tags.
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
   * Highlights BOTH:
   *
   * 1. explicit highlights from mandela_effect.json
   * 2. tags from mandela_effect.json
   *
   * BUT:
   *
   * a tag is only added as a highlight when its
   * occurrence is NOT already covered by an existing
   * highlight.
   *
   * Everything is calculated against the ORIGINAL
   * verse text before any ** markdown is inserted.
   */
  static String applyHighlightsAndTags(
    String text,
    List<Highlight> highlights,
    List<Tag> tags,
  ) {
    if (text.isEmpty) {
      return text;
    }

    final ranges = <_HighlightRange>[];

    /*
     * First add explicit highlight ranges.
     */
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
            source: _HighlightSource.highlight,
          ),
        );
      }
    }

    /*
     * Now add tag ranges.
     *
     * A tag is NOT added if the matching text is
     * already completely covered by an explicit
     * highlight.
     */
    for (final tag in tags) {
      final target = tag.text.trim();

      if (target.isEmpty) {
        continue;
      }

      final matches = _findMatches(
        text,
        target,
      );

      for (final match in matches) {
        final alreadyHighlighted =
            ranges.any(
          (range) =>
              range.source ==
                  _HighlightSource.highlight &&
              match.start >= range.start &&
              match.end <= range.end,
        );

        if (alreadyHighlighted) {
          continue;
        }

        ranges.add(
          _HighlightRange(
            start: match.start,
            end: match.end,
            source: _HighlightSource.tag,
          ),
        );
      }
    }

    if (ranges.isEmpty) {
      return escapeDiscord(text);
    }

    /*
     * Sort by location.
     *
     * When two ranges start at the same location,
     * prefer the longer one.
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
     * Explicit highlights win over tags.
     */
    final merged = <_HighlightRange>[];

    for (final range in ranges) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }

      final previous = merged.last;

      /*
       * Completely contained by the existing range.
       */
      if (range.start >= previous.start &&
          range.end <= previous.end) {
        continue;
      }

      /*
       * Overlapping ranges.
       */
      if (range.start <= previous.end) {
        /*
         * If either range is an explicit highlight,
         * keep it as the highlight.
         */
        final source =
            previous.source ==
                    _HighlightSource.highlight ||
                range.source ==
                    _HighlightSource.highlight
            ? _HighlightSource.highlight
            : _HighlightSource.tag;

        merged[
          merged.length - 1
        ] = _HighlightRange(
          start: previous.start,
          end: range.end > previous.end
              ? range.end
              : previous.end,
          source: source,
        );

        continue;
      }

      merged.add(range);
    }

    /*
     * Build the final Markdown ONCE.
     *
     * This prevents one highlight from accidentally
     * matching the ** inserted by another.
     */
    final buffer = StringBuffer();

    var cursor = 0;

    for (final range in merged) {
      if (range.start > cursor) {
        buffer.write(
          escapeDiscord(
            text.substring(
              cursor,
              range.start,
            ),
          ),
        );
      }

      buffer.write('**');

      buffer.write(
        escapeDiscord(
          text.substring(
            range.start,
            range.end,
          ),
        ),
      );

      buffer.write('**');

      cursor = range.end;
    }

    if (cursor < text.length) {
      buffer.write(
        escapeDiscord(
          text.substring(cursor),
        ),
      );
    }

    return buffer.toString();
  }

  /*
   * Keep this method for compatibility with anything
   * else in the project that may still call
   * applyHighlights().
   *
   * It now uses the same safe highlighting engine.
   */
  static String applyHighlights(
    String text,
    List<Highlight> highlights,
  ) {
    return applyHighlightsAndTags(
      text,
      highlights,
      const [],
    );
  }

  /*
   * Case-insensitive substring matching.
   *
   * We deliberately do NOT use word boundaries because
   * your highlight data contains punctuation and phrases
   * such as:
   *
   *   ":"
   *   "repent: hath"
   *   "it? or"
   */
  static List<_HighlightMatch> _findMatches(
    String text,
    String target,
  ) {
    final matches = <_HighlightMatch>[];

    if (text.isEmpty || target.isEmpty) {
      return matches;
    }

    final lowerText =
        text.toLowerCase();

    final lowerTarget =
        target.toLowerCase();

    var searchStart = 0;

    while (searchStart <=
        lowerText.length -
            lowerTarget.length) {
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
          end:
              index + lowerTarget.length,
        ),
      );

      /*
       * Move one character so overlapping
       * matches are still discovered.
       */
      searchStart = index + 1;
    }

    return matches;
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

enum _HighlightSource {
  highlight,
  tag,
}

class _HighlightRange {
  final int start;
  final int end;
  final _HighlightSource source;

  const _HighlightRange({
    required this.start,
    required this.end,
    required this.source,
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
