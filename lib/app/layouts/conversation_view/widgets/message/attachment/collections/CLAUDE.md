# attachment/collections/ — Media Collections

`MessagePart.isMediaCollection` → `MessagePartContent` → `resolveMediaCollectionLayout`
(`helpers/ui/message_widget_helpers.dart`).

| Skin | Count | Layout |
|------|-------|--------|
| iOS | 2–3 | collage |
| iOS | 4+ | stack |
| Material / Samsung | 2+ | grid |

## Ownership

- Parents size the frame; `AttachmentHolder(fill: true)` fills it (popup skips fill).
- **Collage / stack:** card owns shadow + rounded clip; reactions outside the clip.
- **Grid:** no card shadow; outer `ClipRRect` owns silhouette; cells stay square. Reaction overlay above cells (author-edge, `tightOverhang`). `+N` on 6+ → fullscreen index 4 (interim). Author-edge corners tighten when subject/body is adjacent.

## Files

| File | Purpose |
|------|---------|
| `collection_group_collage.dart` | Overlapping collage (iOS 2–3) |
| `collection_group_stack.dart` | Fan stack (iOS 4+) |
| `collection_group_grid.dart` | Material/Samsung grid |
| `collection_attachment_card.dart` | Shared card chrome + `fill` media + reactions |
| `collection_title.dart` | “X Photos/Videos/Items” label |
| `collection_download_button.dart` | Incoming download control (`CollectionDownloadButton.wrap`) |
