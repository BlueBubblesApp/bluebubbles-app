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
| `pinned_chats_backup.dart` | Backup/restore of pinned chat order |
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
