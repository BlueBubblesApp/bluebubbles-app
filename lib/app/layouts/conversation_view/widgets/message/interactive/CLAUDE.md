# interactive/ — Rich / Interactive Message Renderers

Handles messages with Apple payload data: URL previews, Apple Pay, Game Pigeon invitations, embedded media (maps, music, iBooks), and generic interactive types.

## Files

| File | Purpose |
|------|---------|
| `interactive_holder.dart` | **Entry point** — routes on `message.payloadData` type |
| `url_preview.dart` | Link previews — owns `UrlPreviewController`, dispatches to a skin |
| `url_preview_controller.dart` | All fetch/cache/policy wiring for the preview card |
| `cupertino_url_preview.dart` | iOS skin (20px corners, blur-fill image) |
| `expressive_url_preview.dart` | Material/Samsung skin, M3 Expressive |
| `apple_pay.dart` | Apple Pay request / confirmation UI |
| `game_pigeon.dart` | Game Pigeon game invitation card |
| `embedded_media.dart` | Maps, Apple Music, iBooks, and other embedded content types |
| `photo_slideshow.dart` | Photos app / iCloud shared album card. Falls back to a preview image fetched from the share URL (via `MetadataHelper.fetchForMessage(urlOverride:)`/`resolveCachedImage`, disk-cached) when the message has no attachment. Uses `MetadataCacheSlot.photoSlideshow`. |
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
- URL previews use `MetadataHelper.fetchForMessage()`, which returns a `MetadataFetchResult` and
  never throws — see `lib/helpers/network/metadata/CLAUDE.md`.
- Cached preview state is read/written through `MessageMetadataStore`, never by touching
  `message.metadata` keys directly.
- Transient fetch failures (`!result.shouldMarkAttempted`) must not be recorded as attempts, or
  the message loses its preview permanently.

## Skin Handling

`widgets/message/` uses **inline property branching**, not `ThemeSwitcher` and not per-skin files —
`iOS ? 30 : 35`, `skin.value == Skins.iOS ? 10 : 12.5`. `url_preview` is the one exception, because
its Material variant is M3 Expressive and genuinely differs in structure (no blur-fill, different
image crop, `M3ETonalButton` affordance), which ternaries express badly.

It still avoids `ThemeSwitcher`: that takes already-constructed widgets for every skin, so it would
allocate both variants per message per build. A plain `iOS ? Cupertino... : Expressive...` in
`build()` constructs only the one used. `ThemeSwitcher`'s `Obx` is redundant here anyway — changing
the app skin runs `ChatsSvc.setAllInactive()` first, tearing down open conversation views so they
rebuild against the new skin.

**Presentation only in the skin files.** Anything touching the network, the disk cache, the sender
policy or the retry TTL belongs on `UrlPreviewController`, including derived values like the site
line — that one is security-relevant and must never diverge between skins.

## Adding a New Interactive Type

1. Add the new `PayloadType` value to the enum in `lib/database/io/message.dart`.
2. Create `my_type.dart` in this directory.
3. Add a branch in `interactive_holder.dart`.
