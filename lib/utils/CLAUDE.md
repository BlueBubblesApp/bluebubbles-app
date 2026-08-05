# lib/utils/ — Low-Level Pure Utilities

No business logic. No service dependencies. No GetX.

## Logger (`logger/`)
- `logger.dart` — `Logger.debug/info/warn/error(msg, tag: 'Tag')` — **always use this, never `print()`**
- `task_logger.dart` — task-scoped logging with start/complete/fail lifecycle
- `outputs/debug_console_output.dart` — console sink
- `outputs/rotating_file_output.dart` — rotating file sink implementation
- `outputs/file_output_wrapper.dart` — wraps `rotating_file_output.dart`, strips ANSI codes before writing
- `outputs/log_stream_output.dart` — stream sink (consumed by in-app log viewer)

## Color Engine (`color_engine/`) → `color_engine/CLAUDE.md`
Advanced color space math for theme generation — not for direct use in widgets.

## Parsers (`parsers/event_payload/`)
- `api_payload_parser.dart` — deserializes server API event envelopes into typed objects

## Standalone Utils
- `string_utils.dart` — string manipulation (trim, case conversion, etc.)
- `file_utils.dart` — file I/O wrappers (copy, delete, exists)
- `crypto_utils.dart` — hashing and encryption
- `emoji.dart` — emoji data and character utilities
- `emoticons.dart` — text emoticon → emoji conversion table
- `share.dart` — system share sheet wrapper
- `window_effects.dart` — desktop window transparency (Mica, acrylic) via `flutter_acrylic`
- `media_kit_hot_restart_fix.dart` / `media_kit_hot_restart_fix_web.dart` — workaround for `media_kit` player state surviving Flutter hot restart
