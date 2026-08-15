import 'dart:convert';

import 'package:nyxx/nyxx.dart';

import '../models/bible_reference.dart';
import '../models/verse.dart';
import '../rendering/bible_embed_renderer.dart';
import '../services/bible_service.dart';

class BiblePageState {
  final BibleReference reference;
  final int page;

  const BiblePageState({
    required this.reference,
    required this.page,
  });
}

class BiblePaginator {
  static const String prefix = 'bible_page';

  static const String pageIndicatorId =
      'bible_page_indicator';

  static String createCustomId({
    required BibleReference reference,
    required int page,
  }) {
    final json = jsonEncode({
      'v': reference.translation,
      'b': reference.book,
      'c': reference.chapter,
      's': reference.startVerse,
      'e': reference.endVerse,
      'p': page,
    });

    final encoded = base64UrlEncode(
      utf8.encode(json),
    ).replaceAll('=', '');

    return '$prefix:$encoded';
  }

  static BiblePageState? parseCustomId(
    String customId,
  ) {
    if (!customId.startsWith('$prefix:')) {
      return null;
    }

    try {
      var encoded = customId.substring(
        '$prefix:'.length,
      );

      encoded = encoded.padRight(
        encoded.length +
            ((4 - encoded.length % 4) % 4),
        '=',
      );

      final json = utf8.decode(
        base64Url.decode(encoded),
      );

      final decoded = jsonDecode(json);

      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(
        decoded,
      );

      final translation =
          map['v']?.toString();

      final book =
          map['b']?.toString();

      final chapter = int.tryParse(
        map['c']?.toString() ?? '',
      );

      final page = int.tryParse(
        map['p']?.toString() ?? '',
      );

      if (translation == null ||
          book == null ||
          chapter == null ||
          page == null) {
        return null;
      }

      final start = map['s'] == null
          ? null
          : int.tryParse(
              map['s'].toString(),
            );

      final end = map['e'] == null
          ? null
          : int.tryParse(
              map['e'].toString(),
            );

      return BiblePageState(
        reference: BibleReference(
          book: book,
          chapter: chapter,
          startVerse: start,
          endVerse: end,
          translation: translation,
        ),
        page: page,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Verse>> loadVerses(
    BibleReference reference,
  ) async {
    if (reference.isChapter) {
      return BibleService.getChapter(
        reference.book,
        reference.chapter,
        version: reference.translation,
      );
    }

    return BibleService.getVerseRange(
      reference.book,
      reference.chapter,
      reference.startVerse!,
      reference.endVerse!,
      version: reference.translation,
    );
  }

  static Future<MessageBuilder> buildMessage({
    required BibleReference reference,
    required int page,
  }) async {
    final verses = await loadVerses(reference);

    final pages =
        await BibleEmbedRenderer.renderPages(
      book: reference.book,
      chapter: reference.chapter,
      translation: reference.translation,
      verses: verses,
    );

    final safePage = page.clamp(
      0,
      pages.length - 1,
    );

    final currentPage = pages[safePage];

    final embed =
        BibleEmbedRenderer.buildEmbed(
      book: reference.book,
      chapter: reference.chapter,
      translation: reference.translation,
      page: currentPage,
      pageNumber: safePage + 1,
      totalPages: pages.length,
    );

    final components =
        <ComponentBuilder<Component>>[];

    if (pages.length > 1) {
      final rowComponents =
          <ComponentBuilder<Component>>[];

      // Only add Previous when there actually is
      // a previous page.
      if (safePage > 0) {
        rowComponents.add(
          ButtonBuilder(
            style: ButtonStyle.secondary,
            customId: createCustomId(
              reference: reference,
              page: safePage - 1,
            ),
            label: '◀ Previous',
          ),
        );
      }

      // Page indicator.
      //
      // Nyxx 6.9.1 does not expose `disabled` as a
      // ButtonBuilder constructor parameter, so this
      // is simply a non-paginator button. The handler
      // ignores it.
      rowComponents.add(
        ButtonBuilder(
          style: ButtonStyle.secondary,
          customId: pageIndicatorId,
          label:
              '${safePage + 1} / ${pages.length}',
        ),
      );

      // Only add Next when there actually is
      // a next page.
      if (safePage < pages.length - 1) {
        rowComponents.add(
          ButtonBuilder(
            style: ButtonStyle.primary,
            customId: createCustomId(
              reference: reference,
              page: safePage + 1,
            ),
            label: 'Next ▶',
          ),
        );
      }

      components.add(
        ActionRowBuilder(
          components: rowComponents,
        ),
      );
    }

    return MessageBuilder(
      embeds: [embed],
      components: components,
    );
  }

  static Future<MessageUpdateBuilder> buildUpdate({
    required BibleReference reference,
    required int page,
  }) async {
    final message = await buildMessage(
      reference: reference,
      page: page,
    );

    return MessageUpdateBuilder(
      embeds: message.embeds,
      components: message.components,
    );
  }
}
