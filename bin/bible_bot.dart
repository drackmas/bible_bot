import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'package:bible_bot/commands/command_registry.dart';
import 'package:bible_bot/pagination/bible_paginator.dart';

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

  registerCommands(commands);

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
                EmbedBuilder(
                  title: '❌ Bible Bot Error',
                  description: _friendlyError(error),
                  color: const DiscordColor(0xD32F2F),
                ),
              ],
            ),
          );
        } catch (_) {
          // Interaction may already have been acknowledged.
        }
      }
    },
  );

  stdout.writeln('Bible bot is online.');
}

String _friendlyError(Object error) {
  return error
      .toString()
      .replaceFirst(
        'Bad state: ',
        '',
      );
}
