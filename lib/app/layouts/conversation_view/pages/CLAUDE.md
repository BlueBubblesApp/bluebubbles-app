# conversation_view/pages/ — Top-Level Page Widgets

Two entry-point widgets for the conversation screen.

## Files

| File | Purpose |
|------|---------|
| `conversation_view.dart` | Outer container; sets up `ConversationViewController`, handles routing, manages keyboard/layout |
| `messages_view.dart` | Scrollable message list; owns `CustomScrollView`, loads messages in pages, triggers `MessagesService` |

## Handlers (`handlers/`)
Extracted orchestration logic used by `messages_view.dart` / `conversation_view.dart`:
- `drop_zone_manager.dart` — desktop drag-and-drop file target handling
- `message_animation_orchestrator.dart` — coordinates entrance/highlight animations for messages in the list
- `message_list_animation_config.dart` — animation timing/curve constants for the message list
- `smart_replies_manager.dart` — fetches and manages Smart Reply suggestion state

## Relationship
`ConversationView` renders `MessagesView` as its body. `MessagesView` does **not** create the controller — it receives it from the parent via `ConversationViewController`.

## Key Controllers
- `ConversationViewController` (from `lib/services/ui/chat/conversation_view_controller.dart`) — owns text field state, reply context, attachment drafts, scroll position
- `MessagesService` (tagged by chat GUID) — owns the message data and `MessageState` map

## Related
- Full widget tree overview: `../CLAUDE.md` (conversation_view)
- Message rendering: `../widgets/message/CLAUDE.md`
- Text field: `../widgets/text_field/CLAUDE.md`
