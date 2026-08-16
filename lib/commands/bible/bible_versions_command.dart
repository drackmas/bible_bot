import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import '../../services/bible_service.dart';

ChatCommand createBibleVersionsCommand() {
  return ChatCommand(
    'versions',
    'List available Bible translations.',
    id(
      'bible-versions',
      (
        ChatContext context,
      ) async {
        await _handleBibleVersions(
          context,
        );
      },
    ),
  );
}

Future<void> _handleBibleVersions(
  ChatContext context,
) async {
  try {
    final versions =
        await BibleService.loadAvailableVersions();

    if (versions.isEmpty) {
      await context.respond(
        MessageBuilder(
          embeds: [
            EmbedBuilder(
              title: '📖 Bible Versions',
              description:
                  'No Bible translations are currently available.',
              color: const DiscordColor(0xFFA000),
            ),
          ],
        ),
      );

      return;
    }

    final description = versions
        .map(
          (version) =>
              '**${version.id}** — ${version.name}',
        )
        .join('\n');

    await context.respond(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '📖 Available Bible Versions',
            description: description,
            color: const DiscordColor(0x4CAF50),
          ),
        ],
      ),
    );
  } catch (error, stackTrace) {
    print(
      '[Bible versions error] $error',
    );

    print(stackTrace);

    await context.respond(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '❌ Bible Versions Error',
            description:
                'Something went wrong while loading '
                'the available Bible translations.',
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );
  }
}
