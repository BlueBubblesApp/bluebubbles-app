# database/global/ — Shared DTOs (All Platforms)

Plain Dart classes — no ObjectBox annotations. Safe to use on web. All have `fromMap`/`toMap`.

## Core App Models
| File | Purpose |
|------|---------|
| `settings.dart` | 50+ `Rx*` preference fields — the single source of truth for all app settings |
| `message_part.dart` | One content chunk of a multi-part message |
| `attributed_body.dart` | Rich text formatting metadata (bold, italic, mention, link, attachment) |
| `message_summary_info.dart` | Reply/thread preview metadata |
| `chat_messages.dart` | In-memory chat ↔ message list mapping (used by `MessagesService`) |

## Server Communication
| File | Purpose |
|------|---------|
| `payload_data.dart` | URL preview + iMessage app data wrapper |
| `server_payload.dart` | Server event envelope (wraps action payloads from socket) |
| `queue_items.dart` | Typed outgoing queue models (`OutgoingQueueItem`, `OutgoingMessage`, `OutgoingReaction`, `OutgoingAttachment`, `OutgoingMultipartMessage`) |
| `scheduled_message.dart` | Scheduled send DTO — `Payload` + `Schedule` nested objects |

## Contact & Location
| File | Purpose |
|------|---------|
| `apple_location.dart` | Apple Maps coordinate + label model |
| `findmy_friend.dart` | Find My friend location model |
| `findmy_device.dart` | Find My device location model |

## Media & Files
| File | Purpose |
|------|---------|
| `platform_file.dart` | Cross-platform file abstraction for attachments |
| `async_image_input.dart` | Async image loading input wrapper |

## Theme
| File | Purpose |
|------|---------|
| `theme_colors.dart` | Color palette DTO for custom themes |

## Other
| File | Purpose |
|------|---------|
| `isolate.dart` | Isolate communication marker type |

## Adding a New Setting
Edit `settings.dart` — add an `Rx*` field and persist it in `toMap()`/`fromMap()`.
Then add the UI tile in `lib/app/layouts/settings/` (see that directory's `CLAUDE.md`).
