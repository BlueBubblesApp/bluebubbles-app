# BlueBubbles App — Architecture Overview

## System Layers

```
┌─────────────────────────────────────────────────┐
│                   UI Layer                       │
│  lib/app/layouts/   lib/app/components/          │
│  lib/app/wrappers/  lib/app/animations/          │
│        ↑ reads from                              │
│  lib/app/state/  (ChatState, MessageState)       │
└───────────────────────┬─────────────────────────┘
                        │ updateXxxInternal()
┌───────────────────────▼─────────────────────────┐
│                Service Layer                     │
│  lib/services/ui/     ← UI-facing state          │
│  lib/services/backend/ ← business logic          │
│  lib/services/network/ ← HTTP + WebSocket        │
│  lib/services/backend_ui_interop/ ← events       │
└───────────────────────┬─────────────────────────┘
                        │ via Interfaces
┌───────────────────────▼─────────────────────────┐
│            Background Isolate Layer              │
│  GlobalIsolate  (Actions run here)               │
│  IncrementalSyncIsolate  (sync-only variant)     │
│        ↓ returns IDs                             │
│  Interface hydrates IDs → full objects           │
└───────────────────────┬─────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────┐
│               Database Layer                     │
│  lib/database/io/      ObjectBox entities        │
│  lib/database/html/    Web stubs                 │
│  lib/database/global/  Platform-agnostic DTOs    │
└─────────────────────────────────────────────────┘
```

---

## Background Isolate System

All heavy operations (database reads/writes, sync, bulk processing) run in a dedicated background `Dart Isolate` to keep the UI thread at 60 fps.

### GlobalIsolate

Defined in `lib/services/isolates/global_isolate.dart`. Spawned once at app startup via `startup_tasks.dart` and kept alive for the app's lifetime (auto-killed after 5 minutes of idle, restarted on next use).

The isolate runs `sharedIsolateEntryPoint()`, which:
1. Accepts a `SendPort` from the main thread
2. Calls `initServices()` to register its own service instances
3. Loops waiting for `IsolateRequest` messages
4. Routes each request to the matching `IsolateRequestType` → action function
5. Returns an `IsolateResponse` with a result or error

Communication is request/response over `SendPort`/`ReceivePort` with UUID-keyed pending request tracking. Requests time out automatically.

### IncrementalSyncIsolate

A lighter-weight variant that extends `GlobalIsolate`. It registers only the services needed for sync (no `MethodChannelService`). `idleTimeout` is `Duration.zero`, so it self-terminates immediately after its work is done. Used exclusively for incremental sync operations.

### The `isIsolate` Flag

`lib/env.dart` exposes:
```dart
bool get isIsolate =>
    isIsolateOverride ||
    (Isolate.current.debugName != null && Isolate.current.debugName != 'main');
```

Every Interface method checks this flag to **prevent an isolate from spawning sub-isolates**:
- On the **main thread** (`isIsolate == false`): dispatch to `GlobalIsolate.send()`
- Inside the **isolate** (`isIsolate == true`): call the Action directly

Without this flag, isolate code that calls an Interface would invoke `GlobalIsolate.send()` from within the isolate — spinning up another isolate unnecessarily and risking deadlocks. The flag lets the same interface method work correctly in both execution contexts without duplication.

### Interface → Action → Hydration

Actions (`lib/services/backend/actions/`) perform pure ObjectBox operations and return **primitive IDs**. Interfaces (`lib/services/backend/interfaces/`) route to the right context and then **hydrate** those IDs back into full model objects on the main thread via `Database.entityBox.get(id)` — an O(1) lookup.

Objects and ObjectBox relations cannot be safely passed across isolate boundaries. IDs are plain integers and serialize trivially.

---

## State Management

### GetIt vs GetX

Two dependency injection systems are used deliberately for different purposes:

| System | Used for |
|--------|---------|
| **GetIt** | Singleton services — registered once, accessed anywhere by type |
| **GetX** | Reactive observable variables — `Rx*` types that drive `Obx()` widget rebuilds |

Services are registered with GetIt (`GetIt.I.registerSingleton<T>()`). Shorthand getters for the most-used services are defined in `lib/services/services.dart` (e.g., `ChatsSvc`, `SettingsSvc`). GetX is never used for service location in this project.

Inside components and state classes, `Rx*` observables (`RxBool`, `RxString`, `RxList<T>`, etc.) trigger fine-grained `Obx()` widget rebuilds.

### ChatState & MessageState

`lib/app/state/chat_state.dart` and `message_state.dart` are thin reactive wrappers around the ObjectBox entities `Chat` and `Message`.

**Why they exist:** ObjectBox entities are heavy (they carry lazy-loaded relations, full field sets, and require a DB context to resolve links). Re-querying the DB on every UI event would be expensive and could block the main thread. Instead, the relevant fields that the UI cares about are mirrored as `Rx*` fields inside a state object.

**Update discipline:** Only `*Internal` methods (e.g., `updateIsPinnedInternal()`) modify a state object's observables. These are called exclusively by service-layer code after a confirmed DB write. UI widgets are never allowed to call them directly. This guarantees that the DB and the in-memory state stay in sync and that no widget can create a stale-read situation by writing state independently.

**Granularity matters:** Because each field is its own observable, `Obx()` rebuilds only the sub-tree that reads that specific field. A chat's unread badge updating does not force the chat name or avatar to re-render.

### Update Flows

**Incoming message from server:**
```
IncomingMessageHandler (internal FIFO queue, configurable concurrency)
  → ChatActions (DB write, returns IDs)
  → ChatInterface (hydrates)
  → ChatsService / MessagesService
  → ChatState.updateXxxInternal() / MessageState.updateXxxInternal()
  → Obx() widget rebuilds only affected sub-trees
```

**User action (e.g., mark as read):**
```
UI widget → ChatsService.setChatHasUnread()
  → ChatInterface.markChatReadUnread() (routes to isolate or direct)
  → ChatActions (DB write)
  → ChatState.updateHasUnreadInternal()
  → Obx() widget rebuilds badge
```

---

## UI Architecture

### Skin System

The app supports three visual skins: iOS (Cupertino), Material, and Samsung. Every screen that differs between skins uses `ThemeSwitcher` to branch to the correct implementation:
```dart
ThemeSwitcher(
  iOSSkin:      CupertinoMyWidget(parentController: controller),
  materialSkin: MaterialMyWidget(parentController: controller),
  samsungSkin:  SamsungMyWidget(parentController: controller),
)
```
All three variants share the same controller. Skin-specific logic never leaks into shared code.

### Widget Base Classes

`lib/app/wrappers/stateful_boilerplate.dart` provides three base classes:

| Base | Use when |
|------|---------|
| `CustomStateful<T>` + `CustomState<T, R, S>` | Widget shares or owns a `StatefulController` |
| `OptimizedState<T>` | Stateful widget without a controller; needs frame-aware `setState` |
| Plain `StatelessWidget` | No mutable state |

`OptimizedState.setState()` checks the Flutter scheduler phase before applying updates, preventing layout jank during animation frames.

---

## Platform Abstraction

ObjectBox does not support web. The database layer is split:

| Directory | Platform | Contents |
|-----------|----------|---------|
| `lib/database/io/` | Android, iOS, Desktop | `@Entity` annotated ObjectBox classes |
| `lib/database/html/` | Web | Stub implementations with equivalent API shapes |
| `lib/database/global/` | All | Plain Dart DTOs with no DB annotations |

Conditional imports resolve the correct module at compile time. Service and UI code imports from `lib/database/models.dart` which handles the branching transparently.

---

## Service Startup Order

`lib/helpers/backend/startup_tasks.dart` registers services in a strict order to satisfy dependencies:

1. `FilesystemService` → `SharedPreferencesService` → `SettingsService` → Logger
2. Database initialization
3. `GlobalIsolate` + `IncrementalSyncIsolate` registered with GetIt
4. `HttpService`, `MethodChannelService`, `LifecycleService` (await in parallel)
5. `ContactServiceV2`, `ChatsService`, `SocketService`, `NotificationsService`
6. `EventDispatcher`

---

## Event Bus

`lib/services/backend_ui_interop/event_dispatcher.dart` is a broadcast `StreamController<Tuple2<String, dynamic>>`. Backend services emit named events; UI widgets subscribe in `initState()` and cancel in `dispose()`. This decouples the backend from the UI without needing shared observable state for one-off cross-cutting events (e.g., "chat-updated").
