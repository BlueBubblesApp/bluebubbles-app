# services/backend_ui_interop/ — Backend-to-UI Event Bridge

Two files. This subsystem decouples backend services from UI widgets for one-off cross-cutting events.

## Files
- `event_dispatcher.dart` — `EventDispatcher` broadcast stream; shorthand getter `EventDispatcherSvc`
- `intents.dart` — Flutter `Intent`/`Action` pairs for keyboard shortcuts and system-level commands

## EventDispatcher

A singleton `StreamController<Tuple2<String, dynamic>>.broadcast()`. Any backend service can emit a named event; any widget can subscribe.

**Emit (from service/backend):**
```dart
EventDispatcherSvc.emit("chat-updated", chatGuid);
```

**Subscribe (in a widget's `initState`):**
```dart
_sub = EventDispatcherSvc.stream.listen((event) {
  if (event.item1 == "chat-updated") {
    final guid = event.item2 as String;
    // handle update
  }
});
```

**Always cancel in `dispose`:**
```dart
_sub?.cancel();
```

**When to use vs Obx():** Use `EventDispatcher` for one-shot signals that don't represent persistent state (e.g. "scroll to bottom", "play effect"). Use `Rx*` + `Obx()` for state that widgets need to render continuously (e.g. the active-chat highlight reads `ChatsSvc.activeChatGuid`).

## intents.dart — Flutter Intents

Keyboard shortcut bindings used primarily on Desktop. Each `Intent` has a corresponding `Action` that performs the operation.

| Intent | Action |
|--------|--------|
| `OpenSettingsIntent` | Navigate to settings |
| `OpenNewChatCreatorIntent` | Open chat creator |
| `OpenSearchIntent` | Open search view |
| `ReplyRecentIntent` | Reply to most recent received message |
| `HeartRecentIntent` | Heart (love) most recent message |
| `LikeRecentIntent` | Like most recent message |
| `OpenNextChatIntent` | Cycle to next chat |
| `OpenPreviousChatIntent` | Cycle to previous chat |
| `OpenChatDetailsIntent` | Open conversation details |
| `StartIncrementalSyncIntent` | Trigger incremental sync |
| `GoBackIntent` | Navigate back |

Intents are registered in the widget tree via `Shortcuts` + `Actions` widgets. To add a new shortcut, add an `Intent` + `Action` pair here and register the key binding in the appropriate widget.
