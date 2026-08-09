# services/ui/message/ — Message State

## Files
| File | Purpose |
|------|---------|
| `messages_service.dart` | Per-chat message cache, `MessageState` map, update triggers |

Per-message widget state (parts, edits, audio) lives directly on `MessageState` (`lib/app/state/message_state.dart`) — the old standalone `MessageWidgetController` was merged into it.

---

## MessagesService (`messages_service.dart`)

One instance per chat GUID. Accessed via `MessagesSvc(chatGuid)`.

**What it owns:**
- `messageStates` — `Map<String, MessageState>` keyed by message GUID
- `messageUpdateTrigger` — `RxMap<String, int>` timestamps; widgets watch a message's entry here to know when to rebuild
- `struct` — in-memory `MessageStruct` for ordered access and range queries

**Key methods:**
- `updateMessage(Message, {String? oldGuid})` — the main write path; merges changes into `MessageState` and handles tempGuid → realGuid remapping
- `addMessages(List<Message>)` — bulk-inserts into the struct and creates `MessageState` entries
- `getMessage(String guid)` → `Message?` — fast in-memory lookup
- `getOrCreateState(Message)` → `MessageState` — lazily creates or retrieves a `MessageState` for a message
- `getOrCreateMessageState(String guid)` → `MessageState` — same but keyed by GUID
- `getMessageStateIfExists(String guid)` → `MessageState?` — non-creating lookup

**Convenience getters:**
- `mostRecentSent` — the most recently sent outgoing message
- `mostRecent` — the most recent message in the thread
- `mostRecentReceived` — the most recent incoming message

**Rules:**
- Never write `MessageState` fields directly from UI — always go through `MessagesService.updateMessage()`
- Widgets should observe `messageUpdateTrigger[guid]` in an `Obx()` to know when to re-query state
- For bulk initial load, use `addMessages()` which skips per-field update overhead

**For the full update flow**, see `docs/MESSAGE_RECEIVE_FLOW.md`.
