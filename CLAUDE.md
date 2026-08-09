# BlueBubbles App
iMessage client for Android and Desktop (macOS, Windows, Linux). Flutter/Dart.
Web support exists in the codebase but is **deprecated** — do not design for it.
iOS exists but is secondary; the server component runs on macOS only.

## Code → `lib/CLAUDE.md`
## Android native → `android/CLAUDE.md`
## iOS native → `ios/CLAUDE.md`
## macOS native → `macos/CLAUDE.md`
## Windows native → `windows/CLAUDE.md`
## Linux native → `linux/CLAUDE.md`
## Dev scripts → `scripts/CLAUDE.md`
## Claude workflow → `.claude/CLAUDE.md`
## Architecture → `docs/ARCHITECTURE.md`
## Design decisions → `docs/DECISIONS.md`

## Key Conventions
- State: GetIt for services (`GetIt.I<T>()`), GetX `Rx*` for reactive UI state only
- Line width: 120 chars (`analysis_options.yaml`)
- Services barrel: `lib/services/services.dart`
- Helpers barrel: `lib/helpers/helpers.dart`
- Platform models: `io/` (native/desktop), `html/` (web), `global/` (shared)
