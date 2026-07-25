# attachment/collections/ — Media Collection Layouts

Multi-attachment image/video parts (`isMediaGallery`) formed in `MessageHolder._collapseImageGalleryParts`. Routed via `resolveMediaCollectionLayout(count)` from Media Settings (**Multi-Attachment Layout**).

## Files

| File | Purpose |
|------|---------|
| `collection_layout_metrics.dart` | Shared sizing: `collectionCardWidth`, author-edge insets |
| `collection_group_collage.dart` | Vertical overlapping collage (any count ≥ 2) |
| `collection_group_stack.dart` | Swipeable fan stack (any count ≥ 2) |
| `collection_group_grid.dart` | Google Messages–style multi-attachment grid |
| `collection_attachment_card.dart` | Per-card popup, tapbacks, and swipe-to-reply wrapper |
| `collection_download_button.dart` | Incoming-only circular download control; collage/stack/grid place it via `CollectionDownloadButton.wrap` |
| `collection_media_grid_page.dart` | Full-page grid for a message collection (reuses `MediaGridSection`) |

## Layout routing

Prefs: `mediaCollectionLayoutSmall` (2–3 items) and `mediaCollectionLayoutLarge` (4+), each `skinDefault` | `collage` | `stack` | `grid`.

- `skinDefault` preserves historical behavior: iOS → Collage (2–3) / Stack (4+); Material/Samsung → Grid
- Explicit values force that layout regardless of skin

Dispatcher: `MessagePartContent` → `CollectionGroupCollage` / `CollectionGroupStack` / `CollectionGroupGrid`.

## Card sizing

- **Collage:** Locked per-card frames from each attachment’s `displayWidth`/`displayHeight` (mixed portrait/landscape OK). Uses `AttachmentFrameMode.fixedCard` so media cover-fills without resizing cards on load.
- **Stack:** Shared portrait **3:4** frame for every fan/past slot; same `fixedCard` cover-fill.
- **Grid:** Predetermined cell geometry with `AttachmentFrameMode.gridCell` (same cover-fill path; parent clips; no card shadow).

Each card is a `CollectionAttachmentCard` with its own `MessagePopupHolder` and `CollectionAttachmentReactions`. The outer `MessagePopupHolder` in `MessageHolder` defers gestures (`enableGestures: false`) for all gallery parts; tapbacks are card-local, not bubble-level.

The stack "**X Items**" label and grid "**+N**" overlay open `CollectionMediaGridPage`. Fullscreen viewers opened from a collection (`galleryAttachments`) also show a grid button that opens the same page.

## Related

- Single-attachment renderer: `../attachment_holder.dart`
- Pref resolution: `lib/helpers/ui/message_widget_helpers.dart` → `resolveMediaCollectionLayout`
- Enum: `lib/helpers/types/constants.dart` → `MediaCollectionLayout`
