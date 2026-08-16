import 'package:nyxx/nyxx.dart';

import '../errors/bot_error.dart';
import '../errors/error_response.dart';
import 'bible_paginator.dart';

void registerBiblePaginationHandler(NyxxGateway client) {
  client.onInteractionCreate.listen((event) async {
    final interaction = event.interaction;

    if (interaction is! MessageComponentInteraction) {
      return;
    }

    final state = BiblePaginator.parseCustomId(interaction.data.customId);

    if (state == null) {
      return;
    }

    try {
      final update = await BiblePaginator.buildUpdate(
        reference: state.reference,
        page: state.page,
      );

      await interaction.respond(update, updateMessage: true);
    } on BotException catch (error) {
      logBotError('Bible pagination error', error, StackTrace.current);

      await sendInteractionError(
        interaction,
        title: '❌ Bible Lookup Failed',
        message: error.userMessage,
      );
    } catch (error, stackTrace) {
      logBotError('Unexpected Bible pagination error', error, stackTrace);

      await sendInteractionError(
        interaction,
        title: '❌ Bible Bot Error',
        message: 'Something went wrong while changing pages.',
      );
    }
  });
}
