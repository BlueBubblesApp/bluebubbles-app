# services/backend/ — Server Interaction

## Request Pattern
Each resource has an interface and a concrete action file → `interfaces/CLAUDE.md` + `actions/CLAUDE.md`
- `interfaces/chat_interface.dart` → `actions/chat_actions.dart`
- `interfaces/message_interface.dart` → `actions/message_actions.dart`
- (same for: attachment, contact, contact_v2, handle, image, prefs, server, sync, test)

## Sync System (`sync/`) → `sync/CLAUDE.md`
- `sync_service.dart` — coordinator
- `full_sync_manager.dart` — initial full data sync
- `incremental_sync_manager.dart` — delta updates
- `handle_sync_manager.dart` — contact handle sync

## Outgoing Message Handler
- `outgoing_message_handler.dart` — `OutgoingMessageHandler` / `OutgoingMsgHandler` GetIt getter
- Owns the complete outbound send pipeline: serial queue, `_buildOutgoingMessages` / `_persistOutgoingMessages` / `prepAttachment`, HTTP + socket race via `_sendWithRace()`, send-progress trackers, GUID swap (`_matchMessageWithExisting()`), and error marking

## Incoming Message Handler
- `incoming_message_handler.dart` — `IncomingMessageHandler` / `IncomingMsgHandler` GetIt getter
- Owns the inbound message pipeline: FIFO queue, configurable concurrency, per-GUID serialization, deduplication, chat hydration, DB write, notification dispatch, and UI reactivity

## Other Key Files
- `settings/` — `SettingsService` + `SharedPreferencesService` → `settings/CLAUDE.md`
- `notifications/notifications_service.dart` — local notification dispatch
- `java_dart_interop/` — Android method channel bridge → `java_dart_interop/CLAUDE.md`
- `lifecycle/` — foreground/background lifecycle → `lifecycle/CLAUDE.md`
- `filesystem/` — file I/O, attachment path resolution → `filesystem/CLAUDE.md`
- `setup/` — first-run server connection orchestration → `setup/CLAUDE.md`
