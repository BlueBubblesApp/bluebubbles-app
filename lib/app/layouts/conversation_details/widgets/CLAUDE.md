# conversation_details/widgets/ — Detail Panel Sub-Widgets

Reusable widgets composing the conversation details / info panel.

## Root widgets

| File | Purpose |
|------|---------|
| `chat_info.dart` | **iOS-only.** Top section: avatar, name, participant count, edit name button. Material/Samsung use `../material/material_chat_header.dart` instead — routed from `conversation_details.dart` by skin |
| `participants_findmy_card/` | Find My map preview for chat participants; opens the map bottom sheet |
| `chat_options.dart` | **iOS-only.** Action row: mute, pin, archive, block, delete. Material/Samsung use `../material/material_chat_options.dart` instead |
| `contact_tile.dart` | Single participant row (avatar, name, address, remove button) — shared by both skins |
| `participants_list.dart` | **iOS-only.** Scrollable list of `ContactTile`s for group chats. Material/Samsung use `../material/material_participants_section.dart` instead |
| `attachment_section_header.dart` | Section label + "Show more" for attachment previews |
| `attachments_loader.dart` | Loads shared attachments for media/docs/locations |
| `media_gallery_card.dart` | Tappable thumbnail card for media or file items |

All four widgets in `sections/` plus `attachment_section_header.dart` and `media_gallery_card.dart`
take an `expressive` flag (default `false`), threaded from `conversation_details.dart` /
`conversation_attachments.dart` by `SettingsSvc.settings.skin.value != Skins.iOS`. On expressive:
sentence-case headers via `M3ESectionHeader`, `M3EShapes.lg` card corners tonally derived from
`context.tileColor` (never a raw `colorScheme.surfaceContainer*` read), sections hide entirely
(`AnimatedSize` + `M3EMotion.spatialFast`) instead of rendering an empty placeholder once loading
finishes, and the media grid column count follows the Material window size class instead of
`max(2, width ~/ 200)`.

## `filters/`

| File | Purpose |
|------|---------|
| `media_filters_sheet.dart` | Shared attachment filters bottom sheet + app bar tune button |

## `sections/`

| Path | Purpose |
|------|---------|
| `media/media_grid_section.dart` | Photo/video grid (preview + full page) |
| `media/media_filter_selector.dart` | Inline All/Images/Videos segmented control |
| `links/links_section.dart` | Shared URL link previews |
| `links/links_search_helper.dart` | Link search scoring and sort |
| `documents/documents_section.dart` | Shared files/documents grid |
| `documents/documents_search_helper.dart` | File search scoring and sort |
| `locations/locations_section.dart` | Shared location message cards |

## Related
- Parent panel: `../CLAUDE.md` (conversation_details)
- Dialogs (add participant, leave chat, etc.): `../dialogs/CLAUDE.md`
- Contact avatar: `lib/app/components/avatars/CLAUDE.md`
