import 'package:nyxx_commands/nyxx_commands.dart';

/// Converter used by the Bible lookup command.
///
/// Unlike the normal String converter, this consumes the entire
/// remaining command input.
///
/// For example:
///
/// `Genesis 1:1`
///
/// becomes one String instead of only `Genesis`.
const Converter<String> bibleReferenceInputConverter = Converter<String>(
  _convertBibleReferenceInput,
);

String? _convertBibleReferenceInput(StringView view, ContextData context) {
  final input = view.remaining.trim();

  if (input.isEmpty) {
    return null;
  }

  // Consume everything remaining in the command.
  view.index = view.end;

  return input;
}
