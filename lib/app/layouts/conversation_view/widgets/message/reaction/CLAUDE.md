# reaction/ — Tapback Display

Renders the tapback emoji row that appears above or below a message bubble.

## Files

| File | Purpose |
|------|---------|
| `reaction.dart` | `ReactionWidget` — single tapback emoji with skin-specific styling |
| `reaction_holder.dart` | Horizontal row container for all reactions on a message part |
| `reaction_clipper.dart` | `CustomClipper` for the pill-shaped reaction bubble |

## Data Source

Reactions come from `MessageState.associatedMessages` (an `RxList<Message>`). Each associated message with `associatedMessageType` matching a tapback type (e.g., `"love"`, `"thumbsup"`) is a reaction.

Use `ReactionTypes` string constants (from `lib/helpers/ui/`) — never hardcode reaction type strings.

## Key Pattern

`ReactionWidget` looks up the reaction by GUID or by `(type, part, isFromMe)` tuple:
- iOS: solid circle, no border
- Material: solid circle with border

The widget observes its reaction's `MessageState` so it re-renders when a temp GUID is swapped for a real one or when error state changes.

## Placement

`ReactionHolder` is placed as a `Positioned` overlay inside the bubble `Stack` in `MessageHolder`. The x/y offset is calculated based on `isFromMe` (left or right alignment) and the bubble size.

## Sending a Tapback

Sending is triggered from `MessagePopup` → calls `MessageInterface.sendTapback(message, reactionType, partIndex)`. The new reaction arrives back through the incoming message flow and updates `MessageState.associatedMessages`.
