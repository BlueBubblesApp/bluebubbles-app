# services/ui/ — UI State Services

All are GetX singletons. Shorthand getters live in `lib/services/services.dart`.

## Chat → `chat/CLAUDE.md`
- `chat/chats_service.dart` (`ChatsSvc`) — sorted chat list, unread count, `ChatState` map, active chat tracking; loads in batches of 100
- `chat/conversation_view_controller.dart` — state for the currently open conversation (text, attachments, reply, scroll position)

## Messages → `message/CLAUDE.md`
- `message/messages_service.dart` (`MessagesSvc`) — per-chat service tagged by GUID; owns `MessageState` map for granular widget reactivity. Per-message controller state now lives directly on `MessageState` (`lib/app/state/message_state.dart`) — the old `MessageWidgetController` was merged into it.

## Contacts
- `contact_service_v2.dart` (`ContactsSvcV2`) — desktop sync (requires server v42+)

## Handles & Typing
- `handle_service.dart` — owns the `HandleState` map, mirrors `handle_state.dart` reactive fields
- `typing_indicator_service.dart` — typing indicator state per chat

## Other
- `theme/themes_service.dart` (`ThemeSvc`) — theme switching, custom theme management, preset themes
- `navigator/navigator_service.dart` (`NavigationSvc`) — GetX-based app routing; always use this over `Navigator.of(context)` directly
- `attachments_service.dart` — tracks file attachments in the composer + send progress state
- `unifiedpush.dart` — push notification provider abstraction (UnifiedPush protocol)

## Key Separation Rule
`ChatState` / `MessageState` (in `lib/app/state/`) are what widgets **read**.
`ChatsService` / `MessagesService` call `updateXxxInternal()` on state — **widgets never write state directly**.
