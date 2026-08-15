import 'package:nyxx/nyxx.dart';

import '../models/commentary.dart';
import '../models/tag.dart';
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
            verses:
                List.unmodifiable(
              currentVerses,
            ),
            description:
                currentText,
          ),
        );
      }

      currentVerses = [verse];
      currentText = rendered;

      if (currentText.length >
          descriptionLimit) {
        final chunks =
            splitOversized(
          currentText,
        );

        for (var i = 0;
            i < chunks.length;
            i++) {
          pages.add(
            BibleRenderPage(
              verses: i == 0
                  ? [verse]
                  : const [],
              description:
                  chunks[i],
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
          verses:
              List.unmodifiable(
            currentVerses,
          ),
          description:
              currentText,
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
        translation.toUpperCase() ==
            'KJV';

    Commentary? commentary;

    List<BibleTag> matchingTags =
        const [];

    if (isKjv) {
      commentary =
          await MandelaService.get(
        book,
        chapter,
        verse.verse,
      );

      matchingTags =
          await MandelaService
              .findTagsInText(
        verse.text,
      );
    }

    var text =
        escapeDiscord(
      verse.text,
    );

    /*
     * KJV-only Mandela processing.
     *
     * First apply the verse-specific
     * commentary highlights.
     */
    if (isKjv &&
        commentary != null &&
        commentary.highlights
            .isNotEmpty) {
      text = applyHighlights(
        text,
        commentary.highlights,
      );
    }

    /*
     * Then apply the global tags.
     *
     * We only highlight a tag if its
     * phrase or one of its variants
     * actually appears in this verse.
     */
    if (isKjv &&
        matchingTags.isNotEmpty) {
      text = applyTagHighlights(
        text,
        matchingTags,
      );
    }

    final buffer =
        StringBuffer();

    buffer.write(
      '**${verse.verse}** $text',
    );

    /*
     * Everything below the verse is
     * KJV-only as well.
     */
    if (isKjv &&
        commentary != null) {
      /*
       * HASHTAGS
       */
      if (commentary
          .hashtags.isNotEmpty) {
        final hashtags =
            commentary.hashtags
                .map(
          (tag) {
            final emoji =
                tag.color
                            .toLowerCase() ==
                        'red'
                    ? '🔴'
                    : '🟢';

            return '$emoji #${tag.text}';
          },
        ).join('  ');

        buffer
          ..write('\n')
          ..write(
            hashtags,
          );
      }

      /*
       * GLOBAL TAGS
       *
       * These are displayed separately
       * from hashtags.
       *
       * They come from:
       *
       * mandela_effect.json -> tags
       */
      if (matchingTags.isNotEmpty) {
        final tags =
            matchingTags
                .map(
          (tag) {
            return '🏷️ ${tag.name}';
          },
        ).join('  ');

        buffer
          ..write('\n')
          ..write(
            tags,
          );
      }

      /*
       * COMMENTARY
       */
      if (commentary.text
          .trim()
          .isNotEmpty) {
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
      title =
          '$book $chapter';
    } else if (verses.length == 1) {
      title =
          '$book $chapter:${verses.first.verse}';
    } else {
      title =
          '$book $chapter:${verses.first.verse}-${verses.last.verse}';
    }

    return EmbedBuilder(
      title: title,
      description:
          page.description,
      color: bibleColor,
      footer:
          EmbedFooterBuilder(
        text:
            '${translation.toUpperCase()} • Page $pageNumber/$totalPages',
      ),
    );
  }

  /*
   * Applies the explicit highlights
   * defined on a commentary.
   */
  static String applyHighlights(
    String text,
    List<Highlight> highlights,
  ) {
    final targets =
        highlights
            .map(
              (highlight) =>
                  highlight.text.trim(),
            )
            .where(
              (target) =>
                  target.isNotEmpty,
            )
            .toList();

    if (targets.isEmpty) {
      return text;
    }

    return _applyTargets(
      text,
      targets,
    );
  }

  /*
   * Applies global BibleTag entries.
   *
   * The tag's phrase and all variants
   * are searched for.
   *
   * Example:
   *
   * phrase:
   *   consider the ravens
   *
   * variants:
   *   Consider the ravens
   *   consider the raven
   *   Consider the raven
   *
   * If any one occurs in the KJV verse,
   * that occurrence is highlighted.
   */
  static String applyTagHighlights(
    String text,
    List<BibleTag> tags,
  ) {
    final targets =
        <String>{};

    for (final tag in tags) {
      for (final term
          in tag.searchTerms) {
        if (term.trim().isNotEmpty &&
            _containsWholePhrase(
              text,
              term,
            )) {
          targets.add(
            term.trim(),
          );
        }
      }
    }

    if (targets.isEmpty) {
      return text;
    }

    return _applyTargets(
      text,
      targets.toList(),
    );
  }

  /*
   * Common highlight implementation.
   *
   * Longer phrases are processed
   * first.
   */
  static String _applyTargets(
    String text,
    List<String> targets,
  ) {
    final sorted =
        List<String>.from(
          targets,
        )..sort(
            (a, b) =>
                b.length.compareTo(
              a.length,
            ),
          );

    var result = text;

    for (final target
        in sorted) {
      final value =
          target.trim();

      if (value.isEmpty) {
        continue;
      }

      result =
          _highlightUnmarkedMatches(
        result,
        value,
      );
    }

    return result;
  }

  /*
   * Highlights a target without
   * repeatedly wrapping already
   * highlighted Markdown.
   */
  static String
      _highlightUnmarkedMatches(
    String text,
    String target,
  ) {
    final escaped =
        RegExp.escape(target);

    final pattern = RegExp(
      '(?<!\\\\*)'
      '(?<![A-Za-z0-9])'
      '$escaped'
      '(?![A-Za-z0-9])'
      '(?!\\\\*)',
      caseSensitive: false,
    );

    return text.replaceAllMapped(
      pattern,
      (match) {
        return '**${match[0]}**';
      },
    );
  }

  static bool _containsWholePhrase(
    String text,
    String target,
  ) {
    final value =
        target.trim();

    if (value.isEmpty) {
      return false;
    }

    final pattern = RegExp(
      r'(?<![A-Za-z0-9])' +
          RegExp.escape(value) +
          r'(?![A-Za-z0-9])',
      caseSensitive: false,
    );

    return pattern.hasMatch(
      text,
    );
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
    final result =
        <String>[];

    var remaining = text;

    while (remaining.length >
        descriptionLimit) {
      var splitAt =
          remaining.lastIndexOf(
        ' ',
        descriptionLimit,
      );

      if (splitAt <= 0) {
        splitAt =
            descriptionLimit;
      }

      result.add(
        remaining.substring(
          0,
          splitAt,
        ),
      );

      remaining =
          remaining
              .substring(
                splitAt,
              )
              .trimLeft();
    }

    if (remaining
        .isNotEmpty) {
      result.add(
        remaining,
      );
    }

    return result;
  }
}
