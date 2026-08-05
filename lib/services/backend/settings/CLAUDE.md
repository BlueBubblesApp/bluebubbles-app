# services/backend/settings/ — Settings Persistence

## Files

### `settings_service.dart` — `SettingsService` / `SettingsSvc`

GetIt singleton. The authoritative source for all app settings at runtime.

- Holds the `Settings` object (defined in `lib/database/global/settings.dart`) as `SettingsSvc.settings`
- All settings fields are `Rx*` observables — widgets can `Obx()` directly on any field
- Reads/writes settings via `PrefsInterface` → `PrefsActions` → ObjectBox in the GlobalIsolate

**Reading a setting anywhere:**
```dart
SettingsSvc.settings.enablePrivateAPI.value
```

**Saving a setting change:**
```dart
SettingsSvc.settings.myField.value = newValue;
await SettingsSvc.settings.saveOneAsync('myField');   // or saveManyAsync([...]) / saveAsync() for all fields
```

Also owns `AppUpdateInfo` and `ServerUpdateInfo` models for update check state.

## Actions (`actions/`) → `actions/CLAUDE.md`
Category-scoped `SharedPreferences` action helpers, one file per domain. Accessed via the category helpers on `PrefsSvc` (e.g. `PrefsSvc.desktop`, `PrefsSvc.theme`) described below — don't call these action files directly.

---

### `shared_preferences_service.dart` — `SharedPreferencesService` / `PrefsSvc`

Thin wrapper around Flutter's `SharedPreferences` for simple key-value storage that must be available before ObjectBox initializes (e.g. during background isolate startup).

Used for: callback handle storage (background isolate registration), install timestamp, and any other primitive values that need to survive a cold start before the database is ready.

```dart
PrefsSvc.desktop.setWindowDimensions(width: 1280, height: 720);
final themeName = PrefsSvc.theme.getSelectedDarkTheme();
await PrefsSvc.messaging.clearLastOpenedChat();
```

Use category helpers instead of `PrefsSvc.i` direct access. Keep raw `PrefsSvc.i` usage restricted to helper implementation internals.

For app settings (everything in the `Settings` class), use `SettingsSvc` instead. `PrefsSvc` is only for low-level bootstrap values.

---

### `desktop_shared_preferences_store.dart` — `DesktopSharedPreferencesStore`

Custom `SharedPreferencesAsyncPlatform` backend registered on Windows/Linux only (in `SharedPreferencesService.init()`, so it covers every isolate). The stock desktop backends cache the prefs JSON per isolate, so writes from the GlobalIsolate/sync isolate silently revert keys written by the main isolate (flutter/flutter#143844), and non-atomic writes can corrupt the file on crash (flutter/flutter#89211).

This store never caches, serializes writes across isolates/processes via an exclusively-created lock file, writes atomically (temp file + rename), and keeps a `.bak` snapshot refreshed on every successful write. A corrupt file is quarantined and restored from that backup (at startup and on mid-session reads). Storage path/format match the stock implementation. Do not reintroduce stock `shared_preferences` desktop backends or cache prefs values across isolates.
