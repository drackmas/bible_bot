import 'package:nyxx_commands/nyxx_commands.dart';

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

  const BibleReferenceInput(
    this.value,
  );

  @override
  String toString() {
    return value;
  }
}

/// Converter for Bible references.
///
/// The normal String converter consumes a single word.
///
/// That doesn't work for Bible references because they contain
/// spaces:
///
///     Genesis 1:1
///     Genesis 1:1 BSB
///     Song of Solomon 1:1
///     1 Corinthians 13:4-7 BSB
///
/// Therefore this converter consumes everything remaining in the
/// command input.
final Converter<BibleReferenceInput>
    bibleReferenceInputConverter =
    Converter<BibleReferenceInput>(
  (view, context) {
    final value = view.remaining.trim();

    if (value.isEmpty) {
      return null;
    }

    // StringView in nyxx_commands 6.1.0 exposes `remaining`
    // as a property and allows the cursor to be moved directly.
    view.index = view.end;

    return BibleReferenceInput(value);
  },
);
