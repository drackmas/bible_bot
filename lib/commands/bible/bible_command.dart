import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'package:bible_bot/commands/bible/bible_reference_input.dart';
import 'package:bible_bot/errors/bot_error.dart';
import 'package:bible_bot/errors/error_response.dart';
import 'package:bible_bot/pagination/bible_paginator.dart';
import 'package:bible_bot/parsing/bible_reference_parser.dart';
import 'package:bible_bot/services/bible_service.dart';

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
      ChatCommand(
        'versions',
        'List available Bible translations.',
        id('bible-versions', (
          ChatContext context,
        ) async {
          await _handleBibleVersions(context);
        }),
      ),
    ],
  );
}

Future<void> _handleBibleVersions(
  ChatContext context,
) async {
  try {
    final versions = await BibleService.loadAvailableVersions();

    if (versions.isEmpty) {
      await context.respond(
        MessageBuilder(
          embeds: [
            EmbedBuilder(
              title: '📖 Bible Versions',
              description:
                  'No Bible translations are currently available.',
              color: DiscordColor.fromRgb(255, 160, 0),
            ),
          ],
        ),
      );
      return;
    }

    final description = versions
        .map(
          (version) => '**${version.id}** — ${version.name}',
        )
        .join('\n');

    await context.respond(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '📖 Available Bible Versions',
            description: description,
            color: DiscordColor.fromRgb(76, 175, 80),
          ),
        ],
      ),
    );
  } catch (error, stackTrace) {
    logBotError(
      'Failed to load Bible versions',
      error,
      stackTrace,
    );

    await sendErrorResponse(
      context,
      title: '❌ Bible Versions Error',
      message:
          'Something went wrong while loading the available Bible translations.',
    );
  }
}
Future<void> _handleBibleLookup(
  ChatContext context,
  String input,
) async {
  try {
    final reference =
        await BibleReferenceParser.parse(input);

    final message =
        await BiblePaginator.buildMessage(
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
    logBotError(
      'Unexpected Bible command error',
      error,
      stackTrace,
    );

    await sendErrorResponse(
      context,
      title: '❌ Bible Bot Error',
      message:
          'Something went wrong while looking up that passage.',
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
