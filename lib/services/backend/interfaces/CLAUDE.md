# services/backend/interfaces/ — Isolate Interface Layer

Interfaces are the **only** public API for triggering backend operations. They route each call to the right execution context, then hydrate the returned IDs into full model objects.

## File → Resource Mapping
| File | Resource |
|------|----------|
| `app_interface.dart` | App update check, FCM data |
| `attachment_interface.dart` | Save / find / delete attachments |
| `chat_interface.dart` | Save / delete / mark-read chats |
| `contact_v2_interface.dart` | Contact sync, handle matching (v2) |
| `handle_interface.dart` | Save / find phone number handles |
| `image_interface.dart` | PNG conversion, EXIF, GIF dimensions |
| `log_interface.dart` | Log write/export calls |
| `message_interface.dart` | Save / find / delete messages |
| `prefs_interface.dart` | Settings sync, reply state persistence |
| `send_message_interface.dart` | Outgoing message send pipeline entry point |
| `server_interface.dart` | Server version check, server details |
| `sync_interface.dart` | Incremental sync trigger |
| `test_interface.dart` | Dev/debug test calls |

## Routing Pattern (every interface method follows this)
```dart
static Future<Chat?> saveChat({required String guid, ...}) async {
  final data = {'guid': guid, ...};

  final int? id;
  if (isIsolate) {
    id = await ChatActions.saveChat(data);   // already in isolate → call directly
  } else {
    id = await GetIt.I<GlobalIsolate>().send<int?>(IsolateRequestType.saveChat, input: data);
  }

  // Hydrate: O(1) DB lookup on the main thread
  return id != null ? Database.chats.get(id) : null;
}
```

## Rules
- Always check `isIsolate` before dispatching — never call `GlobalIsolate.send()` from inside an isolate
- Hydration (ID → object) always happens after the isolate call returns, on the calling thread
- Input parameters are named and typed; they are packed into a `Map<String, dynamic>` for the isolate boundary
- Never expose `Map<String, dynamic>` in the public signature — callers pass typed arguments

## Callers
Service layer only: `ChatsService`, `MessagesService`, `ContactServiceV2`, etc.
UI code never calls interfaces directly.
