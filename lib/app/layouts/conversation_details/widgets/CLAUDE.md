# conversation_details/widgets/ — Detail Panel Sub-Widgets

Reusable widgets composing the conversation details / info panel.

## Root widgets

| File | Purpose |
|------|---------|
| `chat_info.dart` | Top section: avatar, name, participant count, edit name button |
| `participants_findmy_map_card.dart` | Horizontal Find My map preview for chat participants; tap opens map bottom sheet |
| `chat_options.dart` | Action row: mute, pin, archive, block, delete |
| `contact_tile.dart` | Single participant row (avatar, name, address, remove button) |
| `participants_list.dart` | Scrollable list of `ContactTile`s for group chats |
| `attachment_section_header.dart` | Section label + "Show more" for attachment previews |
| `attachments_loader.dart` | Loads shared attachments for media/docs/locations |
| `media_gallery_card.dart` | Tappable thumbnail card for media or file items |

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
