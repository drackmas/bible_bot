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

/// Deletes the requested number of recent messages from the
/// current channel.
///
/// Usage:
///
/// `!cleanup messages 3`
Future<void> cleanupMessages(
  ChatContext context,
  int amount,
) async {
  if (context.guild == null) {
    await _respondError(
      context,
      'Cleanup',
      'This command can only be used inside a server.',
    );

    return;
  }

  if (amount < 1) {
    await _respondError(
      context,
      'Cleanup',
      'You must specify at least **1** message.',
    );

    return;
  }

  if (amount > 100) {
    await _respondError(
      context,
      'Cleanup',
      'You can delete a maximum of **100** messages at once.',
    );

    return;
  }

  try {
    final messages = await _getRecentMessages(
      context.channel.messages,
      amount,
    );

    if (messages.isEmpty) {
      await _respondError(
        context,
        'Cleanup',
        'There are no messages available to delete.',
      );

      return;
    }

    var deleted = 0;

    for (final message in messages) {
      try {
        await message.delete();
        deleted++;
      } catch (error) {
        // One message failing to delete should not prevent
        // the remaining messages from being processed.
        print(
          'Failed to delete message ${message.id}: $error',
        );
      }
    }

    await context.respond(
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
  } catch (error, stackTrace) {
    print(
      'Cleanup error: $error',
    );

    print(stackTrace);

    await _respondError(
      context,
      'Cleanup Failed',
      _friendlyError(error),
    );
  }
}

/// Gets the newest [amount] messages from a channel.
///
/// nyxx_extensions provides MessageManager.stream(), which
/// transparently handles Discord's paginated message-history API.
///
/// We request the newest messages by setting [before] to null
/// and using StreamOrder.mostRecentFirst.
Future<List<Message>> _getRecentMessages(
  MessageManager manager,
  int amount,
) async {
  final messages = <Message>[];

  await for (final message in manager.stream(
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

Future<void> _respondError(
  ChatContext context,
  String title,
  String description,
) async {
  await context.respond(
    MessageBuilder(
      embeds: [
        EmbedBuilder(
          title: '❌ $title',
          description: description,
          color: const DiscordColor(0xD32F2F),
        ),
      ],
    ),
  );
}

String _friendlyError(
  Object error,
) {
  return error
      .toString()
      .replaceFirst(
        'Bad state: ',
        '');
}
