import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'bible_reference_input.dart';
import '../../errors/bible_exception.dart';
import '../../pagination/bible_paginator.dart';
import '../../parsing/bible_reference_parser.dart';

ChatCommand createBibleLookupCommand() {
  return ChatCommand(
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
    print(
      '[Bible command] ${error.message}',
    );

    await context.respond(
      _buildErrorMessage(
        error.message,
      ),
    );
  } on FormatException catch (error) {
    print(
      '[Bible command] ${error.message}',
    );

    await context.respond(
      _buildErrorMessage(
        error.message,
      ),
    );
  } catch (error, stackTrace) {
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
