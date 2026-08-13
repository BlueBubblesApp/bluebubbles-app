# services/ui/chat/ — Chat List & Conversation State

## Files
| File | Purpose |
|------|---------|
| `chats_service.dart` | Global chat list state — the source of truth for all `ChatState` objects |
| `conversation_view_controller.dart` | Per-chat controller for the active conversation screen |
| `message_list_gate.dart` | FIFO gate that defers message list mutations while a send animation is in flight |

---

## ChatsService (`chats_service.dart`)

GetIt singleton. Accessed via `ChatsSvc`.

**What it owns:**
- `chatStates` — `Map<String, ChatState>` keyed by chat GUID; every `ChatState` lives here
- `_sortedChats` — ordered list of chats for the conversation list UI
- `chatListVersion` — `RxInt` that increments when sort order changes; conversation list `Obx()` watches this

**Key methods:**
- `updateChat(Chat, {override})` — merges a chat update into its `ChatState` and repositions if needed
- `getChatState(String guid)` → `ChatState?` — the standard way to get reactive state for a chat
- `setAllInactive()` — marks all chats as not active (called when navigating away)
- `getActiveChat()` → `ChatState?` — the currently open chat

**Loading:** Chats are loaded in batches of 100 (`loadChats()`). After the initial load, incremental updates come through `updateChat()`.

**Rules:**
- Never write to a `ChatState` directly from UI — always call a `ChatsService` method
- Never sort the chat list manually — call `updateChat()` and let the service reposition
- To read the chat list in a widget: `Obx(() => ChatsSvc.sortedChats)` gated on `chatListVersion`

---

## ConversationViewController (`conversation_view_controller.dart`)

GetX controller, one instance per open chat. Accessed via `cvc(chat)` helper or `Get.find<ConversationViewController>(tag: chat.guid)`.

**What it owns:**
- `pickedAttachments` — files staged for sending
- `replyToMessage` — the message being replied to
- `editing` mode flag
- `AutoScrollController` for the message list scroll position
- Media caches: sticker widgets, video players, audio players (keyed by attachment GUID)

**Key properties:**
- `isAlive` — `RxBool`; false when the view is popped. Check this before posting to the controller.
- `sendFunc` — callback registered by `SendAnimation`; call `controller.send(...)` to trigger it

**Lifecycle:** Created when a conversation opens, closed when it pops. A conversation can remain "alive" in the background when in tablet mode.

**Rule:** Never hold a direct reference to `ConversationViewController` across navigations — always re-fetch via `cvc(chat)`.

---

## MessageListGate (`message_list_gate.dart`)

One instance per `ConversationViewController`, reached as `controller.messageListGate`.

`SendAnimation` flies a bubble from the text field to the bottom of the message list, aiming at a target computed from the live layout of the rows below the list. Anything that mutates the list or those rows mid-flight moves that target and makes the bubble land wrong. The gate defers that work instead.

**API:** `hold()` closes it, `run(work)` submits, `release()` opens it and replays the queue in order, `dispose()` releases permanently.

**It is not a lock.** No caller ever awaits it and it can never delay a send. While open (the normal case) `run()` executes inline. While held, work queues and replays in submission order as soon as the gate opens. A watchdog force-releases after 2s so a lost `release()` can't strand queued messages.

**Rules:**
- Anything representing the send itself must bypass the gate — the send takes precedence over everything.
- Only submit work that is order-independent with respect to bypassing work. Insertions qualify (`_applyNewMessage` re-sorts and recomputes the index); removals do not — see the comment on `MessagesView.handleDeletedMessage`.

Full rationale and the current list of gated/bypassing call sites: **Step 8b** of `docs/MESSAGE_RECEIVE_FLOW.md`.
