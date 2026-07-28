# settings/pages/ — Settings Page Router

One subdirectory per settings category. Each contains one or more `*_panel.dart` files.

## Subdirectories

| Directory | Contents | Panel Count |
|-----------|----------|-------------|
| `advanced/` | Firebase, Private API, Redacted Mode, Notification Providers, Tasker, UnifiedPush | 6 |
| `conversation_list/` | Chat list appearance, pinned order | 2 |
| `desktop/` | Desktop-specific settings | 1 |
| `message_view/` | Attachment, conversation, message options order, and text field buttons panels | 4 |
| `misc/` | About, logging (live + export), misc tweaks, soft-deleted chats, troubleshoot | 6 |
| `profile/` | Profile / account info panel | 1 |
| `scheduling/` | Scheduled messages & reminders (tri-platform) | 11 |
| `server/` | Server connection, backup/restore, OAuth, iMessage stats | 6 + 2 subdirs |
| `storage/` | Storage Analyzer — attachment storage usage & cleanup | 4 + 1 subdir |
| `system/` | System notification settings | 1 |
| `theming/` | Theming panel + advanced, avatar, background, theme studio | 5 + 4 subdirs |

## Detailed Subdirectories → own CLAUDE.md
- `scheduling/` → `CLAUDE.md` inside
- `server/` → `CLAUDE.md` inside
- `storage/` → `CLAUDE.md` inside
- `theming/` → `CLAUDE.md` inside
- `advanced/` → `CLAUDE.md` inside
- `misc/` → `CLAUDE.md` inside

## Panel Naming Convention
Each panel is named `<feature>_panel.dart`. Tri-platform panels use `cupertino_<feature>_panel.dart`, `material_<feature>_panel.dart`, `samsung_<feature>_panel.dart` + a shared `<feature>_panel.dart` entry point.

## Parent
`../CLAUDE.md` (settings) — owns the settings page router and the `settings_page.dart` entry.
