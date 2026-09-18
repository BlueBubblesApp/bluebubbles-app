# misc/ — Message Utilities & Composition Dispatcher

Shared utilities that don't belong to a single message type. The most important file here is `message_part_content.dart`, which decides what to render for each part of a message.

## Files

| File | Purpose |
|------|---------|
| `message_part_content.dart` | **Central dispatcher** — routes each message part to text, attachment, or interactive |
| `message_properties.dart` | Effect label, reply count badge, edit indicator (below bubble) |
| `message_sender.dart` | Sender name row in group chats |
| `bubble_effects.dart` | Send-effect animation overlays (balloon, confetti, fireworks, etc.) |
| `tail_clipper.dart` | `ClipPath` painter for rounded bubble tail shape (Material only) |
| `slide_to_reply.dart` | Small swipe-left indicator chevron |
| `swipe_to_reply_wrapper.dart` | `GestureDetector` wrapper that triggers reply on swipe-right |
| `select_checkbox.dart` | Selection-mode checkbox (left side for received, right for sent) |
| `message_edit_field.dart` | Inline edit `TextField` with confirm / cancel actions |

## Central Dispatcher: `MessagePartContent`

```dart
if (message.hasApplePayloadData || message.isInteractive)
  → InteractiveHolder          // Apple Pay, Game Pigeon, URL preview, maps
else if (messagePart.text != null)
  → TextBubble                 // plain / attributed text
else if (messagePart.attachments.isNotEmpty)
  → AttachmentHolder           // image, video, audio, sticker, file
else
  → SizedBox.shrink()          // empty part (renders nothing)
```

Called once per `MessagePart` inside the `messageParts.mapIndexed` loop in `MessageHolder`.

## Adding a New Message Part Type

1. Add detection logic to `message_part_content.dart` (check `message` or `messagePart` properties).
2. Create the renderer widget in the appropriate subdirectory (`interactive/`, `attachment/`, etc.).
3. The new branch goes into the `if/else` chain in `MessagePartContent.build()`.

## Swipe-to-Reply

`SwipeToReplyWrapper` wraps the entire bubble Stack. On swipe-right:
1. Animates `slide_to_reply.dart` indicator
2. Calls `cvController.setReplyToMessage(message)` to populate the reply bar in the text field

## Bubble Effects

`BubbleEffects` wraps every bubble and owns **both** kinds of send effect for that message:

- **Bubble effects** (slam, loud, gentle) — a one-shot animation on the bubble itself. **This widget
  owns their auto-play**: an unplayed one that passes `isEffectRecent()` animates on its bubble's
  first laid-out frame and flags itself via `markEffectPlayed()` when it completes. *Every* unplayed
  recent one plays, because each is confined to its own bubble. A stale one is skipped and left
  unflagged — it only gets older, so it keeps failing the check on its own. Replays arrive via
  `MessageState.playEffectPart` matching this widget's part index.
- **Screen effects** (balloons, confetti, spotlight, ...) — this widget only *dispatches* them. The
  part-0 widget listens to `MessageState.playScreenEffect` and emits `play-effect` with the bubble's
  on-screen rect for `ScreenEffectsWidget` to render. It skips registering inside a
  `MessageCloneScope` so the popup's clone doesn't fire the effect a second time. *When* one plays is
  decided by `MessagesService.playPendingScreenEffect()` — they cover the whole conversation, so only
  the newest unplayed one in a chat ever fires.
- **Invisible ink** is neither: it's a resting state, so it covers the bubble on first appearance
  regardless of `hasEffectPlayed` *or* age, and clears when swiped (recorded via `datePlayed`).

`isPreview: true` (send-effect picker only) keeps a throwaway preview bubble animating without
persisting its stand-in `Message` as played.

Use `effectOf(message)` / `effectNameOf(message)` from `helpers/ui/message_effect_helpers.dart` to
resolve a message's effect — don't re-derive it from `effectMap` inline.
