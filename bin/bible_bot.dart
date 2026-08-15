import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:bible_bot/services/bible_service.dart';

void main() async {
  final token = Platform.environment['DISCORD_TOKEN'];

  if (token == null || token.isEmpty) {
    print('Please set the DISCORD_TOKEN environment variable');
    exit(1);
  }

  // ============================================================
  // nyxx_commands
  //
  // IMPORTANT:
  // prefix: null disables nyxx_commands' text-command parser.
  //
  // We handle !commands ourselves below so that:
  //
  //   !verse John 3:16
  //
  // is received as the complete string "John 3:16".
  //
  // Slash commands still work normally.
  // ============================================================

  final commands = CommandsPlugin(
    prefix: null,
    options: CommandsOptions(
      logErrors: true,
    ),
  );

  // ============================================================
  // /verse
  // ============================================================

  commands.addCommand(
    ChatCommand(
      'verse',
      'Look up a Bible verse (e.g. John 3:16 or John 3:16-18)',
      id(
        'verse',
        (
          ChatContext context,
          String reference,
        ) async {
          await sendVerseResponse(
            context,
            reference,
          );
        },
      ),
    ),
  );

  // ============================================================
  // /chapter
  // ============================================================

  commands.addCommand(
    ChatCommand(
      'chapter',
      'Get an entire chapter (e.g. John 3)',
      id(
        'chapter',
        (
          ChatContext context,
          String book,
          int chapter,
        ) async {
          try {
            final normalized =
                BibleService.normalizeBookName(book);

            final verses =
                await BibleService.getChapter(
              normalized,
              chapter,
            );

            if (verses.isEmpty) {
              await context.respond(
                MessageBuilder(
                  content: 'Chapter not found.',
                ),
              );
              return;
            }

            final buffer = StringBuffer();

            buffer.writeln(
              '**$normalized $chapter**\n',
            );

            for (final verse in verses) {
              buffer.writeln(
                '**${verse.verse}** ${verse.text}',
              );
            }

            final parts = _splitMessage(
              buffer.toString(),
              1900,
            );

            for (final part in parts) {
              await context.respond(
                MessageBuilder(
                  content: part,
                ),
              );
            }
          } catch (e) {
            await context.respond(
              MessageBuilder(
                content: 'Error: $e',
              ),
            );
          }
        },
      ),
    ),
  );

  // ============================================================
  // /search
  // ============================================================

  commands.addCommand(
    ChatCommand(
      'search',
      'Search for text in the Bible',
      id(
        'search',
        (
          ChatContext context,
          String query, [
          String? book,
        ]) async {
          await context.respond(
            MessageBuilder(
              content: 'Searching for **$query**...',
            ),
          );

          try {
            final results =
                await BibleService.search(
              query,
              book: book != null
                  ? BibleService.normalizeBookName(book)
                  : null,
            );

            if (results.isEmpty) {
              await context.respond(
                MessageBuilder(
                  content: 'No results found.',
                ),
              );
              return;
            }

            final buffer = StringBuffer();

            buffer.writeln(
              '**Search results for "$query"** '
              '(${results.length} found)\n',
            );

            for (final verse in results.take(15)) {
              buffer.writeln(
                '**${verse.chapter}:${verse.verse}** '
                '${verse.text}',
              );
            }

            if (results.length > 15) {
              buffer.writeln(
                '\n... and ${results.length - 15} more',
              );
            }

            final parts = _splitMessage(
              buffer.toString(),
              1900,
            );

            for (final part in parts) {
              await context.respond(
                MessageBuilder(
                  content: part,
                ),
              );
            }
          } catch (e) {
            await context.respond(
              MessageBuilder(
                content: 'Error: $e',
              ),
            );
          }
        },
      ),
    ),
  );

  // ============================================================
  // /biblehelp
  // ============================================================

  commands.addCommand(
    ChatCommand(
      'biblehelp',
      'Show Bible bot commands',
      id(
        'biblehelp',
        (
          ChatContext context,
        ) async {
          await context.respond(
            MessageBuilder(
              content: '''
**Bible Bot Commands**

`!verse John 3:16`
`!verse John 3:16-18`
`!verse 1 John 2:1-3`

`!chapter John 3`

`!search love`
`!search grace Romans`

Slash commands:

`/verse`
`/chapter`
`/search`
`/biblehelp`

Books use the same names as the me_bible app.

Abbreviations also work:

`gen`
`john`
`1cor`
`ps`
etc.
''',
            ),
          );
        },
      ),
    ),
  );

  // ============================================================
  // Connect
  // ============================================================

  final client = await Nyxx.connectGateway(
    token,
    GatewayIntents.allUnprivileged |
        GatewayIntents.messageContent,
    options: GatewayClientOptions(
      plugins: [
        commands,
        logging,
        cliIntegration,
      ],
    ),
  );

  // ============================================================
  // RAW PREFIX COMMAND HANDLER
  //
  // This bypasses nyxx_commands argument parsing completely.
  //
  // Discord gives us:
  //
  //   "!verse John 3:16"
  //
  // We manually extract:
  //
  //   "John 3:16"
  // ============================================================

  client.onMessageCreate.listen(
    (event) async {
      final message = event.message;

      // Ignore messages from bots.
      if (message.author.id == client.user.id) {
        return;
      }

      final content = message.content.trim();

      if (content.isEmpty) {
        return;
      }

      // ----------------------------------------------------------
      // !verse
      // ----------------------------------------------------------

      if (content.toLowerCase() == '!verse') {
        await message.channel.sendMessage(
          MessageBuilder(
            content:
                'Usage: `!verse John 3:16`',
          ),
        );
        return;
      }

      if (content.toLowerCase().startsWith('!verse ')) {
        final reference =
            content.substring('!verse '.length).trim();

        print(
          'DEBUG: !verse reference = "$reference"',
        );

        if (reference.isEmpty) {
          await message.channel.sendMessage(
            MessageBuilder(
              content:
                  'Usage: `!verse John 3:16`',
            ),
          );
          return;
        }

        await sendRawVerseResponse(
          message,
          reference,
        );

        return;
      }

      // ----------------------------------------------------------
      // !chapter
      //
      // Example:
      //
      // !chapter John 3
      // ----------------------------------------------------------

      if (content.toLowerCase().startsWith('!chapter ')) {
        final input =
            content.substring('!chapter '.length).trim();

        await handleRawChapter(
          message,
          input,
        );

        return;
      }

      // ----------------------------------------------------------
      // !search
      //
      // Example:
      //
      // !search love
      // !search grace Romans
      // ----------------------------------------------------------

      if (content.toLowerCase().startsWith('!search ')) {
        final input =
            content.substring('!search '.length).trim();

        await handleRawSearch(
          message,
          input,
        );

        return;
      }

      // ----------------------------------------------------------
      // !biblehelp
      // ----------------------------------------------------------

      if (content.toLowerCase() == '!biblehelp') {
        await message.channel.sendMessage(
          MessageBuilder(
            content: '''
**Bible Bot Commands**

`!verse John 3:16`
`!verse John 3:16-18`
`!verse 1 John 2:1-3`

`!chapter John 3`

`!search love`
`!search grace Romans`

Slash commands:

`/verse`
`/chapter`
`/search`
`/biblehelp`
''',
          ),
        );

        return;
      }
    },
  );

  print('Bible bot is online!');
}

// ============================================================
// /verse response
// ============================================================

Future<void> sendVerseResponse(
  ChatContext context,
  String reference,
) async {
  await context.respond(
    MessageBuilder(
      content: 'Looking up **$reference**...',
    ),
  );

  try {
    final result =
        await parseAndFetch(reference);

    if (result.isEmpty) {
      await context.respond(
        MessageBuilder(
          content: 'Verse not found.',
        ),
      );
      return;
    }

    final buffer = StringBuffer();

    buffer.writeln(
      '**${result.first.book} ${result.first.chapter}**',
    );

    for (final verse in result) {
      buffer.writeln(
        '**${verse.verse}** ${verse.text}',
      );
    }

    final parts = _splitMessage(
      buffer.toString(),
      1900,
    );

    for (final part in parts) {
      await context.respond(
        MessageBuilder(
          content: part,
        ),
      );
    }
  } catch (e) {
    await context.respond(
      MessageBuilder(
        content: 'Error: $e',
      ),
    );
  }
}

// ============================================================
// !verse response
// ============================================================

Future<void> sendRawVerseResponse(
  Message message,
  String reference,
) async {
  try {
    final result =
        await parseAndFetch(reference);

    if (result.isEmpty) {
      await message.channel.sendMessage(
        MessageBuilder(
          content: 'Verse not found.',
        ),
      );
      return;
    }

    final buffer = StringBuffer();

    buffer.writeln(
      '**${result.first.book} ${result.first.chapter}**',
    );

    for (final verse in result) {
      buffer.writeln(
        '**${verse.verse}** ${verse.text}',
      );
    }

    final parts = _splitMessage(
      buffer.toString(),
      1900,
    );

    for (final part in parts) {
      await message.channel.sendMessage(
        MessageBuilder(
          content: part,
        ),
      );
    }
  } catch (e) {
    await message.channel.sendMessage(
      MessageBuilder(
        content: 'Error: $e',
      ),
    );
  }
}

// ============================================================
// !chapter
// ============================================================

Future<void> handleRawChapter(
  Message message,
  String input,
) async {
  final regex = RegExp(
    r'^(.+?)\s+(\d+)$',
    caseSensitive: false,
  );

  final match = regex.firstMatch(input);

  if (match == null) {
    await message.channel.sendMessage(
      MessageBuilder(
        content:
            'Invalid format. Use: `!chapter John 3`',
      ),
    );
    return;
  }

  final bookRaw = match.group(1)!.trim();
  final chapter = int.parse(match.group(2)!);

  try {
    final book =
        BibleService.normalizeBookName(bookRaw);

    final verses =
        await BibleService.getChapter(
      book,
      chapter,
    );

    if (verses.isEmpty) {
      await message.channel.sendMessage(
        MessageBuilder(
          content: 'Chapter not found.',
        ),
      );
      return;
    }

    final buffer = StringBuffer();

    buffer.writeln(
      '**$book $chapter**\n',
    );

    for (final verse in verses) {
      buffer.writeln(
        '**${verse.verse}** ${verse.text}',
      );
    }

    final parts = _splitMessage(
      buffer.toString(),
      1900,
    );

    for (final part in parts) {
      await message.channel.sendMessage(
        MessageBuilder(
          content: part,
        ),
      );
    }
  } catch (e) {
    await message.channel.sendMessage(
      MessageBuilder(
        content: 'Error: $e',
      ),
    );
  }
}

// ============================================================
// !search
// ============================================================

Future<void> handleRawSearch(
  Message message,
  String input,
) async {
  if (input.isEmpty) {
    await message.channel.sendMessage(
      MessageBuilder(
        content:
            'Usage: `!search love` or `!search grace Romans`',
      ),
    );
    return;
  }

  String query;
  String? book;

  // For now:
  //
  // !search love
  //
  // searches everything.
  //
  // !search grace Romans
  //
  // treats the last word as the book.
  //
  // This keeps the same behavior you already had.

  final words =
      input.split(RegExp(r'\s+'));

  if (words.length == 1) {
    query = words.first;
  } else {
    query = words.sublist(0, words.length - 1).join(' ');
    book = words.last;
  }

  await message.channel.sendMessage(
    MessageBuilder(
      content: 'Searching for **$query**...',
    ),
  );

  try {
    final results =
        await BibleService.search(
      query,
      book: book != null
          ? BibleService.normalizeBookName(book)
          : null,
    );

    if (results.isEmpty) {
      await message.channel.sendMessage(
        MessageBuilder(
          content: 'No results found.',
        ),
      );
      return;
    }

    final buffer = StringBuffer();

    buffer.writeln(
      '**Search results for "$query"** '
      '(${results.length} found)\n',
    );

    for (final verse in results.take(15)) {
      buffer.writeln(
        '**${verse.chapter}:${verse.verse}** '
        '${verse.text}',
      );
    }

    if (results.length > 15) {
      buffer.writeln(
        '\n... and ${results.length - 15} more',
      );
    }

    final parts = _splitMessage(
      buffer.toString(),
      1900,
    );

    for (final part in parts) {
      await message.channel.sendMessage(
        MessageBuilder(
          content: part,
        ),
      );
    }
  } catch (e) {
    await message.channel.sendMessage(
      MessageBuilder(
        content: 'Error: $e',
      ),
    );
  }
}

// ============================================================
// Parsed verse
// ============================================================

class ParsedVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  ParsedVerse(
    this.book,
    this.chapter,
    this.verse,
    this.text,
  );
}

// ============================================================
// Parse Bible reference
// ============================================================

Future<List<ParsedVerse>> parseAndFetch(
  String reference,
) async {
  final cleaned = reference
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  print(
    'DEBUG: parsing "$cleaned"',
  );

  final regex = RegExp(
    r'^(.+?)\s+(\d+)\s*:\s*(\d+)(?:\s*-\s*(\d+))?$',
    caseSensitive: false,
  );

  final match = regex.firstMatch(cleaned);

  if (match == null) {
    throw Exception(
      'Invalid format. '
      'Use: Book Chapter:Verse or Book Chapter:Start-End\n'
      'Examples: John 3:16 or 1 John 2:1-3',
    );
  }

  final bookRaw = match.group(1)!.trim();

  final chapter = int.parse(
    match.group(2)!,
  );

  final start = int.parse(
    match.group(3)!,
  );

  final end = match.group(4) != null
      ? int.parse(match.group(4)!)
      : start;

  if (end < start) {
    throw Exception(
      'Ending verse cannot be before starting verse.',
    );
  }

  final book =
      BibleService.normalizeBookName(bookRaw);

  final verses =
      await BibleService.getVerseRange(
    book,
    chapter,
    start,
    end,
  );

  if (verses.isEmpty) {
    throw Exception(
      'No verses found for '
      '$book $chapter:$start'
      '${end != start ? '-$end' : ''}',
    );
  }

  return verses
      .map(
        (verse) => ParsedVerse(
          book,
          verse.chapter,
          verse.verse,
          verse.text,
        ),
      )
      .toList();
}

// ============================================================
// Discord message splitter
// ============================================================

List<String> _splitMessage(
  String text,
  int maxLength,
) {
  final parts = <String>[];

  var remaining = text;

  while (remaining.length > maxLength) {
    var splitAt = remaining.lastIndexOf(
      '\n',
      maxLength,
    );

    if (splitAt == -1 ||
        splitAt < maxLength ~/ 2) {
      splitAt = maxLength;
    }

    parts.add(
      remaining
          .substring(0, splitAt)
          .trim(),
    );

    remaining =
        remaining.substring(splitAt).trim();
  }

  if (remaining.isNotEmpty) {
    parts.add(remaining);
  }

  return parts;
}
