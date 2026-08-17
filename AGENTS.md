# bible_bot

Dart CLI Discord Bible bot (`nyxx` + `nyxx_commands`). SDK ^3.13.0.

## Commands

| Command | Description |
|---|---|
| `!bible lookup <ref>` | Look up a verse/chapter reference |
| `!bible versions` | List available translations |
| `!cleanup messages <n>` | Bulk-delete bot messages |

Command prefix is hardcoded to `!` in `lib/bot.dart`. Do not change it without updating the unknown-command handler in `lib/errors/command_error_handler.dart` which mirrors these commands.

## Dev / verification

```bash
dart analyze                    # lint (uses package:lints/recommended)
dart test                     # unit tests
dart run bin/bible_bot.dart   # run bot
```

Requires `DISCORD_TOKEN` env var at runtime. See `.gitignore` — `.env` files are excluded.

## Architecture

```
bin/bible_bot.dart → lib/bot.dart:startBot()
  ├─ commands/        ChatGroup + subcommand handlers (nyxx_commands)
  │   ├─ bible/       lookup, versions
  │   └─ cleanup/     messages
  ├─ services/        BibleService (data access), TranslationService (registry), MandelaService
  ├─ parsing/         detector — auto-detect refs in chat messages
  │                    parser — parse detected text into structured reference
  ├─ listeners/       onMessageCreate handler for auto-detection
  ├─ rendering/       embed builder for Discord messages
  ├─ pagination/      paginator for long results (nyxx built-in)
  ├─ models/          Verse, Translation, BibleReference, etc.
  └─ errors/          command error handler + custom exception types
```

## Gotchas

- **Two book-name lists exist.** `BibleService.normalizeBookName()` has the canonical abbreviation→name map (600+ entries). `BibleReferenceDetector._books` is a separate hardcoded list used by the auto-detection listener. If you add a new translation, update both or they will diverge.
- **Auto-detection fails silently.** The message listener catches and prints errors but never sends error messages to chat. This is intentional — don't change it without considering noise in active channels.
- **Multi-reference safety rule:** if a message contains >1 detected reference and any of them is a full-chapter reference (e.g. "Genesis 1"), the bot does not respond automatically. Verse-range references are fine.
- **Bible data is JSON files in `assets/`.** Translation registry lives in `assets/referencebibles.json`. Each translation file has `{ books: [{ name, chapters: [{ chapter, verses: [{ verse, text }] }] }] }` structure.
- **Default translation is KJV.** Both `TranslationService.defaultTranslation` and `BibleService.defaultVersion` are hardcoded to `'KJV'`.
- **Caching:** BibleService caches loaded books in a static `_cache` map per version. TranslationService caches the translations list. These persist for the bot's lifetime (no restart needed).
