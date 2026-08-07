# attachment/collections/ — Media Collections

iOS-only fan stack for multi-attachment media collections (`MessagePart.isMediaCollection`). Material/Samsung still render each attachment via `AttachmentHolder` (no collection widgets yet).

Routed from `MessagePartContent` when `iOS && messagePart.isMediaCollection`.

## Files

| File | Purpose |
|------|---------|
| `collection_group_stack.dart` | Fan stack — 3:4 cards, drag/swipe between attachments, desktop title dialog |
| `collection_attachment_card.dart` | Single card slot + `CollectionAttachmentReactions` overlay |
| `collection_title.dart` | Label row above the stack (icon + “X Photos/Videos/Items”) |
| `collection_download_button.dart` | Circular download control for incoming iOS collections (`CollectionDownloadButton.wrap`) |

