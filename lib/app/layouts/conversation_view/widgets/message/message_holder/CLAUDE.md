# message_holder/ — Master Message Composition

`MessageHolder` is the outermost widget for each message row. It composes every sub-widget into the final rendered bubble.

## Files

| File | Purpose |
|------|---------|
| `../message_holder.dart` | Main widget; lives one level up in `widgets/message/` |
| `message_holder_wrappers.dart` | `SelectModeWrapper` — Obx wrapper for selection-mode checkbox visibility |
| `message_holder_reactions.dart` | `ReactionObserver`, `StickerObserver` — isolated Obx scopes for reactions and sticker overlays |
| `message_holder_timestamps.dart` | `SamsungTimestampObserver` — Samsung-only always-visible timestamp widget |
| `message_reactions.dart` | Positioned reaction row (renders above top-left or top-right of bubble) |
| `reply_bubble_section.dart` | Quoted-reply bubble shown above the message (iOS & Material) |

## Layout Structure

`MessageHolder` assembles this tree (simplified):

```
TimestampSeparator                ← large date header between days
Row
  SelectCheckbox (if not fromMe)
  Expanded → Column per messagePart:
    EditHistoryObserver
    ReplyBubbleSection            ← iOS: above bubble; Material: inline
    MessageSender                 ← group chats only, within 30-min window
    ReactionSpacing
    Stack:
      BubbleEffects               ← send effect animation overlay
      MessagePopupHolder          ← long-press menu trigger
      SwipeToReplyWrapper         ← swipe-right gesture
      TailClipper                 ← ClipPath for bubble tail shape
      MessagePartContent          ← text / attachment / interactive dispatcher
      MessageEditField            ← inline edit input (if editing)
      StickerObserver             ← sticker overlays
      MessageReactions            ← tapback row
    MessageProperties             ← effect label, reply count, edit indicator
DeliveredIndicator                ← bottom-right (sent/delivered/read)
```

## Key Getters

- `showSender` — true if group chat, different sender from previous message, and within 30-min window
- `canSwipeToReply` — requires Private API enabled + Big Sur sync; false for temp/error messages
- `replyTo` — fetches reply target from `MessagesService.struct`
- `messageParts` — `List<MessagePart>` from `MessageState.parts`, passed through `_collapseMediaCollectionParts` for multi-attachment collections

## Reactivity

The main `Obx()` observes `MessageState`: `isSending`, `isFromMe`, `associatedMessages`.

Smaller inner widgets use their own `Obx()` scopes to avoid rebuilding the whole holder on narrow state changes (e.g., only reactions changed).

## Widget Pattern

`MessageHolder` is a plain `StatefulWidget`. It receives a `MessageState ms` directly as a constructor parameter.

```dart
class MessageHolder extends StatefulWidget {
  final MessageState ms; // pre-created by MessagesService
  ...
}

class _MessageHolderState extends State<MessageHolder> with ThemeHelpers {
  MessageState get controller => widget.ms;
}
```

Per-part UI data (reply offsets, animation keys) are stored as `_MessageHolderState` instance lists — not in the state object — to keep `MessageState` clean.

## Skin Branching

No `ThemeSwitcher` here — message widgets branch inline using the `iOS`, `material`, `samsung` boolean getters from `ThemeHelpers`:
- iOS: no bubble tails, reply-lines drawn by painter
- Material: bubble tails via `TailClipper`
- Samsung: always-visible timestamp via `SamsungTimestampObserver`
