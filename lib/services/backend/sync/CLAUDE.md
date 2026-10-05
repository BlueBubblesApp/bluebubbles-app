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
| `chat_state_reconciler.dart` | Validates and applies the server's versioned authoritative chat snapshot; reconciles read state and forward-only whole-thread deletion |
| `chat_state_transition.dart` | Pure forward-only deletion state machine: seeds non-empty chats, then detects populated-to-empty/absent transitions |

## Chat State Reconciliation
`chat_state_reconciler.dart` exists because sync and events both page *forward*:
they learn about things that were added or changed, never about things that
disappeared. A read that happened while the device was offline and a chat
deleted on the Apple side are both invisible to them.

`SyncService.performChatStateReconcile()` fetches `GET /server/chat-state/snapshot`
and applies it once per incremental sync. It is intentionally **not** counted
toward the sync error total — it corrects drift, and an older server without the
endpoint is a normal condition.

Snapshot v2 is strict and forward-only. `ChatStateReconciler.apply()` rejects an
unsupported schema, malformed row, conflicting duplicate, incomplete response,
or out-of-order response. Complete empty snapshots remain valid: the first seeds
a durable set of non-empty chats without deleting; later populated-to-empty or
populated-to-absent transitions soft-delete locally. The durable baseline is
scoped to the configured server address. Read and archive changes use dedicated
server-authoritative setters; read replay cannot echo a mark-read operation to
Apple even while the conversation is active, and archive replay preserves local
pin state.

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
