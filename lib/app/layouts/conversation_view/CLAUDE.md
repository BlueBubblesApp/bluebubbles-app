# conversation_view/ — Message Thread UI

## Structure
- `pages/conversation_view.dart` — main chat screen
- `pages/messages_view.dart` — scrollable message list
- `widgets/messages_view_components.dart` — extracted widgets shared by the message list (e.g. `TypingIndicatorRow`)
- `widgets/message/` — all message rendering → `CLAUDE.md` inside
- `widgets/header/` — chat header bar and info → `CLAUDE.md` inside
- `widgets/text_field/` — message composer
  - `buttons/` — attachment, emoji, send buttons
  - `helpers/` — input field helpers
- `widgets/media_picker/` — file/image selection UI → `CLAUDE.md` inside
- `widgets/effects/` — send effect overlay + picker → `CLAUDE.md` inside
- `dialogs/` — mention autocomplete and other dialogs → `CLAUDE.md` inside
- `mixins/` — `messages_service_mixin.dart` (message loading/callback wiring) → `CLAUDE.md` inside
- `pages/` — `conversation_view.dart` + `messages_view.dart` → `CLAUDE.md` inside

## Controller
`ConversationViewController` → `lib/services/ui/chat/conversation_view_controller.dart`
