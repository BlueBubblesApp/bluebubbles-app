# widgets/text_field/ — Message Composer

## Files (top-level)
- `conversation_text_field.dart` — composer entry point / orchestration
- `conversation_text_field_local_controller.dart` — local (non-service) text field controller state
- `text_field_component.dart` — main composable text input widget
- `send_button.dart` — send / schedule button
- `text_field_icon_bar.dart` — attachment/emoji/etc. icon row; on desktop the `+` is wrapped in `DesktopAttachmentMenu` (`../media_picker/`), as is the chat creator's `+` in `text_field_component.dart`. Desktop users arrange the row here (no settings page): hold a button to drag it before another or into the slot after the last, drop on `+` to move it into the menu, drag menu items out onto the row. `buttons/text_field_button_drag.dart` (`TextFieldButtonDrag`) holds the drag's shared state and works like the pins: the row opens room where it would land (no preview there), the dragged look stays gray, hovering `+` opens the menu with the preview in place, drops fly into place (turning into a menu tile when landing in the menu), and a drop on nothing flies back
- `text_field_suffix.dart` — trailing icon(s) inside the field
- `formatting_bar.dart` — B/I/U/S toggles plus one Effects button, shown above a conversation's input while text is selected or formatting is active (never in the chat creator, which has no `ConversationViewController` and sends a new chat's first message plain). On mobile the button (and the selection menu's "Text Effects") swaps the keyboard for `TextFormattingPanel`; on desktop it opens a popover of `TextEffectGrid`
- `text_effect_picker.dart` — `TextEffectGrid` (a tile per effect, its name looping in that effect via `RunTextEffects`) and `TextFormattingPanel` (B/I/U/S over the grid, in the keyboard's place). `openTextFormattingPanel` hides the keyboard with `TextInput.hide` so the field keeps focus and its selection; `ConversationViewController.showTextFormattingPanel` closes on a tap in the field, focus loss, or back. The panel is as tall as the keyboard was, nav bar included, and pads its own content above the nav bar; the conversation view drops its bottom inset while it shows, so the field stays where it was
- `text_effect_overlay.dart` — animates text effect runs over the input (which draws them transparent), drawing each glyph at the box the field's `RenderEditable` reports so wrapping and scrolling match; motion comes from `RunTextEffects`' pose functions
- `text_field_recording_overlay.dart` — voice message recording overlay UI
- `voice_message_recorder.dart` — voice message recording logic
- `picked_attachment.dart` / `picked_attachments_holder.dart` — pending attachment chip + holder; `ComposerSuggestions` (also in the holder's file) floats the emoji/mention suggestions above the composer through an `OverlayPortal`, so they never change the composer's (animated) height
- `reply_holder.dart` — selected reply preview above the field

## Buttons (`buttons/`)
Action buttons inside and around the input field:
- Attachment picker button
- Emoji picker button
- Audio record button
- Send / schedule button

## Handlers (`handlers/`)
- `clipboard_paste_handler.dart` — image/file paste handling
- `emoji_autocomplete_handler.dart` — `:shortcode:` emoji autocomplete
- `keyboard_shortcut_handler.dart` — composer keyboard shortcuts (desktop)
- `mention_autocomplete_handler.dart` — `@mention` autocomplete
- `text_field_match_helper.dart` — shared text-matching logic for autocomplete handlers (suggestion lists reset through `RxList.setIfChanged`, in `helpers/types/extensions/`)

## Helpers (`helpers/`)
Input field utilities: mention detection, text formatting, cursor management.

## Controller
All composer state lives in `ConversationViewController` (`lib/services/ui/chat/conversation_view_controller.dart`):
- Current text content
- Pending attachments list (→ `AttachmentsService`)
- Selected reply message
- Scheduled send time
- Send progress

## Key Interactions
- Attachments added here → tracked by `AttachmentsService`
- Send → `OutgoingMsgHandler` (`OutgoingMessageHandler`)
- Reply selection rendered by `widgets/message/reply/`
- Mention autocomplete → `custom_text_editing_controllers.dart` in `lib/app/components/`
