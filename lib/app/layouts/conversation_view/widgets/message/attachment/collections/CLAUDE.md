# collections/ — Multi-Attachment Media Layouts

Renders a message part with 2+ media attachments as a collage, fan stack, or grid
(instead of individual `AttachmentHolder`s). Dispatched from `MessagePartContent`
when `MessagePart.isMediaCollection`. Consecutive media-only parts are merged first by
`MessagePart.collapseMediaCollections`, which `MessageHolder` reads through the memoized
`MessageState.displayParts`, so a collection part (and its `MediaCollectionScope`) keeps its identity across rebuilds.

## Files

| File | Purpose |
|------|---------|
| `collection_group_collage.dart` | Overlapping collage (skin-default iOS 2–3) |
| `collection_group_stack.dart` | Fan stack (skin-default iOS 4+); swipe / wheel / trackpad paging |
| `collection_group_grid.dart` | Grid (skin-default Material/Samsung 2+): renders `CollectionGridLayout` |
| `collection_grid_layout.dart` | Pure tile packing for the grid — one `Rect` per attachment, no widgets |
| `collection_attachment_card.dart` | Shared card chrome + `fill` media + per-attachment reactions; `.gridCell` for grid tiles |
| `collection_style.dart` | `CollectionStyle` — card radius, connected-corner radius, iOS card shadow, width limits |
| `collection_title.dart` | “X Photos/Videos/Items” label; `CollectionTitledLayout` places it (iOS skin only) |
| `collection_download_button.dart` | Incoming download control — iOS only (`CollectionDownloadButton.wrap`) |
| `media_collection.dart` | `MediaCollection` value (media, title, `openGallery`) + `MediaCollectionScope` |
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
- Shared sizing / radii / shadow live in `CollectionStyle` — don't redefine them per layout.
  Card radius: iOS 20 / Material `M3EShapes.lg` / Samsung 25.
- **Collage / stack:** card owns skin radius + iOS-only soft shadow; collage tilt (~0.75°) is iOS-only. Reactions sit outside the clip.
- **Grid:** cells are `CollectionAttachmentCard.gridCell` (square, no shadow, no in-card tapbacks). The outer card owns the
  silhouette clip and the iOS-only shadow; tapbacks render in a second, unclipped layer positioned from the same
  `CollectionGridLayout`. Material/Samsung tighten the author-edge corners against an adjacent subject / body
  (`CollectionStyle.connectedCornerRadius`); iOS stays full-radius.
- **Reactions:** per attachment via `CollectionAttachmentReactions` (`MessageState.tapbacksForPartId`). Stack cards and
  the gallery page use the inside tail pinned to the trailing edge; collage and Material/Samsung grid follow the normal
  bubble rule (left of from-me, right of received).
- **Title:** iOS stack/grid only, via `CollectionTitledLayout` → `MediaCollection.openGallery`. Material/Samsung stay layout-only even when prefs force stack/grid.
- **`+N` (grid, count > `CollectionGridLayout.maxCollapsedTiles`):** tap → gallery; long-press → expand remaining items in
  place, up to `CollectionGroupGrid.maxInPlaceTiles` (bigger collections open the gallery instead). Expanding keeps one
  tree: cells are keyed by index and animate to their new rects, so visible media isn't remounted.
- **Per-card parts:** cards hand `MessagePart.itemPartFor(index)` to `AttachmentHolder` / the popup — one
  single-attachment part per attachment, built with the collection, carrying its source part's flags. Don't build
  parts in `build()`.
- **Stack cards** all build the same widget tree (`_slotCard`) whether front, fanned or past, so paging never remounts
  a card's media. `MessagePopupHolder` keeps its tree shape when `enableGestures` flips for the same reason.
- **Download all:** `AttachmentsService.saveAllToDisk` — one folder prompt (desktop, or Android with "Ask where to
  save"), downloads what's missing, then one summary snackbar.
- **Swipe-to-reply:** collage cards use `SwipeToReplyRow` (`misc/swipe_to_reply_wrapper.dart`). The stack has none —
  horizontal drags page the fan. `MessageHolder` disables its per-part swipe for every collection.

## Gallery / Fullscreen

- Each layout provides `MediaCollectionScope`; `CollectionAttachmentCard` re-provides it around the child it hands to
  `MessagePopupHolder` (the popup renders that child in its own route).
- `ResolvedFileContent` / `VideoPlayer` read the scope when opening fullscreen: paging is limited to the collection and
  `ConversationFullscreenHolder` gets an `onOpenCollectionGallery` callback for its grid button.
- `CollectionMediaGridPage` is pushed as its own route, outside any scope, so fullscreen opened from it has no grid
  button (no nesting).

## Related

- Parent dispatcher: `../CLAUDE.md` (attachment/) and `../../misc/CLAUDE.md` (`MessagePartContent`)
- Layout helper: `lib/helpers/ui/message_widget_helpers.dart` → `resolveMediaCollectionLayout`
- Part-id helpers: `MessagePart.coversPartId` / `coveredPartIds`, `MessageState.isLeadingMessagePart` / `isTrailingMessagePart`
- Fullscreen: `lib/app/layouts/fullscreen_media/CLAUDE.md`
