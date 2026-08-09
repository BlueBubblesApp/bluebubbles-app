# Message Receive Flow

End-to-end flow for an inbound message: from the server socket through the database to the reactive UI state.

For the outgoing half (user sends a message), see `docs/MESSAGE_SEND_FLOW.md`.

---

## High-Level Overview

```
Server WebSocket event: "new-message" / "updated-message"
  → SocketService
  → MessageHandlerSvc.handleEvent()  (action_handler.dart)
  → IncomingMsgHandler.handle()  (FIFO queue, configurable concurrency,
      per-GUID serialization via _inflightByGuid, front:true for priority)
  → IncomingMessageHandler._processNewMessage() or _processUpdatedMessage()
      (out-of-order updates for a not-yet-saved message are parked and
      flushed once the matching new-message lands)
  → chat.addMessage() → ChatInterface.addMessageToChat() → GlobalIsolate → ChatActions (ObjectBox write)
  → hydrate ID → Message object
  → ChatsSvc.updateChat() / addChat()  → ChatState.*Internal()     → Obx() rebuild
  → MessagesSvc.updateMessage() / addNewMessage() → MessageState.*Internal()  → Obx() rebuild
```

---

## Step-by-Step Detail

### Step 1 — Socket Receives Event (`socket_service.dart`)

The WebSocket connection maintained by `SocketService` registers listeners at startup:
```dart
socket?.on("new-message",     (data) => MessageHandlerSvc.handleEvent("new-message",     data, 'DartSocket'));
socket?.on("updated-message", (data) => MessageHandlerSvc.handleEvent("updated-message", data, 'DartSocket'));
```

No parsing or routing logic lives here — raw JSON is passed directly to `MessageHandlerSvc`. Firebase push and the Android method channel use the same `handleEvent()` entry point with a different `source` string.

**Key file:** `lib/services/network/socket_service.dart`

---

### Step 2 — Event Dispatch (`action_handler.dart`)

`MessageHandlerSvc` is a top-level `ActionHandler` instance (`Get.find`/`Get.put` singleton, not a GetX service getter). All incoming socket event routing lives in `ActionHandler.handleEvent()`.

**`handleEvent(event, data, source, {useQueue = true})`** parses the raw payload into a typed `ServerPayload`, extracts the `Chat`/`Message`/attachments, then builds an `IncomingPayload` and hands off to `IncomingMsgHandler.handle(payload, front: !useQueue)`.

For `"new-message"` events where `message.isFromMe == true` and the payload has **no** `tempGuid`, the handler can't yet tell which local temp message this echo belongs to. It records the real GUID in `outOfOrderTempGuids` and waits 500ms for the paired `updated-message` (which carries the `tempGuid`) to arrive and remove it; if nothing removes it in that window, the `new-message` is processed as-is. See `docs/MESSAGE_SEND_FLOW.md` for the full tempGuid → realGuid swap.

**Key file:** `lib/services/backend/action_handler.dart`

---

### Step 3 — IncomingMessageHandler (`incoming_message_handler.dart`)

`IncomingMessageHandler` (accessed via the `IncomingMsgHandler` GetIt getter) owns all inbound message queuing and dispatch. It is a GetIt singleton registered at startup.

Internally it maintains a `Queue<_QueueEntry>` and processes entries up to `maxConcurrency` (default `5`) at a time. Same-GUID payloads are additionally chained through an `_inflightByGuid` map so that two transports racing each other (socket + FCM) can never interleave DB writes for the same message.

Calling `handle(payload, {front})` enqueues the payload. Passing `front: true` jumps ahead of waiting items — used when `useQueue` was `false` in Step 2, and internally when flushing/retrying buffered updates.

Routing by `MessageEventType`:
- `MessageEventType.newMessage` → `_processNewMessage(payload)`
- `MessageEventType.updatedMessage` → `_processUpdatedMessage(payload)`

**Key file:** `lib/services/backend/incoming_message_handler.dart`

---

### Step 4 — Handle New Message (`incoming_message_handler.dart`)

**`_processNewMessage(IncomingPayload)`:**

1. **Deduplication** — checks `_processedGuids` (a 100-entry ring buffer). If the real GUID was already processed (e.g. delivered by both socket and Firebase), returns early.

2. **Existing record check** — looks up the message by `tempGuid` and by real GUID. If either already exists in the DB (HTTP response saved it before the socket event, or duplicate delivery), redirects to `_processUpdatedMessage()` for a clean GUID swap or field refresh.

3. **Chat hydration** — calls `_hydrateChat()` to ensure the chat has valid participants and a DB ID before insertion. If not running in an isolate and hydration resolved new contact links, fires `ContactsSvcV2.notifyHandlesUpdated()`.

4. **Save message to DB** — calls `chat.addMessage(message, clearNotificationsIfFromMe: ..., attachments: ...)`. This is the DB write entry point (see Step 5). `clearNotificationsIfFromMe` is only suppressed for reactions, so a notification-triggered reaction doesn't lose its source notification.

5. **Mark as processed** — adds the saved GUID to `_processedGuids` before any async I/O so a duplicate delivery that races in while playing a sound or sending a notification is skipped.

6. **Complete send-progress tracker** — if `tempGuid` is set (and `OutgoingMessageHandler` is registered), calls `OutgoingMsgHandler.completeSendProgressIfExists(tempGuid, Origin.incomingMessageHandler)`.

7. **Audible receive feedback** — plays a receive sound unless the saved message is from this device.

8. **Drive UI reactivity — gated on `!isIsolate`** (skipped entirely when running in a background isolate):
   - Fires `_dispatchNewMessage()` (see below) without awaiting.
   - If this chat is currently the active/open chat, clears `hasUnreadMessage` on the in-memory `Chat` immediately (so the badge never flashes) and persists that via `ChatsSvc.setChatHasUnread(c, false, force: true)`.
   - If a `ChatState` already exists for this chat, calls `ChatsSvc.updateChat(c, override: true)`; otherwise (brand-new chat) calls `ChatsSvc.addChat(c, immediate: true)` — `updateChat()` is a no-op when no `ChatState` exists yet, so this branch is required for a chat's very first message.
   - Calls `ChatsSvc.updateChatLatestMessage(c.guid, saved)`.
   - Re-fires `ContactsSvcV2.notifyHandlesUpdated()` after the `ChatState` is guaranteed to exist (covers the brand-new-chat case).

9. **Push / in-app notification** — awaited (not fire-and-forget): posts a MethodChannel call to Android, and if not awaited the DartWorker engine can be destroyed mid-call, silently dropping the notification. Calls `NotificationsSvc.tryCreateNewMessageNotification(saved, c)` once `NotificationsService` is registered and ready; logs a warning and skips if it isn't registered yet.

10. **Group photo events** — runs regardless of isolate mode (DB persistence happens either way; only the UI state push is isolate-guarded). If `saved.isGroupPhotoEvent`: photo removal clears `customAvatarPath` (via `ChatsSvc.setChatCustomAvatarPath` off-isolate, or a direct save on-isolate); otherwise fetches the new icon from the server via `Chat.getIcon(c, force: true)` and refreshes the chat state.

11. **Flush out-of-order updates** — calls `_flushPendingUpdate()` to re-enqueue (via `handle(..., front: true)`) any `updated-message` that was parked because it arrived before this `new-message`.

**`_processUpdatedMessage(IncomingPayload)`:**

1. **Complete send-progress tracker** — if `tempGuid` is set (same as new-message step 6).

2. **Locate existing DB record** — tries `tempGuid` first (outgoing echo), then the real GUID.

3. **Out-of-order buffering** — if no DB record exists yet, parks the payload via `_parkPendingUpdate()` (which re-checks the DB once more for a race, replaces any existing pending entry for the same GUID, evicts the oldest entry past a 500-item cap, and expires/processes-anyway after a 10s timeout) and returns. `_flushPendingUpdate()` replays it once the matching `new-message` is processed.

4. **Chat hydration** — calls `_hydrateChat()`, same as new-message step 3.

5. **Persist GUID swap / field update** — calls `_replaceMessage()`, which resolves to `Message.replaceMessage()` (`lib/database/io/message.dart`) → `MessageInterface.replaceMessage()`, handling the case where the real GUID is already present due to a parallel delivery (see `docs/MESSAGE_SEND_FLOW.md`).

6. **Persist attachment GUID swaps** — calls `_replaceAttachments()`, which resolves the correct local attachment slot by `temp-` prefix or by index, handles parallel-delivery collisions, and (after all swaps) reloads the message from the DB and calls `MessagesSvc(chat.guid).updateMessage()` once for the whole batch.

7. **Drive UI reactivity — gated on `!isIsolate`:**
   - Calls `_dispatchUpdatedMessage()` → `MessagesSvc(chat.guid).updateMessage(message, oldGuid: tempGuid)` + `EventDispatcherSvc.emit('updated-message', ...)`.
   - Calls `ChatsSvc.updateChat(c, override: true)` unconditionally to refresh chat-list ordering.
   - Only calls `ChatsSvc.updateChatLatestMessage(c.guid, m)` if this chat's current `ChatState.latestMessage` already points at the same message GUID — i.e. it re-syncs the latest-message pointer rather than blindly overwriting it.

**`_dispatchNewMessage(chat, message, {tempGuid})` — three-way branch:**
- If a local `MessagesService` is registered for the chat and the `tempGuid` is a message already known to it, calls `svc.updateMessage(message, oldGuid: tempGuid)` — the classic outgoing-echo swap.
- Else if the real GUID is already known locally, calls `svc.updateMessage(message)` (in-place refresh, no duplication).
- Else calls `svc.addNewMessage(message)` — covers both genuinely new incoming messages *and* an outgoing echo whose `tempGuid` isn't recognized locally (e.g. sent from a different device), which is pushed in as a new message rather than swapped.
- In all cases, fires `EventDispatcherSvc.emit('new-message', {chatGuid, message})`.

---

### Step 5 — Database Write (via Interface + GlobalIsolate)

**Entry point:** `chat.addMessage(message, {clearNotificationsIfFromMe, attachments})` in `lib/database/io/chat.dart`. This method is documented as a "pure DB operation" — UI-service updates (Steps 7-9) are driven separately by `IncomingMessageHandler`, not by `addMessage()` itself.

**`ChatInterface.addMessageToChat()`** (`lib/services/backend/interfaces/chat_interface.dart`):

- Packs arguments into a `Map<String, dynamic>` (all values must be primitive — no ObjectBox entities cross the isolate boundary)
- **If already inside an isolate** (`isIsolate == true`): calls `ChatActions.addMessageToChat(data)` directly
- **If on the main thread:** dispatches to `GlobalIsolate.send(IsolateRequestType.addMessageToChat, data)` and awaits the response
- After the isolate returns `{ messageId: int?, isNewer: bool }`, hydrates the result: `Database.messages.get(messageId)` → full `Message` object. If that lookup fails (ID null/stale), falls back to `Message.findOne(guid: ...)`, and as a last resort constructs a `Message.fromMap()` directly rather than crashing on a null unwrap.

**`ChatActions.addMessageToChat()`** (`lib/services/backend/actions/chat_actions.dart`) runs inside the isolate:
- Upserts the `Message` record into ObjectBox
- Updates `Chat.latestMessage` pointer if the new message is newer
- Returns a plain map — never ObjectBox entities

Back in `Chat.addMessage()` on the calling side (still a "pure DB" step, not gated on isolate):
- If `isNewer`, links the hydrated message via `setLatestMessage()`, clears `dateDeleted` if set, and — only if the message isn't from this device and `SettingsSvc.settings.unarchiveOnNewMessage` is enabled — unarchives the chat.
- Calls `chat.saveAsync()` unconditionally to persist chat-level field mirroring.
- If `isNewer`, toggles unread status: `toggleHasUnreadAsync(false, ...)` if the message is from this device, `toggleHasUnreadAsync(true, ...)` otherwise.
- If the message is a participant-add/remove event, kicks off `serverSyncParticipantsAsync()` to re-fetch authoritative participant data from the server.

For a temp → real GUID swap, `Message.replaceMessage()` → `MessageInterface.replaceMessage()` follows the same isolate routing pattern and atomically updates the GUID on the existing record.

**Key files:**
- `lib/database/io/chat.dart` — `addMessage()`
- `lib/services/backend/interfaces/chat_interface.dart` — `addMessageToChat()`
- `lib/services/backend/actions/chat_actions.dart` — `addMessageToChat()` (runs in isolate)
- `lib/database/io/message.dart` — `replaceMessage()`
- `lib/services/backend/interfaces/message_interface.dart` — `replaceMessage()`

---

### Step 6 — Unread / Archive State Update

This happens inside `Chat.addMessage()` (see Step 5), not as a separate call from `IncomingMessageHandler`:
- If the new message is **newer** and **not from this device**, and the chat was archived, and `SettingsSvc.settings.unarchiveOnNewMessage` is enabled: `chat.toggleArchivedAsync(false)` — unarchives it automatically. (If that setting is off, an archived chat stays archived even on a new incoming message.)
- If the new message is **newer** and **from this device**: `chat.toggleHasUnreadAsync(false, ...)` — clears the unread badge.
- If the new message is **newer** and **not from this device**: `chat.toggleHasUnreadAsync(true, ...)` — marks the chat as having an unread message. (`IncomingMessageHandler` then immediately clears this back to `false` in-memory if the chat happens to be the currently-active/open chat — see Step 4, new-message step 8.)

These go through `ChatInterface`/`saveAsync()` → ObjectBox in the isolate, same as the message write.

---

### Step 7 — Chat Service State Update (`chats_service.dart`)

**`ChatsSvc.updateChat(Chat updated, {bool override = false, bool immediate = true})`** returns `false` (a no-op) if the app is `headless` or if no `ChatState` exists yet for this chat's GUID — which is why `IncomingMessageHandler` branches to `ChatsSvc.addChat()` for a chat's first-ever message (see Step 4).

When a `ChatState` does exist:
1. Calls `state.updateFromChat(updated)` — updates every changed `Rx*` field via `*Internal()` methods — but only if the chat object actually changed or `override: true` was passed. Each `Obx()` widget watching a field rebuilds independently — a `latestMessage` change does not force the chat title to rebuild.
2. Recomputes whether sort-order-relevant fields changed (`latestMessage` GUID/date, `pinIndex`, `isPinned`). If so, or if `override: true`, calls `_repositionChat()` to re-sort the chat list.

**Key file:** `lib/services/ui/chat/chats_service.dart`

---

### Step 8 — Message Service State Update (`messages_service.dart`)

**`MessagesSvc(chatGuid).updateMessage(Message updated, {String? oldGuid})`:**

1. Finds the existing `Message` in the in-memory `MessageStruct` by `oldGuid` (if swapping) or by `updated.guid`
2. Merges the updated message with the existing one (`updated.mergeWith(existing)`)
3. Finds or creates the `MessageState` for this message
4. Calls `messageState.updateFromMessage(updated)` — pushes new values into all `Rx*` fields
5. **If `oldGuid != null`** (tempGuid → realGuid swap): removes `messageStates[oldGuid]` and inserts `messageStates[realGuid]` pointing to the same state object
6. Sets `messageUpdateTrigger[realGuid]` to the current timestamp — widgets that observe the trigger rather than individual fields are notified to rebuild

**`MessagesSvc(chatGuid).addNewMessage(Message message)`** is the counterpart used for genuinely new messages (see Step 4's `_dispatchNewMessage` three-way branch) — it's a no-op if the GUID is already known to the struct.

**Key file:** `lib/services/ui/message/messages_service.dart`

---

### Step 9 — UI Reactivity (`lib/app/state/`)

`ChatState` and `MessageState` are never written to directly by UI code. The only write path is `*Internal()` methods called by the service layer.

**ChatState observables** that drive UI rebuilds: `isPinned`, `hasUnreadMessage`, `isArchived`, `muteType`, `title`, `displayName`, `subtitle`, `latestMessage`, `textFieldText`, `isActive`, `isAlive`, and others. Each is a separate `Rx*` field.

**MessageState observables**: `guid`, `text`, `dateDelivered`, `dateRead`, `dateEdited`, `error`, `hasReactions`, `associatedMessages`, `isSending`, `isSent`, `hasError`, `isReaction`, and others.

Because each field is its own observable, `Obx()` rebuilds only the widget that reads that specific field. An unread badge update does not re-render the chat title. A delivery timestamp update does not re-render the message bubble text.

---

## Key Files at a Glance

| Step | File | Key Method |
|------|------|-----------|
| Socket | `lib/services/network/socket_service.dart` | `socket.on("new-message", ...)` |
| Event dispatch | `lib/services/backend/action_handler.dart` | `handleEvent()` |
| Queue & dispatch | `lib/services/backend/incoming_message_handler.dart` | `handle()`, `_processNewMessage()`, `_processUpdatedMessage()` |
| Chat DB entry | `lib/database/io/chat.dart` | `addMessage()` |
| Interface (chat) | `lib/services/backend/interfaces/chat_interface.dart` | `addMessageToChat()` |
| Interface (message) | `lib/services/backend/interfaces/message_interface.dart` | `replaceMessage()` |
| Isolate actions | `lib/services/backend/actions/chat_actions.dart` | `addMessageToChat()` (runs in isolate) |
| Chat state update | `lib/services/ui/chat/chats_service.dart` | `updateChat()`, `addChat()`, `updateChatLatestMessage()` |
| Message state update | `lib/services/ui/message/messages_service.dart` | `updateMessage()`, `addNewMessage()` |
| Reactive state | `lib/app/state/chat_state.dart` | `updateFromChat()`, `update*Internal()` |
| Reactive state | `lib/app/state/message_state.dart` | `updateFromMessage()`, `update*Internal()` |
