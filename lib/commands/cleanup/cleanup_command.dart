import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_extensions/nyxx_extensions.dart';

ChatGroup createCleanupCommand() {
  return ChatGroup(
    'cleanup',
    'Clean up messages in the current channel.',
    children: [
      ChatCommand(
        'messages',
        'Delete recent messages.',
        id(
          'cleanup-messages',
          (
            ChatContext context,
            int amount,
          ) async {
            await cleanupMessages(
              context,
              amount,
            );
          },
        ),
      ),
    ],
  );
}

/// Deletes the requested number of messages immediately
/// preceding the cleanup command.
///
/// The cleanup command itself is not counted.
///
/// Example:
///
/// `!cleanup messages 3`
///
/// deletes the three messages immediately before the command,
/// then deletes the command itself.
Future<void> cleanupMessages(
  ChatContext context,
  int amount,
) async {
  if (context.guild == null) {
    await _sendChannelMessage(
      context,
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '❌ Cleanup',
            description:
                'This command can only be used inside a server.',
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );

    return;
  }

  if (amount < 1) {
    await _sendChannelMessage(
      context,
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '❌ Cleanup',
            description:
                'You must specify at least **1** message.',
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );

    return;
  }

  if (amount > 100) {
    await _sendChannelMessage(
      context,
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '❌ Cleanup',
            description:
                'You can delete a maximum of **100** messages at once.',
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );

    return;
  }

  if (context is! MessageChatContext) {
    await context.respond(
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '❌ Cleanup',
            description:
                'This command must be used as a text command.',
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );

    return;
  }

  final commandMessage = context.message;

  try {
    final messages = await _getMessagesBefore(
      context.channel.messages,
      commandMessage.id,
      amount,
    );

    if (messages.isEmpty) {
      final response = await _sendChannelMessage(
        context,
        MessageBuilder(
          embeds: [
            EmbedBuilder(
              title: '🧹 Cleanup',
              description:
                  'There are no messages available to delete.',
              color: const DiscordColor(0xFFA000),
            ),
          ],
        ),
      );

      await commandMessage.delete();

      await _deleteLater(
        response,
      );

      return;
    }

    var deleted = 0;

    for (final message in messages) {
      try {
        await message.delete();
        deleted++;
      } catch (error) {
        print(
          'Failed to delete message ${message.id}: $error',
        );
      }
    }

    // Send the confirmation BEFORE deleting the command.
    //
    // We deliberately use channel.sendMessage() rather than
    // context.respond() because context.respond() creates a
    // reply referencing the command message. We are about to
    // delete that message.
    final response = await _sendChannelMessage(
      context,
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '🧹 Cleanup Complete',
            description:
                'Deleted **$deleted** message'
                '${deleted == 1 ? '' : 's'}.',
            color: const DiscordColor(0x4CAF50),
          ),
        ],
      ),
    );

    // Now remove the command itself.
    await commandMessage.delete();

    // Remove the confirmation shortly afterward so cleanup
    // does not leave a permanent bot message in the channel.
    await _deleteLater(
      response,
    );
  } catch (error, stackTrace) {
    print(
      'Cleanup error: $error',
    );

    print(stackTrace);

    // We intentionally do NOT use context.respond() here.
    //
    // If the command message was deleted before the exception
    // occurred, a response referencing it would produce:
    //
    // MESSAGE_REFERENCE_UNKNOWN_MESSAGE
    await _sendChannelMessage(
      context,
      MessageBuilder(
        embeds: [
          EmbedBuilder(
            title: '❌ Cleanup Failed',
            description: _friendlyError(error),
            color: const DiscordColor(0xD32F2F),
          ),
        ],
      ),
    );
  }
}

/// Gets up to [amount] messages immediately preceding [before].
///
/// This is important because the cleanup command itself must
/// not be counted as one of the messages being cleaned.
Future<List<Message>> _getMessagesBefore(
  MessageManager manager,
  Snowflake before,
  int amount,
) async {
  final messages = <Message>[];

  await for (final message in manager.stream(
    before: before,
    pageSize: amount,
    order: StreamOrder.mostRecentFirst,
  )) {
    messages.add(message);

    if (messages.length >= amount) {
      break;
    }
  }

  return messages;
}

/// Sends a message directly to the channel instead of replying
/// to the command message.
Future<Message> _sendChannelMessage(
  ChatContext context,
  MessageBuilder builder,
) {
  return context.channel.sendMessage(
    builder,
  );
}

/// Deletes a cleanup confirmation after a short delay.
Future<void> _deleteLater(
  Message message,
) async {
  await Future<void>.delayed(
    const Duration(seconds: 5),
  );

  try {
    await message.delete();
  } catch (error) {
    print(
      'Failed to delete cleanup confirmation: $error',
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
