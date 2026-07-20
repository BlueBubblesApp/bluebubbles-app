# BlueBubbles App -- Data Models

> Canonical model reference. Consolidates entity/DTO documentation from CLAUDE.md files across database directories.

---

## Import Rule

Always import through `lib/database/models.dart` -- the barrel that handles platform-conditional imports.
Never import directly from `lib/database/io/` or `lib/database/html/`.

---

## ObjectBox Entities (`lib/database/io/`)

Native and desktop (Android, iOS, Windows, macOS, Linux). Not used on web.

After any `@Entity` annotation change: run `dart run build_runner build`. Never edit `objectbox.g.dart` directly.

### Chat (`chat.dart`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int?` | ObjectBox PK -- nullable, assigned on first put |
| `guid` | `String` | `@Unique @Index(value)` -- server-assigned unique identifier |
| `chatIdentifier` | `String?` | iMessage chat address |
| `displayName` | `String?` | Group chat name |
| `isArchived` | `bool` | -- |
| `isPinned` | `bool` | -- |
| `muteType` | `String?` | e.g. `mute`, `donotdisturb` |

Relations:
- `messages` -- `ToMany<Message>` (backlink from `Message_.chat`)
- `handles` / `participants` -- `ToMany<Handle>`

### Message (`message.dart`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int?` | PK |
| `guid` | `String` | `@Unique @Index(value)` |
| `text` | `String?` | Plain text body |
| `dateCreated` | `int?` | Unix ms, `@Index` for sorted queries |
| `isFromMe` | `bool` | -- |
| `error` | `int` | 0 = no error |
| `hasDdResults` | `bool` | Has data detector results (links, phone numbers) |
| `attributedBodyString` | `String?` | JSON-encoded `AttributedBody` list |

Relations:
- `chat` -- `ToOne<Chat>`
- `handle` -- `ToOne<Handle>` (sender)
- `attachments` -- `ToMany<Attachment>`
- `associations` -- `ToMany<Message>` (reactions, replies)

### Attachment (`attachment.dart`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int?` | PK |
| `guid` | `String` | `@Unique` |
| `uti` | `String?` | Uniform Type Identifier (e.g. `public.jpeg`) |
| `mimeType` | `String?` | MIME type |
| `transferName` | `String?` | Original filename |
| `totalBytes` | `int?` | File size |

Backlink from `Message_.attachments`.

### Handle (`handle.dart`)

Represents a contact address (phone/email) on a specific service.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int?` | PK |
| `address` | `String` | Phone/email -- `@Unique` composite with `service` |
| `service` | `String` | `iMessage` or `SMS` |
| `country` | `String?` | ISO country code |

Relations:
- `contact` -- `ToOne<Contact>` (legacy V1)
- `contactsV2` -- backlink from `ContactV2_.handles`

### ContactV2 (`contact_v2.dart`)

Current contact system. N:M relationship with Handle.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int?` | PK |
| `displayName` | `String?` | Full display name |
| `nativeContactId` | `String` | `@Unique` -- device contact record ID |
| `avatarPath` | `String?` | Cached avatar file path |

Relations: `handles` -- `ToMany<Handle>` (N:M, owning side)

### Theme, ThemeEntry, ThemeObject

| Entity | Purpose |
|--------|---------|
| `theme.dart` | Named theme -- `name @Unique`, serialized FlutterThemeData, googleFont, gradientBg |
| `theme_entry.dart` | Reference to a Theme record; bridges theme selector to stored theme |
| `theme_object.dart` | Theme metadata wrapper used by the theme editor |

### Supporting Entities

| File | Purpose |
|------|---------|
| `fcm_data.dart` | FCM tokens and Firebase auth credentials -- persisted per device |
| `launch_at_startup.dart` | Auto-launch configuration (desktop only) |

---

## ObjectBox Conventions

```dart
@Entity()
class MyEntity {
  int? id;                           // always nullable PK

  @Index(type: IndexType.value)
  @Unique()
  String guid;

  @Property(uid: 1234567890)         // required when adding a field to existing entity
  String? optionalField;

  @Transient()
  String? computedField;             // never persisted
}
```

ToMany update -- always clear+addAll+applyToDb:
```dart
chat.handles.clear();
chat.handles.addAll(newList);
chat.handles.applyToDb();
Database.chats.put(chat);
```

ToOne:
```dart
message.handle.target = handle;
Database.messages.put(message);
```

Always close queries:
```dart
final q = (Database.messages.query(...)).build();
final results = q.find();
q.close();
```

---

## Global DTOs (`lib/database/global/`)

Plain Dart classes -- no ObjectBox annotations. Safe on all platforms. All implement `fromMap`/`toMap`.

### Settings (`settings.dart`)

50+ `Rx*` fields representing every user-configurable preference. Single source of truth for all app settings.

Read: `SettingsSvc.settings.someFlag.value`
Write: set value then `await SettingsSvc.saveSettings()`

Adding a new setting: add an `Rx*` field to `settings.dart`, persist in `toMap()`/`fromMap()`, then add a UI tile in `lib/app/layouts/settings/`.

### Message Content

| File | Purpose |
|------|---------|
| `message_part.dart` | One content chunk in a multi-part message (text, attachment, mention) |
| `attributed_body.dart` | Rich text metadata: bold, italic, mention, link, inline attachment |
| `message_summary_info.dart` | Reply/thread preview metadata shown in message bubbles |
| `chat_messages.dart` | In-memory chat to message list mapping used by MessagesService |

### Server Communication

| File | Purpose |
|------|---------|
| `payload_data.dart` | URL preview + iMessage app data wrapper |
| `server_payload.dart` | Server event envelope -- wraps action payloads from socket |
| `queue_items.dart` | Typed outgoing message queue models (`OutgoingQueueItem`, `OutgoingMessage`, `OutgoingReaction`, `OutgoingAttachment`, `OutgoingMultipartMessage`) |
| `scheduled_message.dart` | Scheduled send DTO -- nested Payload + Schedule objects |

### Contact & Location

| File | Purpose |
|------|---------|
| `structured_name.dart` | Contact name component parsing (first, last, nickname, prefix) |
| `apple_location.dart` | Apple Maps coordinate + label model |
| `findmy_friend.dart` | Find My friend location and status model |
| `findmy_device.dart` | Find My device location and battery model |

### Media & Files

| File | Purpose |
|------|---------|
| `platform_file.dart` | Cross-platform file abstraction for attachment send/receive |
| `async_image_input.dart` | Async image loading input wrapper for lazy avatar loading |

### Theme & Misc

| File | Purpose |
|------|---------|
| `theme_colors.dart` | Color palette DTO for custom theme storage |
| `isolate.dart` | Isolate communication marker type (used for request routing) |

---

## Cross-Cutting Models (`lib/models/`)

Pure data classes used across multiple layers. Not ObjectBox entities. Safe across isolate boundaries.

Barrel: `lib/models/models.dart`

| File | Purpose |
|------|---------|
| `app_update_info.dart` | App version check result (latest version, download URL) |
| `attachment_upload_progress.dart` | Upload progress tracking state for an attachment send |
| `chat_sync_page.dart` | Pagination cursor for chat sync requests |
| `contact_search_result.dart` | A single result from a contact search query |
| `dispatched_event.dart` | Event envelope used by EventDispatcherSvc |
| `fcm_data_info.dart` | Firebase Cloud Messaging token + device info DTO |
| `handle_lookup_key.dart` | Composite key (address + service) for handle deduplication |
| `handle_sync_page.dart` | Pagination cursor for handle sync requests |
| `location_attachment_data.dart` | Parsed location payload from a location message |
| `message_receipt_info.dart` | Delivered/read receipt metadata for a message |
| `message_reply_context.dart` | Context for a reply thread entry (parent GUID, part index) |
| `message_save_result.dart` | Result returned by message save action (id, status) |
| `message_update_event.dart` | Carries field diffs for a message update notification |
| `server_details.dart` | Server version, OS, build info from /server/info endpoint |
| `server_update_info.dart` | Server update availability info |
| `text_entity_match.dart` | A matched text entity (phone, email, URL) from ML Kit |
| `theme_pair.dart` | Light + dark ThemeData pair for a named theme |

Rules: no Rx* fields, no DB annotations, no GetX. When an action needs to return structured data without an ObjectBox entity, create a model here.
