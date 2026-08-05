# lib/services/ — Business Logic & State

## Subsystems
- `backend/` — server interaction, sync, queues, action dispatch → `CLAUDE.md` inside
- `network/` — HTTP, WebSocket, downloads, Firebase → `CLAUDE.md` inside
- `ui/` — UI-facing state services → `CLAUDE.md` inside
- `backend_ui_interop/` — event dispatch between backend and UI → `CLAUDE.md` inside
- `isolates/` — cross-isolate communication → `CLAUDE.md` inside

## UI Services (`ui/`)
| File | Manages |
|------|---------|
| `ui/chat/chats_service.dart` | Chat list state |
| `ui/chat/conversation_view_controller.dart` | Active chat controller |
| `ui/message/messages_service.dart` | Message state/cache |
| `ui/handle_service.dart` | Handle state (`HandleState` map) |
| `ui/typing_indicator_service.dart` | Typing indicator state |
| `ui/contact_service_v2.dart` | Contacts (v2) |
| `ui/theme/themes_service.dart` | Theme management |
| `ui/navigator/navigator_service.dart` | GetX navigation/routing |
| `ui/attachments_service.dart` | Attachment handling |
| `ui/unifiedpush.dart` | Push notification provider abstraction (UnifiedPush protocol) |

## Backend-UI Event Bridge
`backend_ui_interop/event_dispatcher.dart` — fire/listen for UI events from backend
`backend_ui_interop/intents.dart` — intent definitions

## Accessing Services
All services are GetIt singletons: `GetIt.I<ServiceName>()` (shorthand getters in `services.dart`)
All exported from `services.dart` barrel.
