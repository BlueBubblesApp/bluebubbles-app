# attachment/collections/ — Media Collections

iOS multi-attachment media collections (`MessagePart.isMediaCollection`). Material/Samsung stay collection-gated off in `MessagePartContent` (still one `AttachmentHolder` each); `resolveMediaCollectionLayout` already returns `grid` for non-iOS for when that lands.

Routed from `MessagePartContent` when `iOS && messagePart.isMediaCollection`, via `resolveMediaCollectionLayout(attachmentCount)` (`helpers/ui/message_widget_helpers.dart` + `MediaCollectionLayout` in `helpers/types/constants.dart`).

## Routing (skinDefault)

| Skin | Count | Layout |
|------|-------|--------|
| iOS | 2–3 | collage |
| iOS | 4+ | stack |
| Material / Samsung | any | grid (not wired yet) |


## Layout ownership

- Parents (`CollectionGroupCollage` / `CollectionGroupStack`) own frame size and motion (`SizedBox`, tilt, fan transforms).
- `AttachmentHolder(fill: true)` cover-expands into the parent frame and suppresses bubble chrome (padding, selection tint, holder shadow/radius). Popup disables fill expand.
- `CollectionAttachmentCard` owns card shadow + uniform `ClipRRect` around media, popup, and reactions (reactions sit outside the clip).
- Grid passes `fill: true` with no card shadow; outer `ClipRRect` owns the silhouette (cells stay square).

## Files

| File | Purpose |
|------|---------|
| `collection_group_collage.dart` | Vertical overlapping collage — parent-sized 4:3 / 3:4 cards, iOS tilt, collage-local swipe-to-reply |
| `collection_group_stack.dart` | Fan stack — 3:4 cards, drag/swipe between attachments, desktop title dialog |
| `collection_attachment_card.dart` | Shared card chrome (shadow/clip) + popup + media via `AttachmentHolder(fill: true)` + reactions; used by collage and stack |
| `collection_title.dart` | Label row above the layout (icon + “X Photos/Videos/Items”) |
| `collection_download_button.dart` | Circular download control for incoming iOS collections (`CollectionDownloadButton.wrap`) |
