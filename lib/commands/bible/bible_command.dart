import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'package:bible_bot/parsing/bible_reference_parser.dart';
import 'package:bible_bot/pagination/bible_paginator.dart';

/// Creates the `!bible` command group.
///
/// Examples:
///
/// `!bible lookup Genesis 1:1`
/// `!bible lookup Genesis 1:1 BSB`
/// `!bible lookup Genesis 1`
/// `!bible lookup Genesis 1 BSB`
ChatGroup createBibleCommand() {
  return ChatGroup(
    'bible',
    'Look up Bible passages.',
    children: [
      ChatCommand(
        'lookup',
        'Look up a Bible passage.',
        id(
          'bible-lookup',
          (
            ChatContext context,
            String input,
          ) async {
            await _handleBibleLookup(
              context,
              input,
            );
          },
        ),
      ),
    ],
  );
}

Future<void> _handleBibleLookup(
  ChatContext context,
  String input,
) async {
  try {
    final reference = await BibleReferenceParser.parse(
      input,
    );

    final message = await BiblePaginator.buildMessage(
      reference: reference,
      page: 0,
    );

    await context.respond(
      message,
    );
  } on FormatException catch (error) {
    await context.respond(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '❌ Bible Lookup Failed',
            description: error.message,
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );
  } catch (error, stackTrace) {
    print(
      'Bible command error: $error',
    );

    print(stackTrace);

    await context.respond(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '❌ Bible Bot Error',
            description: _friendlyError(error),
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );
  }
}

String _friendlyError(
  Object error,
) {
  return error
      .toString()
      .replaceFirst(
        'Bad state: ',
        '',
      );
}
