# API Rules — Backend & Network

## HTTP Calls

`HttpService` (`lib/services/network/http_service.dart`) is a thin entrypoint — it owns `dio`, core
request boilerplate, and a named sub-service per API domain (`lib/services/network/api/*.dart`).
**Never add request methods directly to `HttpService`.** Add them to the relevant domain file and
call through `HttpSvc.<domain>.<method>()`.

| Property | Class | File |
|---|---|---|
| `server` | `ServerApi` | `api/server_api.dart` |
| `fcm` | `FcmApi` | `api/fcm_api.dart` |
| `attachment` | `AttachmentApi` | `api/attachment_api.dart` |
| `chat` | `ChatApi` | `api/chat_api.dart` |
| `message` | `MessageApi` | `api/message_api.dart` |
| `handle` | `HandleApi` | `api/handle_api.dart` |
| `contact` | `ContactApi` | `api/contact_api.dart` |
| `backup` | `BackupApi` | `api/backup_api.dart` |
| `faceTime` | `FaceTimeApi` | `api/facetime_api.dart` |
| `icloud` | `iCloudApi` | `api/icloud_api.dart` |
| `firebase` | `FirebaseApi` | `api/firebase_api.dart` |

Full method-level reference: `lib/services/network/CLAUDE.md` and `lib/services/network/api/CLAUDE.md`.

Each sub-service implements against `BaseApi` (`api/base_api.dart`), an abstract interface
(`dio`, `origin`, `apiRoot`, `headers`, `buildQueryParams()`, `runApiGuarded()`,
`returnSuccessOrError()`) implemented by `HttpService`. Sub-services take a `BaseApi _svc` in their
constructor rather than importing `HttpService` directly — this avoids a circular import.

**Always** wrap calls in `runApiGuarded()` and finish with `returnSuccessOrError()`:
```dart
class ChatApi {
  final BaseApi _svc;
  ChatApi(this._svc);

  Future<Response> markRead(String guid, {CancelToken? cancelToken}) async {
    return _svc.runApiGuarded(() async {
      final response = await _svc.dio.post(
        "${_svc.apiRoot}/chat/$guid/read",
        queryParameters: _svc.buildQueryParams(), // adds auth GUID automatically
        cancelToken: cancelToken,
      );
      return _svc.returnSuccessOrError(response);
    });
  }
}
```

- `_svc.buildQueryParams()` must be called for every request — it injects the server auth key.
- Return `Future<Response>` for raw endpoints; typed futures when you parse the response.
- `runApiGuarded()` handles retries on 502 and propagates all other errors via `Future.error(e, s)`.
- Accept a `CancelToken? cancelToken` param on requests that may need to be cancelled.
- Timeouts are configured globally from settings (`apiTimeout`) — don't set per-request timeouts.

**Adding a new endpoint:**
1. Find the right domain file in `api/` and add the method there.
2. For a brand-new domain, create `<domain>_api.dart` implementing against `BaseApi`, then wire it
   up as a named property on `HttpService` (constructed in `HttpService.init()`).
3. Never add request methods directly to `HttpService`.

## Interface → Action Pattern

For any new domain operation, follow the three-layer pattern:

```
Interface (lib/services/backend/interfaces/)
  ↓  builds Map<String, dynamic>, routes to isolate or direct call
Action  (lib/services/backend/actions/)
  ↓  extracts typed params, runs DB transaction, returns IDs
Interface hydrates full objects from DB using returned IDs
```

**Interface method:**
```dart
static Future<MyModel> doThing({required String guid, required int count}) async {
  final data = {'guid': guid, 'count': count};
  final id = isIsolate
      ? await MyActions.doThing(data)
      : await GetIt.I<GlobalIsolate>().send<int>(IsolateRequestType.doThing, input: data);
  return Database.myBox.get(id)!;
}
```

**Action method:**
```dart
static Future<int> doThing(Map<String, dynamic> data) async {
  final guid  = data['guid']  as String;
  final count = data['count'] as int;
  return Database.runInTransaction(TxMode.write, () {
    // ... DB work
    return newId;
  });
}
```

Rules:
- Actions always receive `Map<String, dynamic>` and extract with `as Type`.
- Provide `?? default` for optional values: `data['offset'] as int? ?? 0`.
- Actions return primitive IDs (or lists of IDs) — never full objects across isolate boundaries.
- Interfaces hydrate full objects after receiving IDs via `Database.myBox.get(id)`.
- New operation types must be added to `IsolateRequestType` enum and routed in the isolate handler.

## Socket / Real-Time Events

- Socket connection managed in `lib/services/network/socket_service.dart` — don't create additional socket instances.
- State tracked as `Rx<SocketState>` — listen to `SocketSvc.state` for connectivity changes.
- Socket reconnect logic lives in `socket_service.dart`; don't implement retry loops elsewhere.

## Backend → UI Events

Use `EventDispatcherSvc` (see `services.md`) to signal UI after backend operations complete. Prefer this over calling UI methods directly from action/service code.

## Error Handling & Logging

- Catch specific exceptions (`UniqueViolationException`, `DioException`, etc.), not bare `Exception`.
- Log with `Logger.debug/info/warn/error()` — include a `tag:` for filtering:
  ```dart
  Logger.warn('Skipping duplicate', tag: 'ChatActions');
  ```
- Expected errors (e.g., duplicate inserts) should log a warning and continue, not rethrow.
- Propagate unexpected errors: `return Future.error(e, s)` with stack trace.

## Async Conventions

- Always `await` async calls — never fire-and-forget unless intentional background work.
- For intentional fire-and-forget, use `unawaited()` from `dart:async` to make intent explicit.
- Use `Completer<void>` to coordinate between HTTP response and socket event (send progress tracking pattern).
- Run DB queries off the main thread: `await runAsync(() => query.find())`.
