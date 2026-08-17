# helpers/ui/ — UI Utility Functions

Pure helper functions and small utility classes for the UI layer. No service dependencies; no state.

## File Routing

| File | What's inside |
|------|---------------|
| `ui_helpers.dart` | General widget utilities; custom back button with gesture support |
| `theme_helpers.dart` | `HexColor` (hex string → `Color`), `BubbleColors` theme extension, desktop window effects (Mica/acrylic) |
| `message_widget_helpers.dart` | `buildMessageSpans()` — rich text rendering with emoji scaling, mention detection, and styled spans for message bubbles |
| `message_effect_helpers.dart` | `effectOf()` / `effectNameOf()` — resolve a message's send effect; `newestScreenEffectMessage()` / `pendingScreenEffectMessage()` — pick the one screen effect in a chat that should auto-play |
| `attributed_body_helpers.dart` | Extracts audio transcripts from `AttributedBody` rich text; parses `Run` objects by part number |
| `reaction_helpers.dart` | `ReactionTypes` — string constants for iMessage tapbacks (`love`, `like`, `dislike`, `laugh`, `emphasize`, `question`) and their verb forms |
| `facetime_helpers.dart` | `showFaceTimeOverlay()` / `hideFaceTimeOverlay()` — incoming FaceTime call UI overlay |
| `oauth_helpers.dart` | Google OAuth flow; platform-branched: `GoogleSignIn` on Android, `DesktopWebviewAuth` on Desktop |
| `async_task.dart` | Lightweight async task wrapper for fire-and-forget UI work |
| `dialog_helpers.dart` | Shared `AlertDialog`/`showDialog` builders reused across settings and chat UI |
| `findmy_helpers.dart` | Find My UI helper functions |
| `redacted_mode_helpers.dart` | Text/name redaction for privacy (Redacted Mode setting) |
| `system_ui_overlay_style_helpers.dart` | Status bar / system UI overlay styling per skin |

## Key Usage Notes

**Message text rendering** — always use `buildMessageSpans()` from `message_widget_helpers.dart` to render message text inside bubbles. It handles emoji font sizing, mention highlighting, and URL styling consistently.

**Bubble colors** — `BubbleColors` is a `ThemeExtension`; access via `Theme.of(context).extension<BubbleColors>()`. Don't hardcode bubble colors.

**Hex colors** — `HexColor("#RRGGBB")` or `HexColor("#AARRGGBB")` converts hex strings to Flutter `Color` objects.

**Send effects** — resolve a message's effect with `effectOf(message)` rather than looking its
`expressiveSendStyleId` up in `effectMap` inline. `MessageEffect.isBubble` / `.isScreen` split the
two kinds, which auto-play under different rules: every unplayed bubble effect plays (handled by
`BubbleEffects`), but only the newest unplayed screen effect does. Both are gated on
`isEffectRecent()` (`effectMaxAge`, 72h) so a stale effect never ambushes the user;
`pendingScreenEffectMessage()` is the pure selection rule for screen effects, applied by
`MessagesService.playPendingScreenEffect()`. Invisible ink is exempt from all of it — it's a resting
state, not a one-shot animation.

**Reaction type constants** — use `ReactionTypes.LOVE`, `ReactionTypes.LIKE`, etc. instead of raw strings. The verb map (`reactionToVerb`) maps type → "loved", "liked", etc. for display.

**Desktop window effects** — window blur/acrylic effects are in `theme_helpers.dart`; only invoke on supported desktop platforms.
