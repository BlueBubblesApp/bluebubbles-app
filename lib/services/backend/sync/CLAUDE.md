# services/backend/sync/ — Data Synchronization

## Managers

| File | Role |
|------|------|
| `sync_service.dart` | Entry point — decides full vs incremental; tracks `lastIncrementalSync` timestamp |
| `full_sync_manager.dart` | Bulk fetch all chats + messages (initial setup or full resync); batches 25–100 msgs/chat |
| `incremental_sync_manager.dart` | Delta sync since last run; paginated by timestamp/rowId; saves resume markers |
| `chat_sync_manager.dart` | Syncs chat list only (no messages); tracks per-chat progress |
| `handle_sync_manager.dart` | Syncs phone/email handles; requires server v1.5.2+; supports rollback |
| `sync_manager_impl.dart` | Abstract base: `SyncStatus` enum, progress `double`, log output `RxList` |
| `apple_state_catch_up.dart` | Catches up with Apple after being offline: read state, single-message deletes, whole-chat deletes |

## Catching up with Apple
Sync and live events both page *forward*: they learn about things that were
added or changed, never about a read or a delete that happened while the
device was offline. `AppleStateCatchUp.run()` fetches
`GET /server/chat-state/snapshot` and `GET /server/recoverable-messages/snapshot`
once per incremental sync and applies them through the same paths the live
events use. It only hides, never restores: a restore comes from the live
`message-restored` event. It is not counted toward the sync error total; an
older server without the endpoints is a normal condition.

## Status Lifecycle
```
IDLE → IN_PROGRESS → COMPLETED_SUCCESS
                   → COMPLETED_ERROR
              ↑
           STOPPING (user-cancelled)
```

## What Every Manager Exposes
- `status` — `Rx<SyncStatus>`
- `progress` — `double` (0.0 → 1.0)
- `logOutput` — `RxList<Tuple2<LogLevel, String>>`

## Platform Notes
- Desktop (Windows): `full_sync_manager.dart` updates the taskbar progress bar during sync
- Incremental sync is resumable — markers saved to prefs so a crash mid-sync can continue

## Triggering a Sync
Call through `SyncService`, not individual managers directly.
`SyncService.startSync()` chooses the right manager based on last sync state.
