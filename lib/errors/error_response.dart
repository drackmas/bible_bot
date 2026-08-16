import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

Future<void> sendErrorResponse(
  ContextData context, {
  required String title,
  required String message,
}) async {
  try {
    await context.channel.sendMessage(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: title,
            description: message,
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );
  } catch (error, stackTrace) {
    logBotError('Failed to send Discord error response', error, stackTrace);
  }
}

Future<void> sendChannelError(
  PartialTextChannel channel, {
  required String title,
  required String message,
}) async {
  try {
    await channel.sendMessage(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: title,
            description: message,
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );
  } catch (error, stackTrace) {
    logBotError('Failed to send channel error response', error, stackTrace);
  }
}

Future<void> sendInteractionError(
  MessageComponentInteraction interaction, {
  required String title,
  required String message,
}) async {
  try {
    await interaction.respond(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: title,
            description: message,
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );
  } catch (error, stackTrace) {
    logBotError('Failed to send interaction error response', error, stackTrace);
  }
}

void logBotError(String message, Object error, StackTrace stackTrace) {
  print('[$message] $error');
  print(stackTrace);
}
