# attachment/collections/ — Media Collections

iOS-only fan stack for multi-attachment media collections (`MessagePart.isMediaCollection`). Material/Samsung still render each attachment via `AttachmentHolder` (no collection widgets yet).

Routed from `MessagePartContent` when `iOS && messagePart.isMediaCollection`.

## Layout ownership

- `AttachmentHolder(fill: true)` cover-expands into the parent frame and suppresses bubble chrome (padding, selection tint, holder shadow/radius). Popup disables fill expand.
- `CollectionAttachmentCard` owns card shadow + uniform `ClipRRect` around media; reactions sit outside the clip.
- Future collage can reuse the same card chrome; grid should pass `fill: true` and supply its own cell clip (no card shadow).

## Files

| File | Purpose |
|------|---------|
| `collection_group_stack.dart` | Fan stack — 3:4 cards, drag/swipe between attachments, desktop title dialog |
| `collection_attachment_card.dart` | Card chrome (shadow/clip) + popup + media via `AttachmentHolder(fill: true)` + reactions |
| `collection_title.dart` | Label row above the stack (icon + “X Photos/Videos/Items”) |
| `collection_download_button.dart` | Circular download control for incoming iOS collections (`CollectionDownloadButton.wrap`) |

