# BlueBubbles App
iMessage client for Android and Desktop (Windows, Linux). Flutter/Dart.
Web support exists in the codebase but is **deprecated** — do not design for it.
iOS and macOS clients are not supported and never will be — do not design for them. (The server component runs on macOS only.)

## Desktop Client Location

The latest Windows and Linux clients are part of this repository's shared Flutter app on `master`; they are no
longer maintained on a separate desktop branch. Historical desktop branches may still appear in Git history, but
use `master` and the latest desktop release tag when researching current behavior.

- Shared desktop/client logic: `lib/`
- Socket.IO connection and recovery: `lib/services/network/socket_service.dart`
- Windows native runner/integration: `windows/`
- Linux native runner/integration: `linux/`

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
