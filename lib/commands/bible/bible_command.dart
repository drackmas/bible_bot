import 'package:nyxx_commands/nyxx_commands.dart';

import 'package:bible_bot/commands/bible/bible_reference_input.dart';
import 'package:bible_bot/errors/bot_error.dart';
import 'package:bible_bot/errors/error_response.dart';
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
        id('bible-lookup', (
          ChatContext context,
          @UseConverter(bibleReferenceInputConverter) String input,
        ) async {
          await _handleBibleLookup(context, input);
        }),
      ),
    ],
  );
}

Future<void> _handleBibleLookup(ChatContext context, String input) async {
  try {
    final reference = await BibleReferenceParser.parse(input);

    final message = await BiblePaginator.buildMessage(
      reference: reference,
      page: 0,
    );

    await context.respond(message);
  } on FormatException catch (error) {
    await sendErrorResponse(
      context,
      title: '❌ Invalid Bible Reference',
      message: error.message,
    );
  } on BotException catch (error) {
    await sendErrorResponse(
      context,
      title: _errorTitle(error),
      message: error.userMessage,
    );
  } catch (error, stackTrace) {
    logBotError('Unexpected Bible command error', error, stackTrace);

    await sendErrorResponse(
      context,
      title: '❌ Bible Bot Error',
      message: 'Something went wrong while looking up that passage.',
    );
  }
}

String _errorTitle(BotException error) {
  if (error is UserInputException) {
    return '❌ Invalid Bible Reference';
  }

  if (error is NotFoundException) {
    return '❌ Bible Passage Not Found';
  }

  if (error is DataException) {
    return '❌ Bible Data Error';
  }

  if (error is ConfigurationException) {
    return '❌ Bible Configuration Error';
  }

  return '❌ Bible Bot Error';
}
