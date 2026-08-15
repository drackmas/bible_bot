import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'package:bible_bot/pagination/bible_paginator.dart';
import 'package:bible_bot/parsing/bible_reference_parser.dart';
import 'package:bible_bot/services/translation_service.dart';

/// Represents the complete Bible reference portion of a command.
///
/// Examples:
///
/// Genesis 1:1
/// Genesis 1
/// Genesis 1:1 BSB
/// Song of Solomon 1:1
/// 1 Corinthians 13:4-7 BSB
class BibleReferenceInput {
  final String value;

  const BibleReferenceInput(this.value);

  @override
  String toString() => value;
}

/// Converter for Bible references.
///
/// Unlike the normal String converter, this consumes everything
/// remaining in the command input.
///
/// This is necessary because Bible references contain spaces:
///
///   Genesis 1:1
///   Song of Solomon 1:1
///   1 Corinthians 13:4-7 BSB
final Converter<BibleReferenceInput>
    bibleReferenceInputConverter =
    Converter<BibleReferenceInput>(
  (view, context) {
    final value = view.remaining.trim();

    if (value.isEmpty) {
      return null;
    }

    // Mark the entire remainder as consumed.
    view.index = view.end;

    return BibleReferenceInput(value);
  },
  type: CommandOptionType.string,
);

Future<void> main() async {
  final token = Platform.environment['DISCORD_TOKEN'];

  if (token == null || token.isEmpty) {
    stderr.writeln(
      'DISCORD_TOKEN environment variable is not set.',
    );
    exit(1);
  }

  final commands = CommandsPlugin(
    prefix: (_) => '!',
  );

  commands.addConverter(
    bibleReferenceInputConverter,
  );

  _registerCommands(commands);

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

  client.onInteractionCreate.listen(
    (event) async {
      final interaction = event.interaction;

      if (interaction is! MessageComponentInteraction) {
        return;
      }

      final state = BiblePaginator.parseCustomId(
        interaction.data.customId,
      );

      if (state == null) {
        return;
      }

      try {
        final update =
            await BiblePaginator.buildUpdate(
          reference: state.reference,
          page: state.page,
        );

        await interaction.respond(
          update,
          updateMessage: true,
        );
      } catch (error, stackTrace) {
        stderr.writeln(
          'Bible pagination error: $error',
        );
        stderr.writeln(stackTrace);

        try {
          await interaction.respond(
            MessageBuilder(
              embeds: [
                _errorEmbed(
                  'Bible Bot',
                  _friendlyError(error),
                ),
              ],
            ),
          );
        } catch (_) {
          // The interaction may already have been acknowledged.
        }
      }
    },
  );

  stdout.writeln('Bible bot is online.');
}

void _registerCommands(
  CommandsPlugin commands,
) {
  commands.addCommand(
    ChatCommand(
      'bible',
      'Bible commands.',
      id(
        'bible',
        (
          ChatContext context,
          String action,
          BibleReferenceInput reference,
        ) async {
          await _handleBibleCommand(
            context,
            action,
            reference.value,
          );
        },
      ),
    ),
  );

  commands.addCommand(
    ChatCommand(
      'biblehelp',
      'Show Bible Bot help.',
      id(
        'biblehelp',
        (
          ChatContext context,
        ) async {
          await context.respond(
            MessageBuilder(
              embeds: [
                _helpEmbed(),
              ],
            ),
          );
        },
      ),
    ),
  );

  commands.addCommand(
    ChatCommand(
      'bibletranslations',
      'List available Bible translations.',
      id(
        'bibletranslations',
        (
          ChatContext context,
        ) async {
          await _handleTranslationsContext(
            context,
          );
        },
      ),
    ),
  );
}

Future<void> _handleBibleCommand(
  ChatContext context,
  String action,
  String reference,
) async {
  if (action.toLowerCase() != 'lookup') {
    await context.respond(
      MessageBuilder(
        embeds: [
          _errorEmbed(
            'Bible Bot',
            'Unknown Bible action `$action`.\n\n'
                'Use:\n'
                '`!bible lookup Genesis 1:1`',
          ),
        ],
      ),
    );

    return;
  }

  await _lookup(
    respond: (MessageBuilder builder) {
      return context.respond(builder);
    },
    input: reference,
  );
}

Future<void> _lookup({
  required Future<Message> Function(
    MessageBuilder builder,
  ) respond,
  required String input,
}) async {
  try {
    final reference =
        await BibleReferenceParser.parse(input);

    final builder =
        await BiblePaginator.buildMessage(
      reference: reference,
      page: 0,
    );

    await respond(builder);
  } catch (error, stackTrace) {
    stderr.writeln(
      'Bible lookup error: $error',
    );
    stderr.writeln(stackTrace);

    await respond(
      MessageBuilder(
        embeds: [
          _errorEmbed(
            'Bible Lookup Failed',
            _friendlyError(error),
          ),
        ],
      ),
    );
  }
}

Future<void> _handleTranslationsContext(
  ChatContext context,
) async {
  try {
    final translations =
        await TranslationService.load();

    final buffer = StringBuffer();

    for (final translation in translations) {
      buffer.writeln(
        '**${translation.id}** — '
        '${translation.name}',
      );
    }

    await context.respond(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title:
                'Available Bible Translations',
            description:
                buffer.toString().trim(),
            color:
                const DiscordColor(0x7850C8),
            footer:
                EmbedFooterBuilder(
              text:
                  'Default translation: KJV',
            ),
          ),
        ],
      ),
    );
  } catch (error) {
    await context.respond(
      MessageBuilder(
        embeds: [
          _errorEmbed(
            'Bible Bot',
            _friendlyError(error),
          ),
        ],
      ),
    );
  }
}

EmbedBuilder _helpEmbed() {
  return EmbedBuilder(
    title: 'Bible Bot',
    description: '''
**Bible Lookup**

`!bible lookup Genesis 1:1`

Look up Genesis 1:1 using KJV.

`!bible lookup Genesis 1:1 BSB`

Look up Genesis 1:1 using BSB.

`!bible lookup Genesis 1`

Display the complete Genesis chapter 1 using KJV.

`!bible lookup Genesis 1 BSB`

Display the complete Genesis chapter 1 using BSB.

`!bible lookup John 3:16-18 KJV`

Display a verse range.

**Other Commands**

`!bibletranslations`

List all installed Bible translations.

`!biblehelp`

Show this help message.

**KJV Commentary**

Commentary, hashtags, and highlights are displayed only when KJV is being used.
''',
    color:
        const DiscordColor(0x7850C8),
    footer:
        EmbedFooterBuilder(
      text:
          'Default translation: KJV',
    ),
  );
}

EmbedBuilder _errorEmbed(
  String title,
  String message,
) {
  return EmbedBuilder(
    title: '❌ $title',
    description:
        _limitDescription(message),
    color:
        const DiscordColor(0xD32F2F),
  );
}

String _friendlyError(
  Object error,
) {
  if (error is FormatException) {
    return error.message;
  }

  return error
      .toString()
      .replaceFirst(
        'Bad state: ',
        '',
      );
}

String _limitDescription(
  String text,
) {
  const limit = 3900;

  if (text.length <= limit) {
    return text;
  }

  return '${text.substring(0, limit - 20)}\n…';
}
