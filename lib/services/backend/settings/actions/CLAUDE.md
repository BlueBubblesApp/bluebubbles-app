# services/backend/settings/actions/ — SharedPreferences Category Actions

One class per preference category, each wrapping a `SharedPreferencesService` instance with typed get/set methods for that category's keys. These are the implementation behind the `PrefsSvc.<category>` category helpers described in `../CLAUDE.md` — call through `PrefsSvc`, not these classes directly.

## Files
| File | Class | Category (`PrefsSvc.<category>`) |
|------|-------|-----------------------------------|
| `shared_preferences_admin_actions.dart` | `SharedPreferencesAdminActions` | `admin` |
| `shared_preferences_database_actions.dart` | `SharedPreferencesDatabaseActions` | `database` |
| `shared_preferences_desktop_actions.dart` | `SharedPreferencesDesktopActions` | `desktop` — window dimensions/offsets, window effect, split view ratio |
| `shared_preferences_firebase_actions.dart` | `SharedPreferencesFirebaseActions` | `firebase` |
| `shared_preferences_messaging_actions.dart` | `SharedPreferencesMessagingActions` | `messaging` — last opened chat, draft/reply state |
| `shared_preferences_network_actions.dart` | `SharedPreferencesNetworkActions` | `network` |
| `shared_preferences_server_actions.dart` | `SharedPreferencesServerActions` | `server` — cached server details (OS version, server version) |
| `shared_preferences_system_actions.dart` | `SharedPreferencesSystemActions` | `system` |
| `shared_preferences_theme_actions.dart` | `SharedPreferencesThemeActions` | `theme` — selected light/dark theme name |

## Pattern
Each class takes a `SharedPreferencesService` in its constructor and exposes typed getters/setters over `service.i.getX()`/`service.i.setX()` for a fixed set of private key constants — never raw strings outside the class.

```dart
class SharedPreferencesDesktopActions {
  static const String _windowWidthKey = 'window-width';
  final SharedPreferencesService service;
  SharedPreferencesDesktopActions(this.service);

  double? getWindowWidth() => service.i.getDouble(_windowWidthKey);
  Future<void> setWindowDimensions({required double width, required double height}) async { ... }
}
```

## Adding a new preference
1. Add the key constant + getter/setter to the relevant category file here (or create a new category file for a new domain).
2. Expose it via the category's property on `PrefsSvc` if not already covered by an existing method.
3. This is for **low-level bootstrap values only** (see `../CLAUDE.md`) — app settings (`Settings` class fields) go through `SettingsSvc` instead, not here.

## Related
- Category helper access pattern (`PrefsSvc.desktop`, `PrefsSvc.theme`, etc.): `../CLAUDE.md`
- `SharedPreferencesService` / `PrefsSvc`: `../shared_preferences_service.dart`
