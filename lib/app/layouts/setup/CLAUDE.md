# setup/ — Onboarding Flow

## Entry Point
`setup_view.dart` — `PageView` orchestrator driven by `SetupViewController`

## Page Order
1. `pages/welcome/welcome_page.dart`
2. `pages/setup_checks/mac_setup_check.dart` — macOS permission checks
3. `pages/setup_checks/battery_optimization.dart` — Android battery optimization warning
4. `pages/permissions/request_permissions.dart` — contact/notification permission request
5. `pages/sync/qr_code_scanner.dart` OR `pages/sync/server_credentials.dart` — connect to server
6. `pages/sync/sync_settings.dart` — configure what to sync
7. `pages/sync/sync_progress.dart` — live progress during initial sync

## Dialogs (`dialogs/`)
- `connecting_dialog.dart` — "Connecting…" overlay
- `manual_entry_dialog.dart` — manual server address + auth key form
- `failed_to_connect_dialog.dart` — connection failure recovery options
- `failed_to_scan_dialog.dart` — QR scan failure recovery

## Template
`pages/page_template.dart` — shared page layout (header, scrollable body, action buttons). Use for any new setup page.

## Controller
`SetupViewController` — manages page index, server connection state, and sync kickoff.
