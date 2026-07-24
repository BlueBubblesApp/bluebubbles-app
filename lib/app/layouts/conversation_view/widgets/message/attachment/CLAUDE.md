# attachment/ — Attachment Renderers

Renders all non-text media inside message bubbles. Entry point: `AttachmentHolder`, which dispatches to the appropriate renderer based on MIME type.

## Files

| File | Purpose |
|------|---------|
| `attachment_holder.dart` | **Entry point** — MIME type dispatcher; manages download state |
| `collection_attachment_card.dart` | Per-card popup, tapback, and swipe-to-reply wrapper for media collections |
| `collection_download_button.dart` | Incoming-only circular download control shared by collage/stack |
| `collection_media_grid_page.dart` | Full-page grid for a message collection (reuses `MediaGridSection`) |
| `message_image_collage.dart` | Vertical overlapping collage (any count ≥ 2) |
| `message_image_stack.dart` | Swipeable fan stack (any count ≥ 2) |
| `message_image_grid.dart` | Google Messages–style multi-attachment grid |
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

**Media collections**: Multi-attachment image/video parts (`isMediaGallery`) are formed in `MessageHolder._collapseImageGalleryParts` (all skins). Routing uses `resolveMediaCollectionLayout(count)` from Media Settings (**Multi-Attachment Layout**):

- Prefs: `mediaCollectionLayoutSmall` (2–3 items) and `mediaCollectionLayoutLarge` (4+), each `skinDefault` | `collage` | `stack` | `grid`
- `skinDefault` preserves historical behavior: iOS → Collage (2–3) / Stack (4+); Material/Samsung → Grid
- Explicit values force that layout regardless of skin

Widgets: `MessageImageCollage`, `MessageImageStack`, `MessageImageGrid`

Each card is a `CollectionAttachmentCard` with its own `MessagePopupHolder` and `CollectionAttachmentReactions`. The outer `MessagePopupHolder` in `MessageHolder` defers gestures (`enableGestures: false`) for all gallery parts; tapbacks are card-local, not bubble-level.

**Collage / stack / grid card sizing**:

- **Collage:** Locked per-card frames from each attachment’s `displayWidth`/`displayHeight` (mixed portrait/landscape OK). Media cover-fills via `fillCard` so load does not resize cards.
- **Stack:** Shared portrait **3:4** frame for every fan/past slot; media cover-fills via `fillCard`.
- **Grid:** Predetermined cell geometry with `inGridCell` (same cover-fill path; no card shadow).

The stack "**X Items**" label and grid "**+N**" overlay open `CollectionMediaGridPage`. Fullscreen viewers opened from a collection (`galleryAttachments`) also show a grid button that opens the same page.

## Adding a New Attachment Type

1. Add the MIME type check to `attachment_holder.dart`'s dispatcher.
2. Create `my_type_renderer.dart` in this directory.
3. The renderer receives the `Attachment` object and optionally a download `content` callback.

## Stickers vs Attachments

Stickers (`associatedMessageType == "sticker"`) are **not** routed through `AttachmentHolder`. They are rendered by `StickerObserver` (in `message_holder/`) as overlays positioned above the bubble.
