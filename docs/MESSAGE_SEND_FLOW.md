# Message Send Flow

End-to-end flow for an outbound message: from the user tapping Send through the API call, the race between the socket response and the HTTP response, and the tempGuid → realGuid swap that merges them.

For the inbound half of this flow (after the server echoes the message back), see `docs/MESSAGE_RECEIVE_FLOW.md`.

---

## High-Level Overview

```
UI (send button tap)
  → build Message (tempGuid assigned explicitly for attachments; text/multipart
      get theirs centrally in OutgoingMessageHandler.queue())
  → OutgoingMsgHandler.queue(item)
      → _ensureTempGuid(item) — belt-and-suspenders GUID assignment
      → _prepItemWithRetry(item):
          text/multipart → _buildOutgoingMessages() (may split into 2 msgs on
              old macOS) → _persistOutgoingMessages() → chat.addMessage()
              (saved to DB with tempGuid — appears in UI as "sending")
          attachment     → prepAttachment() (copy file, save to DB)
          retried up to 3x on transient failure; a terminal failure is
              surfaced as a failed message, never silently dropped
      → item enters the serial `_queue`; OutgoingMessageHandler._processNext()
        drains it one item at a time
          → _dispatchItem() → sendMessage() / sendMultipart() / sendAttachment()
          → _sendWithRace(): registers a send-progress tracker, then fires the
            HTTP call through SendMessageInterface → GlobalIsolate →
            SendMessageActions → HttpSvc.message.*
          ↓ (concurrent)
    ┌─────────────────────┬──────────────────────────┐
    │ Path A               │ Path B                    │
    │ Socket/Firebase      │ HTTP response             │
    │ fires first          │ arrives first             │
    └─────────────────────┴──────────────────────────┘
          ↓ (both paths converge here)
      _matchMessageWithExisting(tempGuid, realMessage)
        → delete stale temp record, upsert/rename to real record
        → MessagesSvc.updateMessage(real, oldGuid: temp)
          → MessageState: guid updated → isSending → false, isSent → true
          → UI rebuilds (bubble stops animating)
```

---

## Step-by-Step Detail

### Step 1 — User Taps Send (`send_button.dart`)

The Send button calls the `sendMessage` callback passed down from `ConversationTextField`. Validation runs (non-empty content, setup complete, etc.), then delegates to `controller.send()` (`conversation_view_controller.dart`), which calls the `sendFunc` registered by `SendAnimation`.

**Key file:** `lib/app/layouts/conversation_view/widgets/text_field/send_button.dart`

---

### Step 2 — Build Message Objects (`send_animation.dart`)

`SendAnimation.send()` constructs one `Message` per attachment and one for the text/subject body (if non-empty), then wraps each in a typed outgoing queue item and pushes it to `OutgoingMsgHandler.queue()`.

**Attachments explicitly generate their tempGuid here** (and copy it onto the attachment record so message and attachment share a GUID):
```dart
message.generateTempGuid();  // sets guid = "temp-XXXXXXXX" (8 random chars)
attachment.guid = message.guid;
await OutgoingMsgHandler.queue(OutgoingAttachment(chat: ..., message: message, attachment: attachment, ...));
```

**Text/multipart messages do *not* call `generateTempGuid()` here** — the `Message` is built without a GUID and handed to `queue()` as-is:
```dart
OutgoingMsgHandler.queue(
  _message.attributedBody.isNotEmpty
      ? OutgoingMultipartMessage(chat: controller.chat, message: _message)
      : OutgoingMessage(chat: controller.chat, message: _message),
);
```
`OutgoingMessageHandler.queue()` assigns the tempGuid centrally via `_ensureTempGuid()` (see Step 3) — this was deliberately centralized after several call sites forgot to generate one themselves, which crashed downstream null-checks.

The tempGuid format is always `temp-` followed by 8 random alphanumeric characters. This prefix is how the app detects "sending" state at construction time: `MessageState.isSending` is seeded as `guid.startsWith("temp") && error == 0`.

Queue item types are explicit and compile-time safe: `OutgoingMessage` (plain text), `OutgoingReaction` (tapbacks, with required `selectedMessage` + `reaction`), `OutgoingAttachment` (file/audio, with required `attachment` + `isAudioMessage`), `OutgoingMultipartMessage` (attributed/mention text).

**Key file:** `lib/app/layouts/conversation_view/widgets/message/send_animation.dart`

---

### Step 3 — OutgoingMessageHandler: Prepare (`outgoing_message_handler.dart`)

**`OutgoingMessageHandler.queue(item)`** runs entirely synchronously with respect to the caller before the item is placed on the serial send queue:

1. **`_ensureTempGuid(item)`** — assigns `item.message.generateTempGuid()` if the message has no GUID yet (a no-op for attachments, which already have one from Step 2, and for retries, which reuse the original failed message's GUID).
2. **`_prepItemWithRetry(item)`** — for text/multipart/reaction items, builds the message(s) once via `_buildOutgoingMessages()` (pure/synchronous — never re-run across retries, since re-running would desync the GUID from what a prior attempt already persisted), then calls `_persistOutgoingMessages()`; for attachments, calls `prepAttachment()`. Both are retried up to 3 attempts (250ms × attempt backoff) if a transient failure leaves the record unsaved. If retries are exhausted, the item is **finalized as a failed message** (visible + retryable) rather than silently dropped — this matters because a fire-and-forget `queue()` call would otherwise lose the message entirely if the isolate was mid-restart.
3. Once prep succeeds, the resulting message(s) are wrapped back into queue entries and pushed onto the internal `Queue<_OutgoingEntry>`. `pendingChatGuids` (an `RxSet<String>`, used by UI to show/hide a "Cancel Outgoing Messages" control) gets the chat GUID added, then `_processNext()` is kicked off.

**`_buildOutgoingMessages()`** — on macOS versions older than Big Sur, a long text message containing a URL is split into two separate `Message`s (each with its own tempGuid) to prevent server-side matching glitches. This is the only case that produces more than one message per send.

**`_persistOutgoingMessages()`** saves each message to ObjectBox **with its tempGuid** via `chat.addMessage(message, clearNotificationsIfFromMe: ...)` — skipping the DB write if a retry finds the GUID already saved. This is intentional — the message appears in the UI immediately in a "sending" state before the server has confirmed anything. It also pushes the message into `MessagesSvc.addNewMessage()` (or, for a reaction, directly into the parent's `associatedMessages` via `addAssociatedMessageInternal`) and calls `ChatsSvc.updateChatLatestMessage()` so the chat tile subtitle updates immediately.

`prepAttachment()` copies the file from its source path (or writes staged bytes) to the app's attachment directory, optimizes GIFs, loads image metadata, stages interactive-message media if applicable, then saves the message to the DB and pushes it into `MessagesSvc` the same way.

**Key file:** `lib/services/backend/outgoing_message_handler.dart`

---

### Step 4 — OutgoingMessageHandler: Send (`outgoing_message_handler.dart`)

`OutgoingMessageHandler._processNext()` dequeues items one at a time (guarded by an `_isProcessing` flag so only one drain loop runs) and calls `_dispatchItem()`, which routes to `sendMessage()`, `sendMultipart()`, or `sendAttachment()` based on the concrete queue item type.

Each send method wraps its work in `_handleSend()`, which starts a 5-second timer that nudges `chat.sendProgress` to `0.9` if the send is still in flight (a "this is taking a while" UI signal), then drives it to `1 → 0` on completion — unless an earlier socket-triggered `completeSendProgressIfExists()` call already did so.

Each send method then calls `_sendWithRace()`, which does two things:

1. **Registers a send-progress tracker** keyed by tempGuid: `registerSendProgressTracker(tempGuid, chat, race)` where `race` is a `Completer<void>`.
2. **Fires the HTTP call** (via the domain-specific `SendMessageInterface` method — see Step 5) and races it against the socket echo. Both paths call `completeSendProgressIfExists(tempGuid, Origin.outgoingMessageHandler | Origin.incomingMessageHandler)` when they resolve — whichever arrives first wins and removes the tracker; the second arrival is a no-op. The `race` completer unblocks `_sendWithRace()`'s returned future, which is what `_processNext()` awaits before moving to the next queued item — **the HTTP callback's own follow-up work (GUID replacement, error marking) keeps running in the background after the race resolves**, it does not block the queue.

The tempGuid is passed to the server as the `tempGuid` field in the request body. The server echoes it back in the `"new-message"` socket event so the client can correlate the two.

**Key file:** `lib/services/backend/outgoing_message_handler.dart`

---

### Step 5 — HTTP Call to Server (interface → isolate → `HttpSvc.message`)

Outgoing HTTP calls do **not** go directly through `HttpService` from `OutgoingMessageHandler`. They follow the standard interface/isolate pattern:

```
OutgoingMessageHandler.sendMessage()/sendMultipart()/sendAttachment()
  → SendMessageInterface.sendTextMessage() / sendTapback() / sendMultipartMessage() / sendAttachmentMessage()
      (lib/services/backend/interfaces/send_message_interface.dart)
  → isIsolate ? SendMessageActions.<method>() : GlobalIsolate.send(IsolateRequestType.<method>, data)
      (lib/services/backend/actions/send_message_actions.dart — runs inside the isolate)
  → HttpSvc.message.sendText() / sendTapback() / sendMultipart() / sendAttachment()
      (lib/services/network/api/message_api.dart)
```

This keeps the actual `dio` call — and, for attachments, the file read and `FormData` construction — inside the isolate so an in-flight send survives the app being backgrounded.

Before firing, `sendMessage()`/`sendAttachment()` call `_resolveMethod()` to decide `"private-api"` vs `"apple-script"`: private API is used if the user has it globally enabled *and* the per-type setting is on, or if the message uses a feature only pAPI supports (subject, thread reply, or an expressive send-style effect) — subject/thread/effect force pAPI regardless of the toggle.

**Attachment upload progress** is reported from inside the isolate: `SendMessageActions.sendAttachmentMessage()`'s `onSendProgress` callback emits `IsolateEventEmitter.emit(IsolateEvent.attachmentUploadProgress, {chatGuid, messageGuid, progress})`. `OutgoingMessageHandler`'s constructor registers a listener for this event (`_handleAttachmentUploadProgressEvent`) that updates the observable `attachmentProgress` list and calls `MessagesSvc.notifyAttachmentUploadProgress()` so the attachment bubble's progress bar animates in real time.

**Key files:**
- `lib/services/backend/interfaces/send_message_interface.dart`
- `lib/services/backend/actions/send_message_actions.dart`
- `lib/services/network/api/message_api.dart`

---

### Step 6 — The Race: Two Paths to Confirmation

After the HTTP call fires, two things can happen concurrently. Whichever arrives first wins and hands off to the other.

---

#### Path A — Socket/Firebase/Method Channel fires BEFORE the HTTP response

The server sends a `"new-message"` socket event (or Firebase push on Android) with the real GUID and the original `tempGuid` in the payload.

`SocketService` routes this to `MessageHandlerSvc.handleEvent("new-message", data, source)` (`action_handler.dart`). The handler checks the payload for `tempGuid`:

- **If `tempGuid` is present:** The real GUID and the tempGuid are known. `IncomingMsgHandler.handle()` is called with the `tempGuid` set, which — inside `IncomingMessageHandler._processNewMessage()`/`_processUpdatedMessage()` — calls `OutgoingMsgHandler.completeSendProgressIfExists(tempGuid, Origin.incomingMessageHandler)`. This:
  - Removes the progress tracker from `_sendProgressTrackers`
  - Drives `chat.sendProgress` to `1` (then back to `0` after 500ms), unless it's already `0`
  - Completes the `race` completer, unblocking `_sendWithRace()` so `_processNext()` moves on
  - `IncomingMessageHandler` continues processing the payload (GUID swap) in its own queue, independent of the outgoing side

- **If `tempGuid` is null** (out-of-order event — the server sent the real GUID before the client registered the tracker, only possible when `message.isFromMe == true`): the real GUID is added to `MessageHandlerSvc.outOfOrderTempGuids` in `action_handler.dart`. The handler waits 500ms, then checks again. If a paired `updated-message` carrying the `tempGuid` arrived and removed the entry in the meantime, this `new-message` is dropped (the update handles it); otherwise it's processed as a regular new message.

When `IncomingMessageHandler` processes the item, `_processNewMessage()` routes to `_processUpdatedMessage()` for the GUID swap (see `docs/MESSAGE_RECEIVE_FLOW.md`) — this is on the **receive** side and is independent of `_matchMessageWithExisting()` below, though both end up converging on the same DB record.

---

#### Path B — HTTP response arrives BEFORE the socket event

The `httpCall().then(...)` callback in `_sendWithRace()` fires with the decoded response body:
```dart
completeSendProgressIfExists(tempGuid, Origin.outgoingMessageHandler);  // removes tracker, finishes progress
await onSuccess(data);   // caller's onSuccess parses Message.fromMap(data['data']) and calls _matchMessageWithExisting
```

For `sendMessage()`/`sendMultipart()`, `onSuccess` is `_finalizeOutgoingSuccess()`, which parses the server message and calls `_matchMessageWithExisting()`. For `sendAttachment()`, the success handling is inline (not via `_finalizeOutgoingSuccess`) because attachment GUID swaps (`_matchAttachmentWithExisting()`, per response attachment) must complete *before* the message GUID swap.

If the socket event has not yet arrived with the real GUID, the temp message is swapped for the real one here. If the socket event arrives afterward, `_processUpdatedMessage()` on the receive side finds the real GUID already in the DB and treats it as a parallel-delivery no-op/refresh rather than duplicating the swap.

---

### Step 7 — `_matchMessageWithExisting()`: The tempGuid → realGuid Swap

This private method on `OutgoingMessageHandler` handles both paths. It is safe to call from either (or both).

**Logic:**
1. Look up a message with the **real GUID** in the DB.
   - **If found (socket won the race):** if the HTTP response's message is newer than what's stored, replace it via `Message.replaceMessage(replacement.guid, replacement)`. Then if a distinct tempGuid record still exists, delete it and call `MessagesSvc.updateMessage(replacement, oldGuid: tempGuid)` to re-key the state map.
   - **If not found (normal path):** call `Message.replaceMessage(existingGuid, replacement)` → `MessageInterface.replaceMessage()` → the GlobalIsolate → ObjectBox atomically renames the record's GUID. Then call `MessagesSvc.updateMessage(saved, oldGuid: existingGuid)`.
   - **If that rename throws** (the temp record isn't found in the isolate's store at all — e.g. `prepMessage` failed silently): falls back to just `replacement.save()` (a fresh insert) and updates the UI treating it as a temp→real transition anyway, so the message is never permanently stuck.
2. If the chat's currently-tracked `latestMessage` still points at the old tempGuid, calls `ChatsSvc.updateChatLatestMessage()` with the confirmed message.
3. If the temp GUID had a staged interactive-media directory (handwritten/digital-touch messages), renames it from the temp path to the real-GUID path on disk so `EmbeddedMedia` finds the pre-staged local file instead of falling back to a server download.

The attachment counterpart, `_matchAttachmentWithExisting()`, does the analogous DB rename/parallel-delivery handling for attachment records and moves the attachment's on-disk directory from the temp path to the real path.

**Key file:** `lib/services/backend/outgoing_message_handler.dart` — `_matchMessageWithExisting()`, `_matchAttachmentWithExisting()`

---

### Step 8 — State Update and UI Rebuild

`MessagesSvc.updateMessage(realMessage, oldGuid: tempGuid)`:
1. Finds the `MessageState` keyed by `tempGuid`
2. Calls `messageState.updateFromMessage(realMessage)`:
   - `updateGuidInternal(realGuid)` — sets the GUID, auto-updates `isSending = false`, `isSent = true`
   - `updateErrorInternal(error)` — auto-updates `hasError` and (if `error == 0`) keeps `isSending` in sync with the current GUID prefix
   - All other changed fields (`dateDelivered`, etc.) updated via their own `*Internal()` methods
3. Re-keys the `messageStates` map: removes the `tempGuid` entry, inserts the same state object under the real GUID
4. Updates `messageUpdateTrigger[realGuid]` — widgets watching this rebuild

The `Obx()` wrapper around `isSending` in the message bubble widget rebuilds and removes the "sending" animation. The `Obx()` wrapper around `dateDelivered` rebuilds to show the delivery timestamp when it arrives.

**Key files:**
- `lib/services/ui/message/messages_service.dart` — `updateMessage()`
- `lib/app/state/message_state.dart` — `updateGuidInternal()`, `updateErrorInternal()`, `updateFromMessage()`

---

### Step 9 — Error Path

If the HTTP call fails, `_sendWithRace()`'s `onError` branch fires, which every send method routes to `_finalizeOutgoingFailure()`:

1. `completeSendProgressIfExists(tempGuid, Origin.outgoingMessageHandler, error: ..., stack: ...)` runs first (clears the tracker; completes the race with an error).
2. `handleSendError(error, m)` classifies the `DioException`/HTTP response and sets `m.error` / `m.errorMessage`. **The GUID is deliberately never mutated here** — it stays as the original `temp-XXXXXXXX` so it remains a stable reference through the retry lifecycle. (`isSending` still flips to `false` because `MessageState.updateErrorInternal()` gates on `error == 0`, not on the GUID prefix.)
3. If the app is backgrounded or the conversation isn't the active view, a "Failed to send" local notification is created via `NotificationsSvc.createFailedToSend()`.
4. `Message.replaceMessage(tempGuid, m)` persists the error state — since `m.guid` is still the tempGuid, this is an in-place field update, not a rename. If this throws (the socket already replaced the record), the error is logged and the original message is returned unchanged rather than propagating the exception.
5. `MessagesSvc.updateMessage(errorMsg, oldGuid: tempGuid)` propagates the failure to the UI; `ChatsSvc.updateChatLatestMessage()` is refreshed if this message was the chat's latest.
6. Type-specific `onExtra` callbacks run afterward — e.g. updating a reaction's parent message state, or clearing attachment upload progress and calling `notifyAttachmentTransferError()`.
7. Back in `_processNext()`'s `catchError`, if `SettingsSvc.settings.cancelQueuedMessages` is enabled, every other still-queued item for the same chat is pulled off the queue, marked `MessageError.BAD_REQUEST` with `"Canceled due to previous failure"`, and finalized the same way.

**User-initiated cancellation** (distinct from the auto-cancel-on-failure above): `OutgoingMessageHandler.cancelMessage(tempGuid)` / `cancelPendingForChat(chatGuid)` remove not-yet-dispatched items from `_queue` and finalize them via `_finalizeOutgoingFailure` with `ClientMessageError.userCanceled`. `hasPendingMessage(tempGuid)` lets the UI check whether a message can still be cancelled (once it's been dequeued for dispatch, it's in flight and can't be). `pendingChatGuids` is the reactive set backing a "Cancel Outgoing Messages" affordance in the UI.

---

## Key Files at a Glance

| Step | File | Key Method |
|------|------|-----------|
| Send button | `lib/app/layouts/conversation_view/widgets/text_field/send_button.dart` | `onPressed` callback |
| Build message | `lib/app/layouts/conversation_view/widgets/message/send_animation.dart` | `send()` |
| tempGuid generation | `lib/database/io/message.dart` | `generateTempGuid()` → `"temp-XXXXXXXX"` |
| Queue + prep + send | `lib/services/backend/outgoing_message_handler.dart` | `queue()`, `_ensureTempGuid()`, `_prepItemWithRetry()`, `_processNext()`, `_dispatchItem()` |
| Build/split messages | `lib/services/backend/outgoing_message_handler.dart` | `_buildOutgoingMessages()` |
| Save to DB (temp) | `lib/services/backend/outgoing_message_handler.dart` | `_persistOutgoingMessages()` / `prepAttachment()` → `chat.addMessage()` |
| HTTP dispatch | `lib/services/backend/outgoing_message_handler.dart` | `sendMessage()`, `sendMultipart()`, `sendAttachment()` |
| HTTP interface (isolate routing) | `lib/services/backend/interfaces/send_message_interface.dart` | `sendTextMessage()`, `sendTapback()`, `sendMultipartMessage()`, `sendAttachmentMessage()` |
| HTTP isolate actions | `lib/services/backend/actions/send_message_actions.dart` | same names, run inside isolate |
| Raw HTTP request | `lib/services/network/api/message_api.dart` | `sendText()`, `sendTapback()`, `sendMultipart()`, `sendAttachment()` |
| HTTP + socket race | `lib/services/backend/outgoing_message_handler.dart` | `_sendWithRace()`, `_handleSend()` |
| Progress tracker | `lib/services/backend/outgoing_message_handler.dart` | `registerSendProgressTracker()`, `completeSendProgressIfExists()` |
| Attachment upload progress | `lib/services/backend/outgoing_message_handler.dart` | `_handleAttachmentUploadProgressEvent()`, `attachmentProgress` |
| Out-of-order handling | `lib/services/backend/action_handler.dart` | `outOfOrderTempGuids`, 500ms grace period |
| tempGuid → realGuid swap | `lib/services/backend/outgoing_message_handler.dart` | `_matchMessageWithExisting()`, `_matchAttachmentWithExisting()` |
| DB swap | `lib/database/io/message.dart` + interfaces | `replaceMessage()` → `MessageInterface.replaceMessage()` |
| Error classification | `lib/helpers/network/network_error_handler.dart` | `handleSendError()` (never mutates the GUID) |
| Finalization | `lib/services/backend/outgoing_message_handler.dart` | `_finalizeOutgoingSuccess()`, `_finalizeOutgoingFailure()` |
| Cancellation | `lib/services/backend/outgoing_message_handler.dart` | `cancelMessage()`, `cancelPendingForChat()`, `hasPendingMessage()` |
| State update | `lib/services/ui/message/messages_service.dart` | `updateMessage(real, oldGuid: temp)` |
| UI rebuild | `lib/app/state/message_state.dart` | `updateGuidInternal()`, `updateErrorInternal()` → `isSending` |

---

## Deduplication Guarantees

- **`IncomingMessageHandler._processedGuids`** — a rolling ring-buffer of the last 100 GUIDs processed by `IncomingMessageHandler`. Prevents the same socket/FCM event from being processed twice (e.g. if Firebase and socket both deliver it).
- **`_matchMessageWithExisting()` real-GUID-first check** — before swapping, always checks whether a message with the real GUID already exists. If it does, the swap is a metadata update at most (never a duplicate insert). This makes both Path A and Path B safe to call, and safe to call twice.
- **`_persistOutgoingMessages()` GUID-exists check** — on a retried prep attempt, skips the DB write entirely if a message with that GUID is already saved, so retries never duplicate a message.
- **`_sendProgressTrackers` removal** — `completeSendProgressIfExists()` removes the tracker on first call. The second arrival (socket after HTTP, or HTTP after socket) finds no tracker and does nothing extra.
- **`outOfOrderTempGuids` with 500ms delay** — lives in `action_handler.dart`. Handles the edge case where the server emits `"new-message"` with a null `tempGuid` before the client has registered its tracker.
