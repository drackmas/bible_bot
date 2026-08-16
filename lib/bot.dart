import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'commands/command_registry.dart';
import 'errors/command_error_handler.dart';
import 'pagination/bible_pagination_handler.dart';

Future<void> startBot() async {
  final token = Platform.environment['DISCORD_TOKEN'];

  if (token == null || token.isEmpty) {
    stderr.writeln('DISCORD_TOKEN environment variable is not set.');

    exit(1);
  }

  final commands = CommandsPlugin(
    prefix: (_) => '!',
    options: const CommandsOptions(logErrors: false),
  );

  registerCommands(commands);

  final client = await Nyxx.connectGateway(
    token,
    GatewayIntents.allUnprivileged | GatewayIntents.messageContent,
    options: GatewayClientOptions(plugins: [commands, logging, cliIntegration]),
  );

  registerCommandErrorHandler(client, commands);

  registerBiblePaginationHandler(client);

  registerUnknownCommandHandler(client, commands);

  stdout.writeln('Bible bot is online.');
}
