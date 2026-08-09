# collections/ — Multi-Attachment Media Layouts

Renders a message part with 2+ media attachments as a collage, fan stack, or grid
(instead of individual `AttachmentHolder`s). Dispatched from `MessagePartContent`
when `MessagePart.isMediaCollection`.

## Files

| File | Purpose |
|------|---------|
| `collection_group_collage.dart` | Overlapping collage (skin-default iOS 2–3) |
| `collection_group_stack.dart` | Fan stack (skin-default iOS 4+) |
| `collection_group_grid.dart` | Grid (skin-default Material/Samsung 2+; chrome + layout + reactions) |
| `collection_attachment_card.dart` | Shared card chrome + `fill` media + per-attachment reactions |
| `collection_title.dart` | Tappable “X Photos/Videos/Items” label (callers gate to iOS) |
| `collection_download_button.dart` | Incoming download control — iOS only (`CollectionDownloadButton.wrap`) |
| `collection_media_controller.dart` | `openGallery` → `CollectionMediaGridPage`; passed into Fullscreen from cards only |
| `collection_media_grid_page.dart` | Full-page collection gallery (`MediaGridSection`; no avatars; tapback overlays) |

## Layout Selection

`MessagePartContent` → `resolveMediaCollectionLayout(count)` in
`helpers/ui/message_widget_helpers.dart`.

Prefs `mediaCollectionLayoutSmall` (2–3) / `mediaCollectionLayoutLarge` (4+) override
when not `skinDefault` (Media Settings → Multi-Attachment Layout):

| Skin (Default) | Count | Layout |
|----------------|-------|--------|
| iOS | 2–3 | collage |
| iOS | 4+ | stack |
| Material / Samsung | 2+ | grid |

## Ownership

- Parents size each card frame; `AttachmentHolder(fill: true)` fills it (popup skips fill).
- Radii: `CollectionAttachmentCard.mediaCardRadius` — iOS 20 / Material `M3EShapes.lg` / Samsung 25.
- **Collage / stack:** card owns skin radius + iOS-only soft shadow; collage tilt (~0.75°) is iOS-only. Reactions sit outside the clip.
- **Grid:** no card shadow; outer `ClipRRect` owns the silhouette (same radius table); cells stay square. Reaction overlay sits above cells (author-edge, `tightOverhang`). Material/Samsung tighten author-edge corners when subject/body is adjacent; iOS stays full-radius.
- **Title:** iOS stack/grid only (`CollectionTitle` → `openGallery`). Material/Samsung stay layout-only even when prefs force stack/grid.
- **`+N` (grid, count > 7):** tap → gallery; long-press → expand remaining items in place. Segment packing lives in the `CollectionGroupGrid` class doc.

## Gallery / Fullscreen

- Cards pass `collectionController` into Fullscreen viewers (paging from `controller.media`).
- Overview gallery cells omit the controller so the fullscreen grid button cannot nest.

## Related

- Parent dispatcher: `../CLAUDE.md` (attachment/) and `../../misc/CLAUDE.md` (`MessagePartContent`)
- Layout helper: `lib/helpers/ui/message_widget_helpers.dart` → `resolveMediaCollectionLayout`
- Fullscreen: `lib/app/layouts/fullscreen_media/CLAUDE.md`
