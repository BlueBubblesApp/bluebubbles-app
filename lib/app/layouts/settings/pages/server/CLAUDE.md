# settings/pages/server/ — Server Connection & Management

Settings panels for managing the BlueBubbles server connection, authentication, backup/restore, and iMessage statistics.

## Files (top-level)

| File | Purpose |
|------|---------|
| `server_management_panel.dart` | Main server settings panel: URL, QR scan, ping, restart server |
| `backup_restore_panel.dart` | Backup/restore UI for settings + themes |
| `backup_restore_actions.dart` | Backup/restore data operations (fetch, delete, device default naming) |
| `backup_restore_dialogs.dart` | Shared backup/restore dialogs (destination picker) |
| `backup_restore_types.dart` | Backup enums (`BackupDestination`, `BackupKind`) |
| `chat_backup_identifier.dart` | Server-agnostic chat identification shared by every chat-scoped backup |
| `pinned_chats_backup.dart` | Backup/restore of pinned chat order |
| `custom_groups_backup.dart` | Backup/restore of custom groups and their member chats |
| `chat_appearance_backup.dart` | Backup/restore of per-chat themes + dynamic wallpapers (and their sub-configs) |
| `oauth_panel.dart` | OAuth /Google sign-in for cloud relay connection |

## Subdirectories

### `connection_panel/` — Server Connection Setup
Platform-specific connection panels (URL input, QR scan, connection test):

| File | Platform |
|------|----------|
| `connection_panel.dart` | Entry point / shared logic |
| `connection_panel_helpers.dart` | Shared helper widgets (URL field, test button) |
| `cupertino_connection_panel.dart` | iOS skin |
| `material_connection_panel.dart` | Material skin |
| `samsung_connection_panel.dart` | Samsung skin |

### `imessage_stats/` — iMessage Account Statistics
Live stats fetched from the server (account status, active handles, relay info):

| File | Platform |
|------|----------|
| `imessage_stats_page.dart` | Entry point / shared logic |
| `imessage_stats_helpers.dart` | Shared helper widgets |
| `cupertino_imessage_stats_page.dart` | iOS skin |
| `material_imessage_stats_page.dart` | Material skin |
| `samsung_imessage_stats_page.dart` | Samsung skin |

## Related
- HTTP API calls: `lib/services/network/http_service.dart`
- Setup flow (first-run): `lib/app/layouts/setup/CLAUDE.md`
- Settings router: `../CLAUDE.md`

## Backup/Restore Notes
- Keep side-effectful API/file operations in `backup_restore_actions.dart`.
- Keep destination selection and other shared prompts in `backup_restore_dialogs.dart`.
- Use `BackupDestination`/`BackupKind` enums rather than implicit bool/string mode flags.
- Chat-scoped extras ride along inside the settings backup JSON under their own top-level keys
  (`pinnedChats`, `customGroups`, `chatAppearance`). `Settings.updateFromMap` reads keys it knows
  by name, so extra keys pass through it untouched.
- Never key a chat-scoped backup entry off `chat.guid` — guids are server-assigned. Use
  `ChatBackupIdentifier.export`/`.resolve` so entries match by display name / participant addresses.
- Anything that only exists as a file in this device's app storage (custom background images,
  adaptive-background themes derived from them) stays out of backups — they'd need the bytes
  embedded. Report those as skipped instead of writing an unusable path.
