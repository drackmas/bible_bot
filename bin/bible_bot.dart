import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'package:bible_bot/models/verse.dart';
import 'package:bible_bot/models/commentary.dart';
import 'package:bible_bot/services/bible_service.dart';
import 'package:bible_bot/services/mandela_service.dart';

void main() async {
  final token = Platform.environment['DISCORD_TOKEN'];

  if (token == null || token.isEmpty) {
    print('Please set the DISCORD_TOKEN environment variable');
    exit(1);
  }

  final commands = CommandsPlugin(
    prefix: null, // we handle prefix commands ourselves
    options: CommandsOptions(logErrors: true),
  );

  // ======================== SLASH COMMANDS ========================

  commands.addCommand(ChatCommand(
    'verse',
    'Look up a Bible verse with Mandela Effect data',
    id('verse', (ChatContext context, String reference) async {
      await handleVerse(context, reference);
    }),
  ));

  commands.addCommand(ChatCommand(
    'chapter',
    'Get an entire chapter',
    id('chapter', (ChatContext context, String book, int chapter) async {
      await handleChapter(context, book, chapter);
    }),
  ));

  commands.addCommand(ChatCommand(
    'search',
    'Search the Bible',
    id('search', (ChatContext context, String query, [String? book]) async {
      await handleSearch(context, query, book);
    }),
  ));

  commands.addCommand(ChatCommand(
    'biblehelp',
    'Show help',
    id('biblehelp', (ChatContext context) async {
      await context.respond(MessageBuilder(
        content: helpText,
      ));
    }),
  ));

  // ======================== CONNECT ========================

  final client = await Nyxx.connectGateway(
    token,
    GatewayIntents.allUnprivileged | GatewayIntents.messageContent,
    options: GatewayClientOptions(
      plugins: [commands, logging, cliIntegration],
    ),
  );

  // ======================== PREFIX HANDLER ========================

  client.onMessageCreate.listen((event) async {
    final message = event.message;

    final content = message.content.trim();
    if (content.isEmpty) return;

    final lower = content.toLowerCase();

    // !verse
    if (lower == '!verse') {
      await message.channel.sendMessage(MessageBuilder(
        content: 'Usage: `!verse John 3:16` or `!verse BSB John 3:16`',
      ));
      return;
    }

    if (lower.startsWith('!verse ')) {
      final reference = content.substring(7).trim();
      await sendRawVerse(message, reference);
      return;
    }

    // !chapter
    if (lower.startsWith('!chapter ')) {
      final input = content.substring(9).trim();
      await handleRawChapter(message, input);
      return;
    }

    // !search
    if (lower.startsWith('!search ')) {
      final input = content.substring(8).trim();
      await handleRawSearch(message, input);
      return;
    }

    // !biblehelp
    if (lower == '!biblehelp' || lower == '!help') {
      await message.channel.sendMessage(MessageBuilder(content: helpText));
      return;
    }
  });

  print('Bible bot is online!');
}

// ==================================================================
// HELP TEXT
// ==================================================================

const helpText = '''
**Bible Bot Commands**

`!verse John 3:16`
`!verse BSB John 3:16`
`!verse AKJV Matthew 19:14-16`

`!chapter John 3`
`!chapter BSB John 3`

`!search love`
`!search grace Romans`

Slash commands also work: `/verse`, `/chapter`, `/search`

**Available versions:**
AKJV, BSB, KJV, ASV, BBE, YLT, Darby, Webster, etc.
''';

// ==================================================================
// HIGHLIGHT HELPER
// ==================================================================

String applyHighlights(String text, List<Highlight> highlights) {
  if (highlights.isEmpty) return text;

  // Sort longer phrases first
  final sorted = List<Highlight>.from(highlights)
    ..sort((a, b) => b.text.length.compareTo(a.text.length));

  String result = text;
  for (final h in sorted) {
    if (h.text.isEmpty) continue;
    final pattern = RegExp(RegExp.escape(h.text), caseSensitive: false);
    result = result.replaceAllMapped(pattern, (m) => '**${m[0]}**');
  }
  return result;
}

// ==================================================================
// BUILD EMBED
// ==================================================================

Future<EmbedBuilder> buildVerseEmbed({
  required String version,
  required String book,
  required int chapter,
  required List<Verse> verses,
}) async {
  final buffer = StringBuffer();

  for (final v in verses) {
    final commentary = await MandelaService.get(book, chapter, v.verse);

    String verseText = v.text;
    if (commentary != null && commentary.highlights.isNotEmpty) {
      verseText = applyHighlights(verseText, commentary.highlights);
    }

    buffer.writeln('**${v.verse}** $verseText');

    // Hashtags / tags line
    if (commentary != null && commentary.hashtags.isNotEmpty) {
      final tags = commentary.hashtags.map((t) {
        final emoji = t.color == 'red' ? '🔴' : '🟢';
        return '$emoji #${t.text}';
      }).join('  ');
      buffer.writeln(tags);
    }

    // Commentary
    if (commentary != null && commentary.text.trim().isNotEmpty) {
      buffer.writeln('> *${commentary.text}*');
    }

    buffer.writeln();
  }

  String description = buffer.toString().trim();

  // Discord embed description limit is 4096
  if (description.length > 4000) {
    description = '${description.substring(0, 3990)}…';
  }

  return EmbedBuilder()
    ..title = '$book $chapter'
    ..description = description
    ..color = DiscordColor(0x7850C8)
    ..footer = EmbedFooterBuilder(text: version.toUpperCase());
}

// ==================================================================
// PARSE REFERENCE (supports optional version)
// ==================================================================

class ParsedReference {
  final String? version;
  final String book;
  final int chapter;
  final int start;
  final int end;

  ParsedReference({
    this.version,
    required this.book,
    required this.chapter,
    required this.start,
    required this.end,
  });
}

ParsedReference parseReference(String input) {
  var cleaned = input.trim().replaceAll(RegExp(r'\s+'), ' ');

  // Optional version at the beginning (e.g. BSB John 3:16)
  String? version;
  final versionMatch = RegExp(
    r'^(AKJV|BSB|KJV|ASV|BBE|YLT|Darby|Webster|NHEB|RLT|Rotherham|CPDV|DRC|Geneva1599|Tyndale|ACV)\s+',
    caseSensitive: false,
  ).firstMatch(cleaned);

  if (versionMatch != null) {
    version = versionMatch.group(1);
    cleaned = cleaned.substring(versionMatch.end).trim();
  }

  final regex = RegExp(
    r'^(.+?)\s+(\d+)\s*:\s*(\d+)(?:\s*-\s*(\d+))?$',
    caseSensitive: false,
  );

  final match = regex.firstMatch(cleaned);
  if (match == null) {
    throw Exception(
      'Invalid format.\n'
      'Examples:\n'
      '`John 3:16`\n'
      '`BSB John 3:16`\n'
      '`Matthew 19:14-16`',
    );
  }

  final bookRaw = match.group(1)!.trim();
  final chapter = int.parse(match.group(2)!);
  final start = int.parse(match.group(3)!);
  final end = match.group(4) != null ? int.parse(match.group(4)!) : start;

  if (end < start) {
    throw Exception('Ending verse cannot be before starting verse.');
  }

  final book = BibleService.normalizeBookName(bookRaw);

  return ParsedReference(
    version: version,
    book: book,
    chapter: chapter,
    start: start,
    end: end,
  );
}

// ==================================================================
// HANDLE VERSE (slash + raw)
// ==================================================================

Future<void> handleVerse(ChatContext context, String reference) async {
  try {
    final parsed = parseReference(reference);
    final verses = await BibleService.getVerseRange(
      parsed.book,
      parsed.chapter,
      parsed.start,
      parsed.end,
      parsed.version,
    );

    if (verses.isEmpty) {
      await context.respond(MessageBuilder(content: 'Verse not found.'));
      return;
    }

    final embed = await buildVerseEmbed(
      version: parsed.version ?? BibleService.defaultVersion,
      book: parsed.book,
      chapter: parsed.chapter,
      verses: verses,
    );

    await context.respond(MessageBuilder(embeds: [embed]));
  } catch (e) {
    await context.respond(MessageBuilder(content: '❌ $e'));
  }
}

Future<void> sendRawVerse(Message message, String reference) async {
  try {
    final parsed = parseReference(reference);
    final verses = await BibleService.getVerseRange(
      parsed.book,
      parsed.chapter,
      parsed.start,
      parsed.end,
      parsed.version,
    );

    if (verses.isEmpty) {
      await message.channel.sendMessage(MessageBuilder(content: 'Verse not found.'));
      return;
    }

    final embed = await buildVerseEmbed(
      version: parsed.version ?? BibleService.defaultVersion,
      book: parsed.book,
      chapter: parsed.chapter,
      verses: verses,
    );

    await message.channel.sendMessage(MessageBuilder(embeds: [embed]));
  } catch (e) {
    await message.channel.sendMessage(MessageBuilder(content: '❌ $e'));
  }
}

// ==================================================================
// CHAPTER HANDLERS
// ==================================================================

Future<void> handleChapter(ChatContext context, String book, int chapter) async {
  try {
    final normalized = BibleService.normalizeBookName(book);
    final verses = await BibleService.getChapter(normalized, chapter);

    if (verses.isEmpty) {
      await context.respond(MessageBuilder(content: 'Chapter not found.'));
      return;
    }

    final embed = await buildVerseEmbed(
      version: BibleService.defaultVersion,
      book: normalized,
      chapter: chapter,
      verses: verses,
    );

    await context.respond(MessageBuilder(embeds: [embed]));
  } catch (e) {
    await context.respond(MessageBuilder(content: '❌ $e'));
  }
}

Future<void> handleRawChapter(Message message, String input) async {
  final regex = RegExp(r'^(?:(\w+)\s+)?(.+?)\s+(\d+)$', caseSensitive: false);
  final match = regex.firstMatch(input.trim());

  if (match == null) {
    await message.channel.sendMessage(MessageBuilder(
      content: 'Invalid format. Use: `!chapter John 3` or `!chapter BSB John 3`',
    ));
    return;
  }

  final version = match.group(1);
  final bookRaw = match.group(2)!.trim();
  final chapter = int.parse(match.group(3)!);
  final book = BibleService.normalizeBookName(bookRaw);

  try {
    final verses = await BibleService.getChapter(book, chapter, version: version);

    if (verses.isEmpty) {
      await message.channel.sendMessage(MessageBuilder(content: 'Chapter not found.'));
      return;
    }

    final embed = await buildVerseEmbed(
      version: version ?? BibleService.defaultVersion,
      book: book,
      chapter: chapter,
      verses: verses,
    );

    await message.channel.sendMessage(MessageBuilder(embeds: [embed]));
  } catch (e) {
    await message.channel.sendMessage(MessageBuilder(content: '❌ $e'));
  }
}

// ==================================================================
// SEARCH HANDLERS (simple for now)
// ==================================================================

Future<void> handleSearch(ChatContext context, String query, [String? book]) async {
  await context.respond(MessageBuilder(content: 'Searching for **$query**...'));

  try {
    final results = await BibleService.search(
      query,
      book: book != null ? BibleService.normalizeBookName(book) : null,
    );

    if (results.isEmpty) {
      await context.respond(MessageBuilder(content: 'No results found.'));
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('**Search results for "$query"** (${results.length} found)\n');

    for (final v in results.take(12)) {
      buffer.writeln('**${v.chapter}:${v.verse}** ${v.text}');
    }

    if (results.length > 12) {
      buffer.writeln('\n... and ${results.length - 12} more');
    }

    await context.respond(MessageBuilder(content: buffer.toString()));
  } catch (e) {
    await context.respond(MessageBuilder(content: '❌ $e'));
  }
}

Future<void> handleRawSearch(Message message, String input) async {
  if (input.isEmpty) {
    await message.channel.sendMessage(MessageBuilder(
      content: 'Usage: `!search love` or `!search grace Romans`',
    ));
    return;
  }

  final words = input.split(RegExp(r'\s+'));
  String query;
  String? book;

  if (words.length == 1) {
    query = words.first;
  } else {
    query = words.sublist(0, words.length - 1).join(' ');
    book = words.last;
  }

  await message.channel.sendMessage(MessageBuilder(
    content: 'Searching for **$query**...',
  ));

  try {
    final results = await BibleService.search(
      query,
      book: book != null ? BibleService.normalizeBookName(book) : null,
    );

    if (results.isEmpty) {
      await message.channel.sendMessage(MessageBuilder(content: 'No results found.'));
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('**Search results for "$query"** (${results.length} found)\n');

    for (final v in results.take(12)) {
      buffer.writeln('**${v.chapter}:${v.verse}** ${v.text}');
    }

    if (results.length > 12) {
      buffer.writeln('\n... and ${results.length - 12} more');
    }

    await message.channel.sendMessage(MessageBuilder(content: buffer.toString()));
  } catch (e) {
    await message.channel.sendMessage(MessageBuilder(content: '❌ $e'));
  }
}
