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
  → CollectionGroup*           // isMediaCollection → collage/stack/grid via resolveMediaCollectionLayout
  → AttachmentHolder           // otherwise: image, video, audio, file
else
  → SizedBox.shrink()          // empty part (renders nothing)
```

Media collections: `../attachment/collections/CLAUDE.md`.

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

`BubbleEffects` plays a one-shot animation overlay on top of the bubble. Triggered when `message.expressiveSendStyleId` is set (e.g., `com.apple.MobileSMS.expressivesend.balloons`). Uses `AnimationController` tied to `initState` — effect plays once and disappears.
