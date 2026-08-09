# services/backend/actions/ — Isolate Action Implementations

Actions are pure functions that run **inside** the background isolate. They perform ObjectBox reads/writes and return primitive values (IDs, maps, booleans) — never full model objects with DB relations.

## File → Resource Mapping
| File | Resource |
|------|----------|
| `app_actions.dart` | App update check, FCM data |
| `attachment_actions.dart` | Save / find / delete attachments |
| `chat_actions.dart` | Save / delete / mark-read chats, bulk sync |
| `contact_v2_actions.dart` | Contact sync, handle matching (v2) |
| `handle_actions.dart` | Save / find phone number handles |
| `image_actions.dart` | PNG conversion, EXIF, GIF dimensions |
| `log_actions.dart` | Log write/export actions |
| `message_actions.dart` | Save / find / delete messages, bulk operations |
| `prefs_actions.dart` | Settings sync, reply state persistence |
| `send_message_actions.dart` | Outgoing message send pipeline actions |
| `server_actions.dart` | Server version check, server details |
| `storage_actions.dart` | Attachment storage analysis (filesystem walk + DB join), deletion |
| `sync_actions.dart` | Incremental sync, contact upload |
| `test_actions.dart` | Dev/debug test actions |

## Rules
- Actions accept a single `Map<String, dynamic> data` parameter (serializable across isolate boundary)
- Return types must be primitive or JSON-serializable: `int?`, `bool`, `Map`, `List<int>`, etc.
- Never return ObjectBox entities or objects with lazy-loaded `ToOne`/`ToMany` relations
- All DB writes go through `Database.runInTransaction(TxMode.write, () { ... })`
- Actions are registered in `isolate_actions.dart` → `IsolateActons.actions`

## Adding a New Action
1. Add a `static Future<ReturnType> myAction(Map<String, dynamic> data)` method here
2. Add the `IsolateRequestType.myAction` enum value in `global_isolate.dart`
3. Register in `IsolateActons.actions` in `isolate_actions.dart`
4. Add the corresponding interface method in `interfaces/`

## Do NOT call from here
- `GlobalIsolate.send()` — you're already inside the isolate
- `GetIt.I<SomeService>()` for services not registered in the isolate's init sequence
