# interactive/ — Rich / Interactive Message Renderers

Handles messages with Apple payload data: URL previews, Apple Pay, Game Pigeon invitations, embedded media (maps, music, iBooks), and generic interactive types.

## Files

| File | Purpose |
|------|---------|
| `interactive_holder.dart` | **Entry point** — routes on `message.payloadData` type |
| `url_preview.dart` | Link previews |
| `apple_pay.dart` | Apple Pay request / confirmation UI |
| `game_pigeon.dart` | Game Pigeon game invitation card |
| `embedded_media.dart` | Maps, Apple Music, iBooks, and other embedded content types |
| `photo_slideshow.dart` | Photos app / iCloud shared album card. Falls back to an OG preview image fetched from the share URL (via `MetadataHelper.fetchMetadata(urlOverride:)`/`resolveCachedImage`, disk-cached) when the message has no attachment. |
| `supported_interactive.dart` | Generic fallback for known-but-unsupported interactive types |
| `unsupported_interactive.dart` | Fallback for completely unknown interactive types |

## Routing Logic

`InteractiveHolder` inspects `message.payloadData`:

```
PayloadType.url          → UrlPreview (or UrlPreview.legacy for old servers)
PayloadType.applePay     → ApplePay
PayloadType.gamePigeon   → GamePigeon
PayloadType.embeddedMedia → EmbeddedMedia (maps, music, etc.)
(known type)             → SupportedInteractive
(unknown)                → UnsupportedInteractive
```

Called from `MessagePartContent` when `message.hasApplePayloadData || message.isInteractive`.

## Key Patterns

- All interactive widgets use `AutomaticKeepAliveClientMixin` to preserve state during scroll (prevents re-fetching URL metadata on every scroll).
- Tap handling is wrapped in `Obx()` to observe selection mode — in selection mode, taps select the message rather than triggering the interactive action.
- URL previews use `MetadataHelper.fetchMetadata()` (cached) — see `lib/helpers/network/CLAUDE.md`.

## Adding a New Interactive Type

1. Add the new `PayloadType` value to the enum in `lib/database/io/message.dart`.
2. Create `my_type.dart` in this directory.
3. Add a branch in `interactive_holder.dart`.
