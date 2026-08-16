import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'package:bible_bot/commands/bible/bible_reference_input.dart';
import 'package:bible_bot/errors/bible_exception.dart';
import 'package:bible_bot/pagination/bible_paginator.dart';
import 'package:bible_bot/parsing/bible_reference_parser.dart';

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
            @UseConverter(bibleReferenceInputConverter)
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
    final reference =
        await BibleReferenceParser.parse(
      input,
    );

    final message =
        await BiblePaginator.buildMessage(
      reference: reference,
      page: 0,
    );

    await context.respond(
      message,
    );
  } on BibleException catch (error) {
    /*
     * Expected/user-facing Bible errors.
     *
     * Examples:
     * - Book does not exist
     * - Chapter does not exist
     * - Verse does not exist
     * - Translation does not exist
     *
     * These should NOT produce a stack trace.
     */
    print(
      '[Bible command] ${error.message}',
    );

    await context.respond(
      _buildErrorMessage(
        error.message,
      ),
    );
  } on FormatException catch (error) {
    /*
     * Invalid user input is also expected.
     */
    print(
      '[Bible command] ${error.message}',
    );

    await context.respond(
      _buildErrorMessage(
        error.message,
      ),
    );
  } catch (error, stackTrace) {
    /*
     * Only unexpected application failures get a
     * stack trace.
     */
    print(
      '[Bible command error] $error',
    );

    print(stackTrace);

    await context.respond(
      _buildErrorMessage(
        'Something went wrong while looking up '
        'that passage. Please try again.',
      ),
    );
  }
}

MessageBuilder _buildErrorMessage(
  String message,
) {
  return MessageBuilder(
    embeds: [
      EmbedBuilder(
        title: '❌ Bible Lookup Failed',
        description: message,
        color: const DiscordColor(0xD32F2F),
      ),
    ],
  );
}
