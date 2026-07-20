# Services Rules — Service Layer, Events & Platform Bridges

## Service Registration & Access

All services are GetX singletons. Shortcuts are defined in `lib/services/services.dart`.

**Access pattern:**
```dart
// Via shorthand getter (preferred — defined in services.dart)
ChatsSvc.activeChat
SettingsSvc.settings.someField.value
EventDispatcherSvc.emit('type', data)

// Via GetIt for network/utility services
GetIt.I<HttpService>()
GetIt.I<GlobalIsolate>()

// Via Get.find for GetX-registered services
Get.find<MyService>()
```

**Registering a new service:**
```dart
// Check before registering to avoid duplicate registration
final svc = Get.isRegistered<MyService>()
    ? Get.find<MyService>()
    : Get.put(MyService());
```

Add the shorthand getter to `lib/services/services.dart`.

## Event Dispatch (Backend → UI)

`EventDispatcherSvc` is a broadcast stream of `Tuple2<String, dynamic>` (type, payload).

**Emitting:**
```dart
EventDispatcherSvc.emit('chat-updated', chat.guid);
```

**Listening (in `initState`):**
```dart
EventDispatcherSvc.stream.listen((event) {
  if (event.item1 == 'chat-updated' && mounted) {
    final guid = event.item2 as String;
    // handle update
  }
});
```

- Use named string event types — document new event types near the emit site.
- Always check `mounted` before calling `setState()` in a listener.
- Cancel stream subscriptions in `dispose()`.

## Background Processing

- Heavy/blocking operations belong off the main thread: `await runAsync(() => expensiveWork())`.
- Cross-isolate communication goes through `GlobalIsolate` via `IsolateRequestType` — don't spawn raw `Isolate.spawn`.
- `background_isolate.dart` (Android) handles Dart work triggered by platform background tasks.

## Method Channels (Android Bridge)

```dart
await MethodChannelSvc.invokeMethod('method-name', {
  'key': value,
});
```

- Method names use kebab-case strings matching the Kotlin handler.
- Corresponding Kotlin code lives in `android/app/src/main/kotlin/.../services/`.
- Always guard method channel calls behind `!kIsWeb && !kIsDesktop` where appropriate.
- New method channels need handlers on both sides: Dart (`method_channel_service.dart`) and Kotlin (`MainActivity.kt` or a dedicated service).

## Settings Access

```dart
// Read
SettingsSvc.settings.someFlag.value

// Write (triggers reactive update)
SettingsSvc.settings.someFlag.value = newValue;
await SettingsSvc.saveSettings();
```

New settings fields are defined in `lib/database/global/settings.dart` (see `database.md`).

## Navigation

```dart
NavigationSvc.push(context, MyWidget());
NavigationSvc.pushAndRemoveUntil(context, MyWidget());
NavigationSvc.pop(context);
```

Use `NavigationSvc` — don't call `Navigator.of(context)` directly in feature code.

## Contacts

- V1 (legacy): `ContactsSvc` — returns `Contact` objects
- V2 (current): `ContactsSvcV2` — returns `ContactV2` objects
- Prefer V2 for any new feature work. Check `ContactsSvcV2.isHandleUpdated(handle.id)` in `ever()` listeners for reactive contact updates.
