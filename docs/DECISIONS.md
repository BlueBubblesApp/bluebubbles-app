# Architectural Decisions — BlueBubbles App

Each entry documents a significant design choice: what was decided, why, and what the consequences are. See `docs/ARCHITECTURE.md` for how these decisions fit together.

---

## ADR-001: Heavy Processing Runs in a Persistent Background Isolate

**Decision:** All database writes and reads that aren't trivially fast run inside `GlobalIsolate`, a dedicated Dart isolate that is spawned once at app startup and kept alive.

**Context:** ObjectBox operations — especially bulk inserts during sync, message hydration, and contact lookups — can take tens to hundreds of milliseconds. Running them on the main thread stalls the Flutter rendering pipeline and causes dropped frames.

**Rationale:**
- A persistent isolate avoids the cold-start cost of spawning a new isolate per task (isolate spawn overhead is non-trivial).
- The isolate registers its own copies of the services it needs (`ContactServiceV2`, `ChatsService`, `HttpService`) so it can operate independently without calling back to the main thread for dependencies.
- The 5-minute idle timeout auto-kills the isolate when not in use, recovering memory on mobile.

**Consequences:**
- All database-heavy paths must go through the Interface layer, not call Actions directly from UI code.
- Services registered inside the isolate are separate instances from those on the main thread — do not assume shared mutable state between the two.
- A second lighter isolate (`IncrementalSyncIsolate`) exists for sync-only work; it terminates immediately after completing (`idleTimeout: Duration.zero`) to avoid holding resources between syncs.

**Key files:** `lib/services/isolates/global_isolate.dart`, `lib/helpers/backend/startup_tasks.dart`

---

## ADR-002: Actions Return IDs; Interfaces Hydrate

**Decision:** Action methods (inside the isolate) return only primitive IDs. Interface methods (on the main thread) convert those IDs back into full model objects via ObjectBox's O(1) `get(id)` lookup.

**Context:** Dart isolates communicate via message passing. Complex objects with circular references, ObjectBox-managed lazy relations, or non-serializable fields cannot be sent across isolate boundaries.

**Rationale:**
- Integers are trivially serializable across isolate ports.
- ObjectBox entity `get(id)` is an O(1) indexed lookup — hydrating one or many objects after the fact is cheap.
- This keeps Action logic pure (just DB operations, returns a plain ID) and Interface logic responsible for producing the final typed result.
- Avoids duplicating serialization/deserialization logic for every model.

**Pattern:**
```dart
// Action (inside isolate)
static Future<int> saveChat(Map<String, dynamic> data) {
  return Database.runInTransaction(TxMode.write, () {
    Database.chats.put(chat);
    return chat.id!; // return only the ID
  });
}

// Interface (main thread)
final id = await GlobalIsolate.send<int>(IsolateRequestType.saveChat, input: data);
final chat = Database.chats.get(id)!; // hydrate
return chat;
```

**Consequences:**
- New action types must return IDs (or `List<int>` for bulk), never full model objects.
- For operations returning multiple pieces of data, use `Map<String, dynamic>` with ID keys (e.g., `{'messageId': 5, 'isNewer': true}`).
- The interface method is always responsible for null-safety after hydration.

**Key files:** `lib/services/backend/actions/`, `lib/services/backend/interfaces/`

---

## ADR-003: Same Code Runs on Main Thread and Inside Isolate via `isIsolate` Flag

**Decision:** Every Interface method checks the `isIsolate` boolean at runtime. If the caller is already inside an isolate, the Interface calls the Action directly. If the caller is on the main thread, it dispatches to `GlobalIsolate`.

**Context:** The purpose of this flag is to prevent an isolate from spawning sub-isolates. Without it, code running inside `GlobalIsolate` that calls an Interface would cause `GlobalIsolate.send()` to be invoked again — spinning up another isolate from within an isolate. This is both wasteful and a potential source of deadlocks.

**Rationale:**
- Any code running inside an isolate can detect its context via `isIsolate` (`Isolate.current.debugName != 'main'`) and short-circuit to a direct Action call.
- The same Interface method is correct in both execution contexts without any code duplication: main thread → route through `GlobalIsolate`; already in an isolate → execute the action directly.
- The flag also eliminates an entire class of dual-maintenance bugs where a "main thread version" and an "isolate version" of the same logic diverge over time.

**Consequences:**
- `isIsolate` must be checked before every `GlobalIsolate.send()` call — never skip it.
- The `isIsolateOverride` flag in `env.dart` allows forcing direct execution in tests without actually spawning an isolate.
- Adding a new interface method requires the routing check, the isolate request type, and the corresponding action implementation.

**Key file:** `lib/env.dart`, every `*_interface.dart` file

---

## ADR-004: GetIt for Services, GetX Only for Observable Variables

**Decision:** `GetIt` is the dependency injection container for all singleton services. `GetX` observables (`Rx*`) are used only for reactive fields inside state classes and service properties that drive `Obx()` widget rebuilds.

**Context:** Both packages were available. Using GetX's `Get.put()`/`Get.find()` for everything is a common Flutter pattern, but it couples service lifetimes to navigation and makes non-UI services harder to manage.

**Rationale:**
- GetIt is navigation-agnostic. Services survive route changes without needing `permanent: true` workarounds.
- GetIt's `registerSingletonAsync` cleanly handles services that need async initialization (database, HTTP client, method channels) with proper dependency ordering.
- GetX's `Rx*` types and `Obx()` are excellent for granular reactive UI updates — this is their strength and that's all they do here.
- Clear separation: if you see `GetIt.I<T>()`, it's a service access. If you see `.obs` or `Obx()`, it's reactive UI state.

**Consequences:**
- Never use `Get.put()` or `Get.find()` for backend/network services.
- Controllers scoped to individual widgets use `Get.put(tag: id)` / `Get.find(tag: id)` — this is acceptable because they are UI-layer objects with a navigational scope.
- Shorthand getters for the most common services live in `lib/services/services.dart` (e.g., `ChatsSvc`, `SettingsSvc`).

**Key file:** `lib/services/services.dart`, `lib/helpers/backend/startup_tasks.dart`

---

## ADR-005: ChatState, MessageState, HandleState, and AttachmentState Decouple DB Entities from UI Reactivity

**Decision:** `ChatState`, `MessageState`, `HandleState`, and `AttachmentState` are thin reactive wrapper classes that mirror the fields of `Chat`, `Message`, `Handle`, and `Attachment` as individually observable `Rx*` variables. The UI reads from state objects, never directly from DB entities.

**Context:** These are ObjectBox entities. They carry lazy-loaded relations and cannot be observed for field-level changes without re-querying. Passing entities directly to `Obx()` widgets would cause the entire widget to rebuild on any field change.

**Rationale:**
- `Obx()` rebuilds only the sub-tree that reads a specific `Rx*` field. If only `isPinned` changes, only the widget reading `chatState.isPinned` rebuilds — not the avatar, title, or subtitle.
- The DB entity lives in the isolate context; the reactive wrapper lives on the main thread. This is a clean boundary.
- Computed convenience fields (`hasError`, `isSending`, `isSent`) can be derived and kept in sync inside the state class without polluting the DB entity.

**Ownership varies by state class:**
- `ChatState` / `MessageState` are the primary per-entity wrappers, generally held by the UI-facing services (`ChatsService`, `MessagesService`).
- `HandleState` is owned by `HandleService` and kept in a per-handle registry keyed by `Handle.id`; fetch it via `HandleService.getOrCreateHandleState()`, never construct it directly. It also owns all redacted-mode logic (fake names/addresses/avatars) — the underlying `Handle` DB object always returns raw, non-redacted data.
- `AttachmentState` is owned by its parent `MessageState` and stored in `MessageState.attachmentStates`, keyed by attachment GUID, accessed via `MessageState.getAttachmentState()`. It additionally tracks upload/download lifecycle via an `AttachmentTransferState` enum (`idle` → `uploading`/`queued` → `downloading` → `processing` → `complete`/`error`).

**Consequences:**
- Every field that a widget renders must exist as an `Rx*` in the corresponding state class.
- Adding a new displayable property means adding it to both the entity (`database/io/`) and the state class (`app/state/`).
- `*Internal` methods are the only write path to state fields — UI widgets must never assign to `chatState.someField.value` (or the `handleState`/`attachmentState` equivalent) directly.
- Services are responsible for calling `updateXxxInternal()` after confirmed DB writes: `HandleState` mutations must go through `HandleService`; `AttachmentState` mutations go through `MessagesService`, `OutgoingMessageHandler`, or `IncomingMessageHandler`.

**Key files:** `lib/app/state/chat_state.dart`, `lib/app/state/message_state.dart`, `lib/app/state/handle_state.dart`, `lib/app/state/attachment_state.dart`

---

## ADR-006: Update Only the Smallest Possible Widget Sub-Tree

**Decision:** Wrap only the widget that actually reads a reactive value in `Obx()`. Nest multiple `Obx()` instances to isolate different reactive scopes within a single build tree.

**Context:** A naïve implementation wraps an entire screen in a single `Obx()`. Every time any observable in that screen changes, the full widget tree rebuilds. At 60 fps with live message streams, this is unacceptable.

**Rationale:**
- Each `Obx()` tracks only the observables read during its builder function's last execution.
- Splitting large widget trees into small `Obx()` scopes means a timestamp update doesn't rebuild the avatar or message text.
- This also means `GetBuilder` (manual `update()` call) is almost never needed — fine-grained `Rx*` with `Obx()` is sufficient.

**Pattern:**
```dart
// ✅ Correct — each Obx scopes to its own observables
Obx(() => Text(chatState.title.value)),
Obx(() => Badge(count: chatState.unreadCount.value)),

// ❌ Wrong — one Obx causes both to rebuild on any change
Obx(() => Column(children: [
  Text(chatState.title.value),
  Badge(count: chatState.unreadCount.value),
]))
```

**Consequences:**
- Complex widgets end up with multiple nested `Obx()` calls, which is intentional.
- Avoid reading multiple unrelated observables inside one `Obx()` unless they always change together.

---

## ADR-007: `*Internal` Methods Are the Sole Write Path to State

**Decision:** `ChatState`, `MessageState`, `HandleState`, and `AttachmentState` expose only `update*Internal()` methods for mutation. No public setters. Services call these after confirming a DB write; widgets never do.

**Context:** If both services and widgets can write state, it's impossible to guarantee that the DB and in-memory state agree. Race conditions and stale reads become inevitable.

**Rationale:**
- Enforces a unidirectional data flow: DB → service → state → UI.
- Any widget that appears to "need" to set state directly is a signal that a service method is missing.
- Equality checks inside `updateXxxInternal()` (`if (field.value != value) field.value = value`) prevent spurious reactive updates.

**Consequences:**
- When adding a new observable field, always add a corresponding `updateXxxInternal()` method.
- The method must include the equality check before assigning.
- If a derived field (like `hasError`) depends on the changed field, update it in the same method call.

---

## ADR-008: Platform DB Abstraction via `io/` and `html/` Directories

**Decision:** ObjectBox entity classes are duplicated into `lib/database/io/` (native/desktop) and `lib/database/html/` (web stub). Conditional imports in `lib/database/models.dart` select the right one at compile time.

**Context:** ObjectBox does not support web. The web platform needs some form of the same API surface so service and UI code can compile without `#if` scattered everywhere.

**Rationale:**
- Service and UI code imports from a single barrel file and is unaware of the platform split.
- Web stubs return empty lists and no-ops, which is acceptable since BlueBubbles web is a limited-feature target.
- The `global/` directory holds genuine shared models (DTOs, server payloads, settings) that don't touch ObjectBox at all and can safely be used on any platform.

**Consequences:**
- Adding a new entity requires creating the file in both `io/` and `html/`.
- All service-layer code must guard DB calls with `if (kIsWeb) return;` or equivalent.
- Never import directly from `io/` or `html/` — always go through `database/models.dart`.

**Key files:** `lib/database/models.dart`, `lib/database/io/`, `lib/database/html/`, `lib/database/global/`

---

## ADR-009: Three-Skin UI System (iOS / Material / Samsung)

**Decision:** Features that differ visually between platforms are implemented as three separate widget variants. `ThemeSwitcher` selects the correct one at runtime based on the user's skin setting.

**Context:** The app runs on Android and iOS (and desktop) and users may prefer a native-looking UI for their platform, or switch to a different aesthetic. Mixing skin logic inside shared widgets becomes unmaintainable.

**Rationale:**
- Each skin variant is a self-contained widget; changes to one skin don't risk breaking another.
- All variants receive the same controller, so business logic is never triplicated.
- `ThemeSwitcher` is the single switching point — no `if (skin == Skins.iOS)` in shared code.

**Consequences:**
- New skin-dependent UI requires creating three variants.
- Shared behavior belongs in the controller or a shared widget, not inside any skin variant.
- The skin is a user preference, not a platform detection — a user on Android can choose the iOS skin.

---

## ADR-010: (Superseded) Frame-Aware `setState` via `OptimizedState`

**Status:** Superseded — `OptimizedState` was removed from `lib/app/wrappers/stateful_boilerplate.dart` in April 2024 ("Remove unused boilerplate code") because it was dead code by that point. Nothing replaced its scheduler-phase deferral; `CustomState.updateWidget()` calls `setState()` directly with no frame-aware gating. Kept here for history — do not reference `OptimizedState` in new code or docs.

**Original decision:** `OptimizedState` overrode `setState` to defer updates until the current animation frame completed, using a `SchedulerBinding.instance.schedulerPhase` check plus an `endOfFrame` Future, to avoid layout jank when real-time updates (e.g., new messages) arrived mid-scroll-animation.

**Current state:** Widgets with controllers use `CustomStateful` + `CustomState` (see "Widget Base Classes" in `docs/ARCHITECTURE.md`); widgets without one use plain `StatelessWidget`. Neither performs frame-aware deferral. If jank from real-time updates during animation resurfaces as a problem, that mitigation needs to be reintroduced deliberately rather than assumed present.

---

## ADR-011: Prefer `Obx()` Over `setState`; Use `setState` Only as a Last Resort

**Decision:** `setState` must not be used to drive reactive UI updates. All reactive state that drives widget rebuilds belongs in `Rx*` observables wrapped by `Obx()`. `setState` is acceptable only for cases where GetX observables are structurally impractical (e.g., animation controllers, `FocusNode` listeners, or one-time layout measurements that have no persistent state).

**Context:** `setState` rebuilds the entire `State` subtree rooted at the widget that calls it. In a deeply nested widget tree with real-time message streams, this is equivalent to throwing away and re-rendering a large chunk of the screen on every incoming event. The more widgets below the `setState` call, the worse the performance impact.

**Rationale:**
- `Obx()` rebuilds only the widget(s) that read the changed `Rx*` observable — this is O(observers) not O(subtree depth).
- An `Rx*` field on a controller or state class can be observed from multiple independent `Obx()` scopes simultaneously, without duplicating state or coupling widgets together.
- `setState` forces synchronous layout recalculation for the entire subtree. `Obx()` schedules only the minimal rebuild needed.
- Keeping reactive state in `Rx*` fields also makes it easier to share state between sibling or ancestor widgets without prop-drilling.

**When `setState` is acceptable:**
- Driving a `TickerProvider` / `AnimationController` where the animation itself is the state
- Responding to `FocusNode` or `ScrollController` listeners where storing the value in an `Rx*` field would require significant wiring for a trivial one-off effect
- One-time post-frame measurements (`WidgetsBinding.instance.addPostFrameCallback`) that only affect local layout

**Consequences:**
- New widgets that need dynamic state must expose that state as `Rx*` fields on a controller or state class, then wrap the reading widget in `Obx()`.
- Auditing for `setState` calls in code review is a valid signal that a widget's state design should be reconsidered.
- The rare legitimate `setState` should be accompanied by a comment explaining why `Obx()` was not suitable.

---

## ADR-012: Web Platform Is Deprecated; Target Android and Desktop Only

**Decision:** The app officially targets Android, macOS, Windows, and Linux. iOS support exists but is secondary (the server-side component does not run on iOS). Web support exists in the codebase but is actively being deprecated and must not be a design constraint for new features.

**Context:** The web platform required significant compromises: ObjectBox is unavailable (replaced by stub implementations in `database/html/`), many native APIs are inaccessible, and the real-time WebSocket + notification stack behaves differently in a browser context. Maintaining full parity is not worth the ongoing cost.

**Rationale:**
- All meaningful BlueBubbles use cases require a persistent background connection and local database — neither works well in a web browser.
- The `html/` stub layer adds maintenance overhead every time a new database entity is added.
- Desktop (macOS, Windows, Linux) covers the non-mobile use case that web was intended to serve, with full feature parity.

**Consequences:**
- New features do not need `html/` stub implementations. Do not block a feature on web compatibility.
- New `@Entity` classes in `database/io/` require a matching stub in `database/html/` only if it is needed to keep the project compiling on web — otherwise leave it absent and document the web build as broken for that feature.
- `if (kIsWeb)` guards in existing code should be left in place but treated as legacy dead branches — do not add new ones.
- Do not optimize, test, or debug for the web target. If a bug only reproduces on web, it is low priority.
- iOS is not deprecated but is lower priority than Android and Desktop; the server component (BlueBubbles Server) runs on macOS, so iOS clients require the server to be on a separate machine.

---

## ADR-013: Keep Widgets Small and Single-Purpose

**Decision:** Every widget should do one thing. If a widget's `build` method is growing large, or if it manages more than one distinct piece of state, it must be split into smaller named sub-widgets. There is no fixed line-count rule, but if a widget's file is approaching 300 lines or its `build` method exceeds ~60 lines, that is a strong signal to decompose.

**Context:** Large monolithic widgets have caused recurring problems in this codebase:
- A single `setState` or `Obx()` update anywhere in the widget forces the entire massive subtree to re-render.
- The file becomes too large for a human or an LLM to hold in working memory, making reasoning about behavior and side effects unreliable.
- Bugs become harder to isolate because state is spread across a large surface area.
- Adding a feature requires reading and understanding far more code than the feature itself touches.

**Rationale:**
- A small, focused widget has a narrow, predictable rebuild scope. When its one piece of state changes, only that widget re-renders — not its siblings, parents, or unrelated children.
- Small widgets can be read and understood in isolation. This matters both for human reviewers and for LLM-assisted development where context windows are finite.
- Decomposed widgets are naturally more reusable. A widget that renders "a single message's timestamp and delivery status" is useful anywhere that information needs to appear; a widget that renders "an entire message row including bubble, text, reaction strip, and timestamp" is not.
- Each sub-widget can independently manage its own `Obx()` scope, controller tag, and lifecycle — enabling the granular update patterns described in ADR-006 and ADR-011.

**How to decompose:**
- Extract any visually distinct section into its own `StatelessWidget` or `CustomStateful` subclass with a descriptive name.
- Extract any section that reads a different set of observables into its own `Obx()` scope — and if that scope is large, extract it into a named widget.
- Controllers shared between sub-widgets should be passed down via `parentController`, not re-fetched from GetIt inside each child (see `frontend.md`).
- Name extracted widgets after what they render, not where they appear: `MessageTimestamp`, not `ConversationViewBottomRow`.

**Signals that a widget needs splitting:**
- The `build` method has deeply nested conditionals spanning 30+ lines
- Two unrelated pieces of state (e.g., avatar color and typing indicator) live in the same `Obx()`
- A file contains more than one "primary" widget — helper builders that have grown large enough to have their own state
- Adding a new feature requires scrolling through hundreds of lines to find the right insertion point
- An LLM assistant asks for clarification about which part of the file to modify

**Consequences:**
- New UI features must be built as small composable widgets from the start — retrofitting decomposition is expensive.
- Prefer creating a new file per logical widget over adding private classes to an existing large file.
- The `lib/app/layouts/conversation_view/widgets/message/` directory is the canonical example of correct decomposition: 54+ files, each handling one narrow responsibility.
