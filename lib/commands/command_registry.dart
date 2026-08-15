import 'package:nyxx_commands/nyxx_commands.dart';

import 'bible/bible_command.dart';
import 'cleanup/cleanup_command.dart';

void registerCommands(
  CommandsPlugin commands,
) {
  commands.addCommand(
    createBibleCommand(),
  );

  commands.addCommand(
    createCleanupCommand(),
  );
}
