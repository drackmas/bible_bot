import 'package:nyxx/nyxx.dart';

import '../pagination/bible_paginator.dart';
import '../parsing/bible_reference_detector.dart';
import '../parsing/bible_reference_parser.dart';

void registerBibleReferenceListener(
  NyxxGateway client,
) {
  client.onMessageCreate.listen(
    (event) async {
      await _handleMessage(event);
    },
  );
}

Future<void> _handleMessage(
  MessageCreateEvent event,
) async {
  final message = event.message;

  /*
   * Never respond to bots.
   *
   * This prevents the Bible bot from responding to its
   * own generated messages.
   */
  if (message.author is User &&
      (message.author as User).isBot) {
    return;
  }

  final content = message.content.trim();

  if (content.isEmpty) {
    return;
  }

  final detected =
      await BibleReferenceDetector.detect(
    content,
  );

  if (detected.isEmpty) {
    return;
  }

  /*
   * Multiple-reference safety rule:
   *
   * If there is more than one reference and ANY of them
   * is a full chapter, don't automatically respond.
   *
   * Example:
   *
   * Genesis 1 and Mark 1:3
   *
   * -> no response
   *
   * But:
   *
   * Genesis 1:1-3 KJV and Mark 1:3 BSB
   *
   * -> respond to both
   */
  if (detected.length > 1 &&
      detected.any(
        (reference) => reference.isFullChapter,
      )) {
    return;
  }

  /*
   * A maximum of five references is enforced by the
   * detector.
   */
  for (final detectedReference in detected) {
    await _lookupReference(
      message,
      detectedReference,
    );
  }
}

Future<void> _lookupReference(
  Message message,
  DetectedBibleReference detected,
) async {
  try {
    final reference =
        await BibleReferenceParser.parse(
      detected.text,
    );

    final builder =
        await BiblePaginator.buildMessage(
      reference: reference,
      page: 0,
    );

    await message.channel.sendMessage(
      builder,
    );
  } catch (error, stackTrace) {
    /*
     * Automatic detection should fail silently.
     *
     * If a sentence happens to look like a Bible reference
     * but the actual Bible data doesn't contain it, don't
     * send an error message into the conversation.
     */
    print(
      '[Bible reference listener] '
      'Failed to process "${detected.text}": $error',
    );

    print(stackTrace);
  }
}
