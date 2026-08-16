import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

import 'error_response.dart';

void registerCommandErrorHandler(NyxxGateway client, CommandsPlugin commands) {
  commands.onCommandError.listen((error) async {
    await _handleCommandError(error);
  });
}

Future<void> _handleCommandError(CommandsException error) async {
  if (error is CommandNotFoundException) {
    return;
  }

  if (error is BadInputException) {
    await sendErrorResponse(
      error.context,
      title: '❌ Invalid Command Input',
      message:
          'I could not understand that input.\n\n'
          'Try:\n'
          '`!bible lookup Genesis 1:1`',
    );

    return;
  }

  if (error is NotEnoughArgumentsException) {
    await sendErrorResponse(
      error.context,
      title: '❌ Missing Command Input',
      message:
          'This command is missing required information.\n\n'
          'Try:\n'
          '`!bible lookup Genesis 1:1`',
    );

    return;
  }

  if (error is ConverterFailedException) {
    await sendErrorResponse(
      error.context,
      title: '❌ Invalid Command Input',
      message:
          'I could not understand one of the arguments '
          'you provided.\n\n'
          'Try:\n'
          '`!bible lookup Genesis 1:1`',
    );

    return;
  }

  if (error is CheckFailedException) {
    await sendErrorResponse(
      error.context,
      title: '❌ Permission Denied',
      message: 'You do not have permission to use this command.',
    );

    return;
  }

  if (error is ContextualException) {
    await sendErrorResponse(
      error.context,
      title: '❌ Bot Error',
      message: 'Something went wrong while processing that command.',
    );

    logBotError(
      'Unhandled contextual command error',
      error,
      error.stackTrace ?? StackTrace.current,
    );

    return;
  }

  logBotError(
    'Unhandled command error',
    error,
    error.stackTrace ?? StackTrace.current,
  );
}

void registerUnknownCommandHandler(
  NyxxGateway client,
  CommandsPlugin commands,
) {
  client.onMessageCreate.listen((event) async {
    await _handleUnknownCommand(event, commands);
  });
}

Future<void> _handleUnknownCommand(
  MessageCreateEvent event,
  CommandsPlugin commands,
) async {
  final message = event.message;

  /*
   * MessageAuthor is not always a User.
   *
   * Only check isBot when the author actually is a User.
   */
  if (message.author is User && (message.author as User).isBot) {
    return;
  }

  final content = message.content.trim();

  /*
   * Ignore normal messages.
   */
  if (!content.startsWith('!')) {
    return;
  }

  final input = content.substring(1).trim();

  /*
   * Ignore a bare "!". 
   */
  if (input.isEmpty) {
    await sendChannelError(
      message.channel,
      title: '❌ Missing Command',
      message:
          'Please enter a command after `!`.\n\n'
          '**Available commands:**\n'
          '`!bible lookup <reference>`\n'
          '`!cleanup messages <amount>`',
    );

    return;
  }

  final words = input.split(RegExp(r'\s+'));

  final root = words.first.toLowerCase();

  /*
   * We only handle known command roots here.
   *
   * If this is a completely unrelated !command,
   * tell the user that it does not exist.
   */
  if (root == 'bible') {
    if (words.length == 1) {
      await sendChannelError(
        message.channel,
        title: '❌ Missing Bible Subcommand',
        message:
            'Use the `lookup` subcommand.\n\n'
            '**Example:**\n'
            '`!bible lookup Genesis 1:1`',
      );

      return;
    }

    final subcommand = words[1].toLowerCase();

    if (subcommand != 'lookup') {
      await sendChannelError(
        message.channel,
        title: '❌ Unknown Bible Subcommand',
        message:
            'I don\'t recognize `!bible $subcommand`.\n\n'
            '**Available command:**\n'
            '`!bible lookup <reference>`\n\n'
            '**Example:**\n'
            '`!bible lookup Revelation 1:1`',
      );

      return;
    }

    /*
     * !bible lookup exists, so let nyxx_commands handle
     * its arguments/errors.
     */
    return;
  }

  if (root == 'cleanup') {
    if (words.length == 1) {
      await sendChannelError(
        message.channel,
        title: '❌ Missing Cleanup Subcommand',
        message:
            'Use the `messages` subcommand.\n\n'
            '**Example:**\n'
            '`!cleanup messages 10`',
      );

      return;
    }

    final subcommand = words[1].toLowerCase();

    if (subcommand != 'messages') {
      await sendChannelError(
        message.channel,
        title: '❌ Unknown Cleanup Subcommand',
        message:
            'I don\'t recognize `!cleanup $subcommand`.\n\n'
            '**Available command:**\n'
            '`!cleanup messages <amount>`',
      );

      return;
    }

    return;
  }

  /*
   * Completely unknown command.
   */
  await sendChannelError(
    message.channel,
    title: '❌ Unknown Command',
    message:
        'I don\'t recognize `!$root`.\n\n'
        '**Available commands:**\n'
        '`!bible lookup <reference>`\n'
        '`!cleanup messages <amount>`',
  );
}
