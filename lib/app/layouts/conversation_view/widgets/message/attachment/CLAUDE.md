# attachment/ — Attachment Renderers

Renders all non-text media inside message bubbles. Entry point: `AttachmentHolder`, which dispatches to the appropriate renderer based on MIME type.

Multi-attachment **collections** live in `collections/` → [CLAUDE.md](collections/CLAUDE.md).

## Files

| File | Purpose |
|------|---------|
| `attachment_holder.dart` | **Entry point** — MIME type dispatcher; manages download state |
| `image_viewer.dart` | Images with tap-to-fullscreen gesture |
| `video_player.dart` | Video playback with custom controls |
| `audio_player.dart` | Audio playback with progress bar |
| `contact_card.dart` | Contact / vCard display |
| `sticker_holder.dart` | Sticker rendering (full-size emoji-like overlays) |
| `other_file.dart` | Generic file display for docs, archives, APKs, etc. |
| `live_photo_mixin.dart` | Mixin for handling Live Photo metadata |
| `collections/` | Multi-attachment collage / stack / grid → CLAUDE.md |
| `parts/` | Per-transfer-state renderers for a single attachment slot → CLAUDE.md |

## Key Patterns

**Download state**: `AttachmentHolder` holds an `Rx<dynamic> content` that is `null` until downloaded. Observes `AttachmentDownloadController` for progress updates. Auto-download is gated by `AttachmentsSvc.canAutoDownload()`.

**`fill`**: When true, cover-expands into a parent-fixed frame and skips standalone bubble chrome. Collection parents own clip/shadow — see [collections/CLAUDE.md](collections/CLAUDE.md).

**Controller**: Extends `CustomStateful<MessageWidgetController>`. Always set `forceDelete = false` in `initState()` — the message list owns the controller lifecycle.

**Fullscreen**: Tap on `ImageViewer` or `VideoPlayer` pushes `FullscreenMedia` via `NavigationSvc`. See `lib/app/layouts/fullscreen_media/CLAUDE.md`.

## Adding a New Attachment Type

1. Add the MIME type check to `attachment_holder.dart`'s dispatcher.
2. Create `my_type_renderer.dart` in this directory.
3. The renderer receives the `Attachment` object and optionally a download `content` callback.

## Stickers vs Attachments

Stickers (`associatedMessageType == "sticker"`) are **not** routed through `AttachmentHolder`. They are rendered by `StickerObserver` (in `message_holder/`) as overlays positioned above the bubble.
