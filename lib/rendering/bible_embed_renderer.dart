import 'package:nyxx/nyxx.dart';

import '../models/commentary.dart';
import '../models/tag.dart';
import '../models/verse.dart';
import '../services/mandela_service.dart';

class BibleRenderPage {
  final List<Verse> verses;
  final String description;

  const BibleRenderPage({required this.verses, required this.description});
}

class BibleEmbedRenderer {
  static const int descriptionLimit = 3900;

  static const DiscordColor bibleColor = DiscordColor(0x7850C8);

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
        const BibleRenderPage(verses: [], description: 'No verses were found.'),
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
    final isKjv = translation.trim().toUpperCase() == 'KJV';

    Commentary? commentary;
    List<BibleTag> globalTags = const [];

    if (isKjv) {
      /*
       * Per-verse data:
       *
       * - highlights
       * - hashtags
       * - commentary text
       */
      commentary = await MandelaService.get(book, chapter, verse.verse);

      /*
       * Global data:
       *
       * - all tags are stored at the root of
       *   mandela_effect.json
       */
      globalTags = await MandelaService.getTags();
    }

    final originalText = verse.text;

    /*
     * Find which GLOBAL tags actually occur in this verse.
     *
     * A global tag can match:
     *
     * - its phrase
     * - any of its variants
     */
    final matchedTags = isKjv
        ? _findMatchingTags(originalText, globalTags)
        : const <_MatchedTag>[];

    /*
     * Highlight:
     *
     * 1. Per-verse highlights
     * 2. Global tags that occur in this verse
     */
    final highlightedText = isKjv
        ? _applyHighlightsAndTags(
            originalText,
            commentary?.highlights ?? const [],
            matchedTags,
          )
        : escapeDiscord(originalText);

    final buffer = StringBuffer();

    /*
     * ============================================================
     * VERSE
     * ============================================================
     */
    buffer.write('**${verse.verse}** $highlightedText');

    if (!isKjv) {
      return buffer.toString();
    }

    /*
     * ============================================================
     * HASHTAGS
     * ============================================================
     *
     * Hashtags are PER-VERSE.
     *
     * They are always listed here if the verse has them.
     */
    final hashtags = commentary?.hashtags ?? const <HashTag>[];

    if (hashtags.isNotEmpty) {
      final hashtagText = hashtags
          .map((hashtag) {
            final text = hashtag.text.trim();

            if (text.isEmpty) {
              return '';
            }

            final emoji = hashtag.color.trim().toLowerCase() == 'red'
                ? '🔴'
                : '🟢';

            return '$emoji #$text';
          })
          .where((text) => text.isNotEmpty)
          .join('  ');

      if (hashtagText.isNotEmpty) {
        buffer
          ..write('\n')
          ..write(hashtagText);
      }
    }

    /*
     * ============================================================
     * GLOBAL TAGS
     * ============================================================
     *
     * These are NOT stored in Commentary.
     *
     * We only display tags that matched this verse.
     *
     * Example:
     *
     * Tags: bottles, fowl
     */
    if (matchedTags.isNotEmpty) {
      final tagNames = matchedTags
          .map((matchedTag) => matchedTag.tag.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .join(', ');

      if (tagNames.isNotEmpty) {
        buffer
          ..write('\n')
          ..write('🏷️ $tagNames');
      }
    }

    /*
     * ============================================================
     * COMMENTARY
     * ============================================================
     */
    final commentaryText = commentary?.text.trim() ?? '';

    if (commentaryText.isNotEmpty) {
      buffer
        ..write('\n')
        ..write('> *${escapeDiscord(commentaryText)}*');
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
      title = '$book $chapter:${verses.first.verse}';
    } else {
      title = '$book $chapter:${verses.first.verse}-${verses.last.verse}';
    }

    return EmbedBuilder(
      title: title,
      description: page.description,
      color: bibleColor,
      footer: EmbedFooterBuilder(
        text: '${translation.toUpperCase()} • Page $pageNumber/$totalPages',
      ),
    );
  }

  /*
   * ================================================================
   * FIND GLOBAL TAG MATCHES
   * ================================================================
   *
   * Every tag is global.
   *
   * For each global tag we check:
   *
   *   tag.phrase
   *   tag.variants
   *
   * against the actual verse text.
   */
  static List<_MatchedTag> _findMatchingTags(
    String verseText,
    List<BibleTag> tags,
  ) {
    final result = <_MatchedTag>[];

    for (final tag in tags) {
      final matches = <_HighlightMatch>[];

      for (final searchTerm in tag.searchTerms) {
        final term = searchTerm.trim();

        if (term.isEmpty) {
          continue;
        }

        final termMatches = _findMatches(verseText, term);

        matches.addAll(termMatches);
      }

      if (matches.isEmpty) {
        continue;
      }

      /*
       * Remove duplicate matches.
       *
       * This can happen when a phrase and variant
       * resolve to the same text.
       */
      final uniqueMatches = <String, _HighlightMatch>{};

      for (final match in matches) {
        final key = '${match.start}:${match.end}';

        uniqueMatches[key] = match;
      }

      result.add(_MatchedTag(tag: tag, matches: uniqueMatches.values.toList()));
    }

    return result;
  }

  /*
   * ================================================================
   * APPLY HIGHLIGHTS + GLOBAL TAGS
   * ================================================================
   *
   * Everything is calculated against the ORIGINAL verse.
   *
   * We do NOT add "**" until all matches have been found.
   *
   * This prevents broken Markdown such as:
   *
   *   ****word****
   *
   * or:
   *
   *   **old **bottles****
   */
  static String _applyHighlightsAndTags(
    String text,
    List<Highlight> highlights,
    List<_MatchedTag> matchedTags,
  ) {
    if (text.isEmpty) {
      return text;
    }

    final ranges = <_HighlightRange>[];

    /*
     * ============================================================
     * PER-VERSE HIGHLIGHTS
     * ============================================================
     */
    for (final highlight in highlights) {
      final target = highlight.text.trim();

      if (target.isEmpty) {
        continue;
      }

      final matches = _findMatches(text, target);

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
     * ============================================================
     * GLOBAL TAGS
     * ============================================================
     *
     * These are automatically highlighted if they occur
     * in the verse.
     */
    for (final matchedTag in matchedTags) {
      for (final match in matchedTag.matches) {
        /*
         * If this exact occurrence is already covered
         * by a per-verse highlight, don't add another
         * range on top of it.
         */
        final alreadyHighlighted = ranges.any(
          (range) =>
              range.source == _HighlightSource.highlight &&
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
     * ============================================================
     * SORT
     * ============================================================
     */
    ranges.sort((a, b) {
      final startComparison = a.start.compareTo(b.start);

      if (startComparison != 0) {
        return startComparison;
      }

      /*
         * If two matches start at the same character,
         * use the longer one first.
         */
      return b.end.compareTo(a.end);
    });

    /*
     * ============================================================
     * MERGE OVERLAPPING RANGES
     * ============================================================
     *
     * Explicit per-verse highlights have priority.
     */
    final merged = <_HighlightRange>[];

    for (final range in ranges) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }

      final previous = merged.last;

      /*
       * Completely contained inside previous range.
       */
      if (range.start >= previous.start && range.end <= previous.end) {
        /*
         * If the contained range is an explicit
         * highlight, upgrade the source.
         */
        if (range.source == _HighlightSource.highlight &&
            previous.source != _HighlightSource.highlight) {
          merged[merged.length - 1] = _HighlightRange(
            start: previous.start,
            end: previous.end,
            source: _HighlightSource.highlight,
          );
        }

        continue;
      }

      /*
       * Overlapping ranges.
       */
      if (range.start <= previous.end) {
        final source =
            previous.source == _HighlightSource.highlight ||
                range.source == _HighlightSource.highlight
            ? _HighlightSource.highlight
            : _HighlightSource.tag;

        merged[merged.length - 1] = _HighlightRange(
          start: previous.start,
          end: range.end > previous.end ? range.end : previous.end,
          source: source,
        );

        continue;
      }

      /*
       * No overlap.
       */
      merged.add(range);
    }

    /*
     * ============================================================
     * BUILD FINAL DISCORD MARKDOWN
     * ============================================================
     */
    final buffer = StringBuffer();

    var cursor = 0;

    for (final range in merged) {
      /*
       * Normal text before highlight.
       */
      if (range.start > cursor) {
        buffer.write(escapeDiscord(text.substring(cursor, range.start)));
      }

      /*
       * Highlighted text.
       */
      buffer.write('**');

      buffer.write(escapeDiscord(text.substring(range.start, range.end)));

      buffer.write('**');

      cursor = range.end;
    }

    /*
     * Remaining text after last highlight.
     */
    if (cursor < text.length) {
      buffer.write(escapeDiscord(text.substring(cursor)));
    }

    return buffer.toString();
  }

  /*
   * ================================================================
   * FIND TEXT MATCHES
   * ================================================================
   *
   * Case-insensitive.
   *
   * We use whole-word matching for normal words.
   *
   * This prevents:
   *
   *   ox
   *
   * from matching:
   *
   *   box
   *   oxygen
   *
   * But punctuation is allowed:
   *
   *   ox,
   *   ox.
   *   "ox"
   *
   * Phrases are also supported.
   */
  static List<_HighlightMatch> _findMatches(
    String text,
    String target,
  ) {
    final matches = <_HighlightMatch>[];

    if (text.isEmpty || target.isEmpty) {
      return matches;
    }

    /*
     * Global ALL-CAPS tags such as:
     *
     *   GOD
     *   LORD
     *   JESUS
     *
     * are case-sensitive.
     *
     * Therefore:
     *
     *   GOD != God
     *   LORD != Lord
     *
     * Normal tags remain case-insensitive.
     *
     * Therefore:
     *
     *   bottles == Bottles
     */
    final letters = target.replaceAll(
      RegExp(r'[^A-Za-z]'),
      '',
    );

    final caseSensitive =
        letters.isNotEmpty &&
        letters == letters.toUpperCase() &&
        letters != letters.toLowerCase();

    final searchText = caseSensitive
        ? text
        : text.toLowerCase();

    final searchTarget = caseSensitive
        ? target
        : target.toLowerCase();

    var searchStart = 0;

    while (searchStart < searchText.length) {
      final index = searchText.indexOf(
        searchTarget,
        searchStart,
      );

      if (index == -1) {
        break;
      }

      final end = index + searchTarget.length;

      /*
       * Character before match.
       */
      final validStart =
          index == 0 ||
          !_isWordCharacter(
            searchText[index - 1],
          );

      /*
       * Character after match.
       */
      final validEnd =
          end == searchText.length ||
          !_isWordCharacter(
            searchText[end],
          );

      if (validStart && validEnd) {
        matches.add(
          _HighlightMatch(
            start: index,
            end: end,
          ),
        );
      }

      /*
       * Move one character so overlapping
       * matches can still be found.
       */
      searchStart = index + 1;
    }

    return matches;
  }

  /*
   * ================================================================
   * WORD CHARACTER CHECK
   * ================================================================
   */
  static bool _isWordCharacter(String character) {
    if (character.isEmpty) {
      return false;
    }

    final code = character.codeUnitAt(0);

    /*
     * A-Z
     */
    if (code >= 65 && code <= 90) {
      return true;
    }

    /*
     * a-z
     */
    if (code >= 97 && code <= 122) {
      return true;
    }

    /*
     * 0-9
     */
    if (code >= 48 && code <= 57) {
      return true;
    }

    /*
     * Underscore.
     */
    if (code == 95) {
      return true;
    }

    return false;
  }

  /*
   * ================================================================
   * DISCORD ESCAPING
   * ================================================================
   */
  static String escapeDiscord(String text) {
    return text.replaceAll('\\', r'\\').replaceAll('`', r'\`');
  }

  /*
   * ================================================================
   * SPLIT OVERSIZED EMBEDS
   * ================================================================
   */
  static List<String> splitOversized(String text) {
    final result = <String>[];

    var remaining = text;

    while (remaining.length > descriptionLimit) {
      var splitAt = remaining.lastIndexOf(' ', descriptionLimit);

      if (splitAt <= 0) {
        splitAt = descriptionLimit;
      }

      result.add(remaining.substring(0, splitAt));

      remaining = remaining.substring(splitAt).trimLeft();
    }

    if (remaining.isNotEmpty) {
      result.add(remaining);
    }

    return result;
  }
}

/*
 * ================================================================
 * INTERNAL MATCHED TAG
 * ================================================================
 *
 * Private because it is only used inside this renderer.
 *
 * This avoids the analyzer warning:
 *
 * "Invalid use of a private type in a public API."
 */
class _MatchedTag {
  final BibleTag tag;
  final List<_HighlightMatch> matches;

  const _MatchedTag({required this.tag, required this.matches});
}

/*
 * ================================================================
 * INTERNAL HIGHLIGHT SOURCE
 * ================================================================
 */
enum _HighlightSource { highlight, tag }

/*
 * ================================================================
 * INTERNAL HIGHLIGHT RANGE
 * ================================================================
 */
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

/*
 * ================================================================
 * INTERNAL MATCH
 * ================================================================
 */
class _HighlightMatch {
  final int start;
  final int end;

  const _HighlightMatch({required this.start, required this.end});
}
