# app/layouts/fullscreen_media/ — Full-Screen Media Viewer

## Files
| File | Purpose |
|------|---------|
| `conversation_fullscreen_holder.dart` | Gallery holder for a chat's attachments — pinch-zoom, `PageView` paging, reply-to-attachment, keyboard arrow navigation |
| `single_attachment_fullscreen_viewer.dart` | Single-item holder for one local/unsent attachment — no paging, reply, or gallery state |
| `fullscreen_image.dart` | Full-screen image viewer |
| `fullscreen_video.dart` | Full-screen video player |

## Usage

**`ConversationFullscreenHolder`** — use when viewing an attachment that belongs to a chat/message (in-bubble tap, gallery card), where paging through the chat's other attachments and replying to a specific attachment matter:
```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ConversationFullscreenHolder(attachment: attachment, showInteractions: true),
));
```

**`SingleAttachmentFullscreenViewer`** — use when previewing one local, not-yet-sent `PlatformFile`/`Attachment` (e.g. the composer's picked-attachment preview), where there's no chat context, gallery, or reply target:
```dart
SingleAttachmentFullscreenViewer(file: file, attachment: attachment, showInteractions: false);
```

Both dispatch on the attachment's mime type and render `FullscreenImage` or `FullscreenVideo` as the child, and both drive a "Done"/close button off the child's `onOverlayToggle` callback — `ConversationFullscreenHolder` tracks it against a paged attachment list, `SingleAttachmentFullscreenViewer` tracks it directly with no intermediate state.

## Key Behaviors
- Pinch-to-zoom (in `ConversationFullscreenHolder`) and standard image gestures — child widgets do not need to implement it themselves
- Tap to toggle the overlay/system UI (hide/show status bar, navigation, and action bars) — handled inside `FullscreenImage`/`FullscreenVideo`, independent of `showInteractions`
- `showInteractions` gates which action buttons are relevant (download/reply/share/etc.), not whether the overlay can be shown/hidden
- Video player is disposed when the route is popped
- Shares/saves to gallery are triggered from within the action bar
- With `collectionController`, grid button → `openGallery`; overview→FS omits controller (no nesting)

## Related
- Attachment models: `lib/database/io/attachment.dart`
- Attachment download state: `lib/services/ui/attachments_service.dart`
- Thumbnails in the chat: `lib/app/layouts/conversation_view/widgets/message/attachment/`
- Collection overview: `lib/app/layouts/conversation_view/widgets/message/attachment/collections/`
- Composer preview: `lib/app/layouts/conversation_view/widgets/text_field/picked_attachment.dart`
