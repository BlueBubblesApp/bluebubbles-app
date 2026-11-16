# conversation_view/widgets/media_picker/ — Attachment Picker UI

UI for selecting media files to attach before sending a message.

## Files

| File | Purpose |
|------|---------|
| `text_field_attachment_picker.dart` | Bottom-sheet picker that browses the photo library and recent files; tapping an item adds it to the composer draft |
| `attachment_picker_file.dart` | Renders a single file/photo thumbnail item inside the picker |
| `attachment_actions.dart` | `AttachmentActions` — the shared "add something" handlers (Files, Handwritten, Schedule, Location, Genmoji attach/create/delete). Both the mobile picker and the desktop `+` menu call these, and `run()` dispatches a `TextFieldButton` for the row and menu; add new actions here, not in either UI |
| `desktop_attachment_menu.dart` | `DesktopAttachmentMenu` — desktop's `+` button is a `MenuAnchor` popup (opens upward, scrolls when short) listing every supported `TextFieldButton` not already in the composer row. With `arrangeable` (the composer, not the chat creator), items hold-drag out onto the row and a row button dropped on `+` moves into the menu; see `TextFieldButtonDrag`. Desktop has no attachment sheet |
| `genmoji_dialog.dart` | Skin-aware Genmoji creator (prompt → nebula while generating → Discard / New / Attach); checks `genmoji/status` on open. Opened by `AttachmentActions.createGenmoji` |
| `genmoji_library_tile.dart` | `GenmojiLibraryTile` (cached thumbnail, in-draft ring, download spinner) and `GenmojiCreateTile` (the "New" tile), shared by both library UIs |
| `sticker_library_dialog.dart` | `StickerLibraryView`: the Mac's sticker library (Stickers + Recents, from `StickerLibrarySvc`) with `+` to upload an image from this device (lands in Recents). On desktop the composer's "Stickers" button opens it as a popover (`showStickerLibraryPopover`); dragging a sticker out closes the popover, and dropping it on a message bubble (`StickerDropTarget`, `../message/attachment/`) places it there through `OutgoingMsgHandler.queuePlacedSticker`; the emoji tapback picker's Stickers tab uses it to react with a sticker |
| `sticker_library_tile.dart` | `StickerLibraryTile` (with `draggable`, drags onto a message bubble to place it as large as it looked: at once with a mouse, after a long press on mobile, where a second finger pinches/rotates it (`StickerDrag` carries the transform) and a long press released in place offers removal instead. The desktop popover hides rather than closes while the drag is out (`ComposerPopoverScope`), because a navigator pop cancels active pointers; right-click offers `confirmRemoveSticker`, which removes it from the Mac via `DELETE /api/v2/sticker/:id`, Private API only), `StickerAddTile` and `pickAndAddSticker`, shared by the dialog and the mobile picker's sticker grid |
| `genmoji_library_popover.dart` | Desktop Genmoji library: searchable grid anchored above `+`; click attaches and closes, right-click → Delete, "New" opens the creator |
| `composer_popover.dart` | `showComposerPopover` + `ComposerPopoverCard`: the desktop popover above a composer button (click outside or Escape dismisses) that the Genmoji, sticker and emoji popovers share |
| `emoji_picker_popover.dart` | Desktop Emoji button: `EmojiPicker` in a popover; picks go into the field being typed in at its cursor and it stays open |

## Genmoji
Gated on `ServerDetails.supportsGenmoji` (v2 server). On mobile the picker's "Genmoji" action toggles the right-hand grid from photos to the Mac's library (3 rows of square tiles; the first column starts with "Photos" then "New", as grid cells; tap toggles attach, long-press deletes; pull to force-refresh). The mode is `ConversationViewController.showGenmojiLibrary`: the picker resets it on open, and the conversation view's back handler clears it before closing the picker. Ways back to photos: the "Photos" tile, tapping the selected Genmoji action (shows ✕), or Android back. On desktop it's the `+` menu's "Genmoji" item → popover. Both read `GenmojiLibrarySvc` (`lib/services/ui/genmoji_library_service.dart`), which mirrors the Mac's library and caches images on disk. A library Genmoji is attached as `genmoji-<identifier>.png`, which is how tiles know it's in the draft.

## Integration
Opened from the compose bar via the attachment (paperclip / `+`) button in `widgets/text_field/` — the sheet on mobile, `DesktopAttachmentMenu` on desktop.
Selected attachments are stored in `ConversationViewController.pickedImages`.

## Related
- Compose bar: `../text_field/CLAUDE.md`
- Conversation view controller: `lib/services/ui/chat/conversation_view_controller.dart`
- Attachment state: `lib/app/state/attachment_state.dart`
