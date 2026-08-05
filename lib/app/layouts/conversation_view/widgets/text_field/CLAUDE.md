# widgets/text_field/ — Message Composer

## Files (top-level)
- `conversation_text_field.dart` — composer entry point / orchestration
- `conversation_text_field_local_controller.dart` — local (non-service) text field controller state
- `text_field_component.dart` — main composable text input widget
- `send_button.dart` — send / schedule button
- `text_field_icon_bar.dart` — attachment/emoji/etc. icon row
- `text_field_suffix.dart` — trailing icon(s) inside the field
- `text_field_emoji_picker_section.dart` — inline emoji picker section
- `text_field_recording_overlay.dart` — voice message recording overlay UI
- `voice_message_recorder.dart` — voice message recording logic
- `picked_attachment.dart` / `picked_attachments_holder.dart` — pending attachment chip + holder
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
- `text_field_match_helper.dart` — shared text-matching logic for autocomplete handlers

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
