# attachment/ — Attachment Renderers

Renders all non-text media inside message bubbles. Entry point: `AttachmentHolder`, which dispatches to the appropriate renderer based on MIME type.

## Files

| File | Purpose |
|------|---------|
| `attachment_holder.dart` | **Entry point** — MIME type dispatcher; manages download state |
| `collection_attachment_card.dart` | Per-card popup, tapback, and swipe-to-reply wrapper for media collections |
| `message_image_collage.dart` | 2–3 item vertical overlapping collage (iOS skin) |
| `message_image_stack.dart` | 4+ item swipeable fan stack (iOS skin) |
| `message_image_grid.dart` | Multi-attachment grid layout (Material / Samsung skins) |
| `image_viewer.dart` | Images with tap-to-fullscreen gesture |
| `video_player.dart` | Video playback with custom controls |
| `audio_player.dart` | Audio playback with progress bar |
| `contact_card.dart` | Contact / vCard display |
| `sticker_holder.dart` | Sticker rendering (full-size emoji-like overlays) |
| `other_file.dart` | Generic file display for docs, archives, APKs, etc. |
| `live_photo_mixin.dart` | Mixin for handling Live Photo metadata |

## Key Patterns

**Download state**: `AttachmentHolder` holds an `Rx<dynamic> content` that is `null` until downloaded. Observes `AttachmentDownloadController` for progress updates. Auto-download is gated by `AttachmentsSvc.canAutoDownload()`.

**Controller**: Extends `CustomStateful<MessageWidgetController>`. Always set `forceDelete = false` in `initState()` — the message list owns the controller lifecycle.

**Fullscreen**: Tap on `ImageViewer` or `VideoPlayer` pushes `FullscreenMedia` via `NavigationSvc`. See `lib/app/layouts/fullscreen_media/CLAUDE.md`.

**Media collections**: Multi-attachment image/video parts (`isMediaGallery`) are formed in `MessageHolder._collapseImageGalleryParts` (all skins) and route by skin:

- **iOS**: `MessageImageCollage` (2–3 items) or `MessageImageStack` (4+ fan stack).
- **Material / Samsung**: `MessageImageGrid` — single rounded card containing a gap-separated grid. Cells have square edges (no per-cell rounding) and images use cover fit to fill each cell. Layout: 2 items side-by-side; 3 items with a prominent top row; 4+ with a prominent top row and a bottom row (left = 2nd image, right = vertical stack of the rest). Caps at five visible cells; the fifth shows a `+N` overlay when more attachments exist.

Each card is a `CollectionAttachmentCard` with its own `MessagePopupHolder` and `CollectionAttachmentReactions`. The outer `MessagePopupHolder` in `MessageHolder` defers gestures (`enableGestures: false`) for all gallery parts; tapbacks are card-local, not bubble-level. iOS collage cards also get per-card swipe-to-reply (`enableSwipeToReply: true`); the outer bubble-level swipe is disabled for iOS collages. Grid cells do not get per-card swipe-to-reply. iOS stack (4+) keeps outer bubble swipe to avoid conflicting with fan navigation.

## Adding a New Attachment Type

1. Add the MIME type check to `attachment_holder.dart`'s dispatcher.
2. Create `my_type_renderer.dart` in this directory.
3. The renderer receives the `Attachment` object and optionally a download `content` callback.

## Stickers vs Attachments

Stickers (`associatedMessageType == "sticker"`) are **not** routed through `AttachmentHolder`. They are rendered by `StickerObserver` (in `message_holder/`) as overlays positioned above the bubble.
