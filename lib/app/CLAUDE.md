# lib/app/ — UI Layer

## Major Subsystems
- `layouts/conversation_view/` — message thread UI → `CLAUDE.md` inside
- `layouts/conversation_list/` — chat list/inbox → `CLAUDE.md` inside
- `layouts/settings/` — preferences → `CLAUDE.md` inside
- `layouts/setup/` — onboarding flow → `CLAUDE.md` inside
- `layouts/conversation_details/` — chat info panel → `CLAUDE.md` inside
- `layouts/chat_creator/` — new chat creation → `CLAUDE.md` inside
- `layouts/findmy/` — Find My device locator → `CLAUDE.md` inside
- `layouts/startup/` — splash screen + boot failure screen → `CLAUDE.md` inside
- `layouts/fullscreen_media/` — full-screen image/video viewer → `CLAUDE.md` inside
- `layouts/camera/camera_screen.dart` — in-app camera capture for attachments
- `layouts/chat_selector_view/` — pick an existing chat (e.g. for forwarding/sharing)
- `layouts/contact_selector_view/` — pick a contact
- `layouts/handle_selector_view/` — pick a specific handle/address for a contact
- `components/` — reusable widgets → `CLAUDE.md` inside
- `animations/` — send effects → `CLAUDE.md` inside
- `state/` — `ChatState`, `MessageState` — reactive wrappers around DB models → `CLAUDE.md` inside
- `wrappers/` — scaffold composition → `CLAUDE.md` inside

## Avatars → `components/avatars/CLAUDE.md`
`components/avatars/contact_avatar_widget.dart` (single)
`components/avatars/contact_avatar_group_widget.dart` (group)
