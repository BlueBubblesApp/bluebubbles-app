# chat_creator/widgets/ — New Chat Creator Widgets

Sub-widgets for the new conversation creation UI.

## Files

| File | Purpose |
|------|---------|
| `recipient_chips_row.dart` | Horizontal scrollable row of selected contact chips (To: field) |
| `selected_contact_chip.dart` | Single removable chip representing a chosen recipient |
| `search_results_list.dart` | Scrollable list of contact/handle search results |
| `search_contact_tile.dart` | Single search result row (avatar, name, address) |
| `chat_list_section.dart` | Section showing existing chats matching the search query |
| `chat_creator_tile.dart` | Single existing-chat row item in chat_list_section |
| `message_type_toggle.dart` | iMessage / SMS toggle switch |
| `service_type_picker.dart` | Picker for selecting message service type (iMessage, SMS, RCS) |

## Related
- Parent view: `../CLAUDE.md` (chat_creator)
- Contact search: `lib/services/ul/contact_service_v2.dart`
- Handle lookup: `lib/services/backend/interfaces/handle_interface.dart`
