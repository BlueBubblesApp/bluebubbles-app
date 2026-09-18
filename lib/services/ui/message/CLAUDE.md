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

- `playPendingScreenEffect({delay})` — auto-plays the chat's newest screen effect if it hasn't been played

**Convenience getters:**
- `mostRecentSent` — the most recently sent outgoing message
- `mostRecent` — the most recent message in the thread
- `mostRecentReceived` — the most recent incoming message

**Rules:**
- Never write `MessageState` fields directly from UI — always go through `MessagesService.updateMessage()`
- Widgets should observe `messageUpdateTrigger[guid]` in an `Obx()` to know when to re-query state
- For bulk initial load, use `addMessages()` which skips per-field update overhead

## Send Effect Auto-Play

The two kinds of send effect have deliberately different auto-play policies, but share one
persisted flag (`Message.hasEffectPlayed`) — a message carries exactly one effect, so there is
never a row where both meanings apply — and one staleness cutoff, `effectMaxAge` (72h).

| | Bubble effects (slam, loud, gentle) | Screen effects (balloons, confetti, spotlight, ...) |
|---|---|---|
| What plays | Every unplayed one | Only the newest one |
| Age cutoff | `effectMaxAge` | `effectMaxAge` |
| Who decides | `BubbleEffects.initState` per bubble | `MessagesService.playPendingScreenEffect()` |
| Flagged played | Each message, when its animation completes | Only the newest screen-effect message |

**Invisible ink is neither** — it's a resting state that hides its bubble until swiped, not a
one-shot animation, so it renders on every appearance regardless of age or `hasEffectPlayed`.

Bubble effects need no coordination: each animates its own bubble, so it plays when its message
appears and flags itself. Screen effects animate over the whole conversation, so only one can
meaningfully play — `playPendingScreenEffect()` is called from `MessagesView` on the chat's initial
load, on a message arriving in the open chat, and on the app resuming onto an already-open chat, and
behaves the same way for all three:

1. Take the **newest** screen-effect message in the chat (`pendingScreenEffectMessage`, in
   `helpers/ui/message_effect_helpers.dart`). Older ones are never candidates.
2. If it has already been played, or is older than `effectMaxAge` (72h), do nothing.
3. Otherwise wait out `delay` (so the bubble is laid out — spotlight/love/lasers need its rect),
   play it via `MessageState.triggerEffect()`, and flag it played.

Only that newest message ever gets flagged, and that is deliberate: it acts as a high-water mark, so
a chat full of never-played historical screen effects stays quiet, while one that arrived while the
chat was closed or backgrounded still plays on the next open or resume. Playback is skipped — and
crucially *not* flagged — in two cases: while `ChatsSvc.isChatActive(chat.guid)` is false (which is
what defers a backgrounded chat's screen effect to resume), and when the message is too old (which
needs no flag, since it only gets older).

**For the full update flow**, see `docs/MESSAGE_RECEIVE_FLOW.md`.
