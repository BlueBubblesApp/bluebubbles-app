# conversation_view/widgets/effects/ — Send Effect UI

UI for selecting and displaying iMessage send effects (balloon, confetti, echo, etc.).

## Files

| File | Purpose |
|------|---------|
| `screen_effects_widget.dart` | Full-screen animated overlay that plays a send effect (rendered on top of the conversation) |
| `send_effect_picker.dart` | Picker sheet that lists available effects; lets user choose before sending |

## Effect Definitions
The animation classes and renderers live in `lib/app/animations/` → `CLAUDE.md` inside.
Effect name ↔ Apple code mapping: `lib/helpers/types/constants.dart` (`effectMap`).

## Trigger
`ScreenEffectsWidget` plays whatever arrives on the `play-effect` event (`{'type': <effect name>,
'size': <bubble Rect>}`). The only emitter is `BubbleEffects` (part 0 of a message), which owns the
bubble's `GlobalKey` and therefore its rect.

Two things reach it:
- **Auto-play** — `MessagesService.playPendingScreenEffect()` bumps `MessageState.playScreenEffect`
  for the newest unplayed screen-effect message when a chat is opened, when a message arrives, or on
  app resume. Only the newest one, since these cover the whole conversation, and only within
  `effectMaxAge` (72h) of arrival. (Bubble effects share that age cutoff but not the newest-only
  rule: every unplayed one plays, handled by `BubbleEffects` itself.)
- **Manual replay** — tapping "sent with \<effect\>" in `MessageProperties`, which calls
  `MessageState.triggerEffect()`.

`echo` never reaches this widget (`MessageEffect.isScreen` excludes it): there is no renderer for it,
and a selection this widget can't clear would block every effect after it.

## Related
- Animation renderers: `lib/app/animations/CLAUDE.md`
- Send flow: `docs/MESSAGE_SEND_FLOW.md`
