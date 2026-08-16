# lib/models/ — Cross-Cutting DTOs & View Models

See `docs/MODELS.md` for the consolidated cross-directory entity/DTO field reference.

Plain data classes used across multiple layers. Not ObjectBox entities — no `@Entity` annotations. All serializable and safe to cross isolate boundaries.

Barrel export: `models/models.dart`

## File Map

| File | Purpose |
|------|---------|
| `app_update_info.dart` | App version check result (latest version, download URL) |
| `attachment_upload_progress.dart` | Upload progress tracking state for an attachment send |
| `chat_sync_page.dart` | Pagination cursor for chat sync requests |
| `contact_search_result.dart` | A single result from a contact search query |
| `dispatched_event.dart` | Event envelope used by `EventDispatcherSvc` |
| `fcm_data_info.dart` | Firebase Cloud Messaging token + device info DTO |
| `handle_audit_result.dart` | Developer Tools "Handle Auditing" scan result for a single handle missing `originalROWID`, plus remediation status |
| `handle_lookup_key.dart` | Composite key (address + service) for handle deduplication |
| `handle_sync_page.dart` | Pagination cursor for handle sync requests |
| `location_attachment_data.dart` | Parsed location payload from a location message |
| `message_receipt_info.dart` | Delivered/read receipt metadata for a message |
| `message_reply_context.dart` | Context for a reply thread entry (parent message, part index, optional attachment GUID) |
| `message_save_result.dart` | Result returned by message save action (id, status) |
| `message_update_event.dart` | Carries field diffs for a message update notification |
| `parsed_log_entry.dart` | Parsed structure of a single log file line |
| `server_details.dart` | Server version, OS, build info returned from `/server/info` |
| `server_update_info.dart` | Server update availability info |
| `storage_analysis.dart` | Storage analyzer DTOs — segments, results, age filter, progress state |
| `text_entity_match.dart` | A matched text entity (phone, email, URL) extracted by ML Kit |
| `theme_pair.dart` | Light + dark `ThemeData` pair for a named theme |

## Web Stub
`html/contact_v2.dart` — stub for web platform (no native contact access on web).

## Rules
- These are pure data models — no `Rx*` fields, no DB annotations, no GetX
- Mutable fields are fine (used as transfer objects, not reactive state)
- Extend or create models here when an action needs to return structured data without a DB entity
