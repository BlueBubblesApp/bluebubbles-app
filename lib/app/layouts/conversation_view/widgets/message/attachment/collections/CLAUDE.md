# attachment/collections/ — Media Collections

`MessagePart.isMediaCollection` → `MessagePartContent` → `resolveMediaCollectionLayout`
(`helpers/ui/message_widget_helpers.dart`).

User prefs `mediaCollectionLayoutSmall` (2–3) / `mediaCollectionLayoutLarge` (4+)
override when not `skinDefault` (Media Settings → Multi-Attachment Layout).

| Skin (Default) | Count | Layout |
|----------------|-------|--------|
| iOS | 2–3 | collage |
| iOS | 4+ | stack |
| Material / Samsung | 2+ | grid |

## Ownership

- Parents size the frame; `AttachmentHolder(fill: true)` fills it (popup skips fill).
- **Radii:** `CollectionAttachmentCard.mediaCardRadius` — iOS 20 / Material `M3EShapes.lg` / Samsung 25.
- **Collage / stack:** card owns skin radius + iOS-only soft shadow; collage tilt (~0.75°) is iOS-only. Reactions outside the clip.
- **Grid:** no card shadow; outer `ClipRRect` owns silhouette (same radius table); cells stay square. Reaction overlay above cells (author-edge, `tightOverhang`). Material/Samsung tighten author-edge corners when subject/body is adjacent; iOS stays full-radius + title.
- **Overview:** stack title / grid `+N` → `CollectionMediaController.openGallery`; collage only via fullscreen grid button. Cards pass `collectionController` into Fullscreen viewers (paging from `controller.media`); overview cells omit it purposefully so the grid button cannot nest.

## Grid layout (`collection_group_grid.dart`)

Three composable shapes on a shared 3-column grid (details in the `CollectionGroupGrid` class doc):

| Shape | Geometry |
|-------|----------|
| Banner | Full-width; height = `HeroStack(2)` × `4/3` |
| HeroStack(n) | 2-col hero + column of `n` squares (facing flips each hero) |
| SquareRow(n) | Full-width row of `n` equal squares |

**`+N` (count > 7):** tap → collection gallery; long-press → expand missing items in place.

## Files

| File | Purpose |
|------|---------|
| `collection_group_collage.dart` | Overlapping collage (iOS 2–3) |
| `collection_group_stack.dart` | Fan stack (iOS 4+) |
| `collection_group_grid.dart` | Grid (chrome + layout + reactions) |
| `collection_attachment_card.dart` | Shared card chrome + `fill` media + reactions |
| `collection_title.dart` | “X Photos/Videos/Items” label |
| `collection_download_button.dart` | Incoming download control (`CollectionDownloadButton.wrap`) |
| `collection_media_controller.dart` | `openGallery` → `CollectionMediaGridPage`; Fullscreen viewers pass-through from cards only |
| `collection_media_grid_page.dart` | Full-page collection gallery grid (`MediaGridSection`; no avatars; tapback overlays) |
