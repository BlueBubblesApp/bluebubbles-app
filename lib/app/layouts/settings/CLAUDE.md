# settings/ — App Settings

## Page Categories (`pages/`) → `pages/CLAUDE.md`
| Directory | Content |
|-----------|---------|
| `theming/` | Theme picker; `advanced/` for color customization; `avatar/` for avatar colors |
| `message_view/` | Message display preferences |
| `conversation_list/` | Chat list display preferences |
| `server/` | Server connection, backup/restore, OAuth |
| `system/` | Notifications, permissions |
| `profile/` | User profile |
| `scheduling/` | Scheduled messages and reminders |
| `advanced/` | Private API, Firebase, Tasker, Redacted mode, UnifiedPush |
| `misc/` | Logging, troubleshoot, about |
| `desktop/` | Desktop-specific options |

## Reusable Widgets (`widgets/`)
- `tiles/` — preference tile components (primary building block):
  - `redacted_mode_tile.dart` — Redacted Mode toggle + explainer
  - `private_api_tile.dart` — Private API status/toggle
  - `connection_server_tile.dart` — server connection status row
  - `contact_upload_progress.dart` — contact sync upload progress row
- `layout/` — page layout containers
- `content/` — **core building blocks** (`SettingsTile`, `SettingsSwitch`, `SettingsOptions`, `SettingsSlider`) → CLAUDE.md inside
- `search/` — settings search UI → CLAUDE.md inside

## Dialogs (`dialogs/`)
- `sync_dialog.dart` — manual settings/theme sync progress dialog
- `create_new_theme_dialog.dart` — name + create a new custom theme
- `old_themes_dialog.dart` — browse/restore legacy theme format entries
- `custom_headers_dialog.dart` — edit custom HTTP headers sent to the server
- `notification_settings_dialog.dart` — OS-level notification permission prompt/redirect

## Adding a New Setting
1. Add field to `lib/database/global/settings.dart`
2. Add tile in the appropriate `pages/*/` file using widgets from `widgets/tiles/`
