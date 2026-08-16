import 'package:nyxx_commands/nyxx_commands.dart';

import 'bible_lookup_command.dart';
import 'bible_versions_command.dart';

ChatGroup createBibleCommand() {
  return ChatGroup(
    'bible',
    'Bible commands.',
    children: [
      createBibleLookupCommand(),
      createBibleVersionsCommand(),
    ],
  );
}
