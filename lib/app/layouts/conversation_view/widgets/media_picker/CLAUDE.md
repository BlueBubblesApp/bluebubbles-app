# conversation_view/widgets/media_picker/ — Attachment Picker UI

UI for selecting media files to attach before sending a message.

## Files

| File | Purpose |
|------|---------|
| `text_field_attachment_picker.dart` | Bottom-sheet picker that browses the photo library and recent files; tapping an item adds it to the composer draft |
| `attachment_picker_file.dart` | Renders a single file/photo thumbnail item inside the picker |
| `attachment_actions.dart` | `AttachmentActions` — the shared "add something" handlers (Files, Photos & Videos, Handwritten, Schedule, Location, Genmoji attach/create/delete). Both the mobile picker and the desktop `+` menu call these; add new actions here, not in either UI |
| `desktop_attachment_menu.dart` | `DesktopAttachmentMenu` — desktop's `+` button is a `MenuAnchor` popup (opens upward, scrolls when short) listing the desktop-capable actions. Desktop has no attachment sheet |
| `genmoji_dialog.dart` | Skin-aware Genmoji creator (prompt → nebula while generating → Discard / New / Attach); checks `genmoji/status` on open. Opened by `AttachmentActions.createGenmoji` |
| `genmoji_library_tile.dart` | `GenmojiLibraryTile` (cached thumbnail, in-draft ring, download spinner) and `GenmojiCreateTile` (the "New" tile), shared by both library UIs |
| `genmoji_library_popover.dart` | Desktop Genmoji library: searchable grid anchored above `+`; click attaches and closes, right-click → Delete, "New" opens the creator |

## Genmoji
Gated on `ServerDetails.supportsGenmoji` (v2 server). On mobile the picker's "Genmoji" action toggles the right-hand grid from photos to the Mac's library (3 rows of square tiles; the first column starts with "Photos" then "New", as grid cells; tap toggles attach, long-press deletes; pull to force-refresh). The mode is `ConversationViewController.showGenmojiLibrary`: the picker resets it on open, and the conversation view's back handler clears it before closing the picker. Ways back to photos: the "Photos" tile, tapping the selected Genmoji action (shows ✕), or Android back. On desktop it's the `+` menu's "Genmoji" item → popover. Both read `GenmojiLibrarySvc` (`lib/services/ui/genmoji_library_service.dart`), which mirrors the Mac's library and caches images on disk. A library Genmoji is attached as `genmoji-<identifier>.png`, which is how tiles know it's in the draft.

## Integration
Opened from the compose bar via the attachment (paperclip / `+`) button in `widgets/text_field/` — the sheet on mobile, `DesktopAttachmentMenu` on desktop.
Selected attachments are stored in `ConversationViewController.pickedImages`.

## Related
- Compose bar: `../text_field/CLAUDE.md`
- Conversation view controller: `lib/services/ui/chat/conversation_view_controller.dart`
- Attachment state: `lib/app/state/attachment_state.dart`
