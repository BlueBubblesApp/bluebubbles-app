# BlueBubbles App -- Data Models

> Canonical model reference. Consolidates entity/DTO documentation from CLAUDE.md files across database directories.

---

## Import Rule

Always import through `lib/database/models.dart` -- the barrel that handles platform-conditional imports.
Never import directly from `lib/database/io/` or the web stub directory (`lib/models/html/`).

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
| `isArchived` | `bool?` | -- |
| `muteType` | `String?` | e.g. `mute`, `mute_individuals`, `temporary_mute`, `text_detection` |
| `muteArgs` | `String?` | Args for the mute type (comma-separated individuals/text, or a mute-until timestamp) |
| `isPinned` | `bool?` | -- |
| `hasUnreadMessage` | `bool?` | -- |
| `displayName` | `String?` | Group chat name |
| `autoSendReadReceipts` | `bool?` | Per-chat override of the global setting |
| `autoSendTypingIndicators` | `bool?` | Per-chat override of the global setting |
| `textFieldText` | `String?` | Persisted draft text for the compose field |
| `textFieldAttachments` | `List<String>` | Persisted draft attachment paths |
| `dbOnlyLatestMessageDate` | `DateTime?` | `@Property(uid: 526293286661780207)` -- sort key kept in sync with `dbLatestMessage` via `setLatestMessage()` |
| `dateDeleted` | `DateTime?` | -- |
| `style` | `int?` | `43` = group chat (see `isGroup`) |
| `lockChatName` | `bool` | -- |
| `lockChatIcon` | `bool` | -- |
| `lastReadMessageGuid` | `String?` | -- |
| `customThemeLight` / `customThemeDark` | `String?` | -- |
| `customAvatarPath` / `customBackgroundPath` / `pinIndex` | `String?` / `String?` / `int?` | Backed by private `Rxn*` fields; getter/setter pairs, not plain fields |
| `sendProgress` | `RxDouble` | `@Transient()` -- send-progress UI state, not persisted |

Relations:
- `dbLatestMessage` -- `ToOne<Message>` -- O(1) lookup of the chat's latest message
- `messages` -- `ToMany<Message>`, `@Backlink('chat')`
- `handles` -- `ToMany<Handle>` -- the real relation
- `participants` -- `@Transient() List<Handle>` -- serialization-only mirror of `handles`; never write to this directly, use `handles`

### Message (`message.dart`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int?` | PK |
| `originalROWID` | `int?` | Server-side ROWID, preserved across GUID swaps |
| `guid` | `String?` | `@Unique @Index(value)` -- nullable until the server assigns one (temp GUIDs start with `temp-`) |
| `handleId` | `int?` | Legacy FK to `Handle.originalROWID` -- prefer `getHandle()` / `handleRelation` |
| `otherHandle` | `int?` | Secondary handle for participant-add/remove group events |
| `text` | `String?` | Plain text body |
| `subject` | `String?` | -- |
| `country` | `String?` | -- |
| `dateCreated` | `DateTime?` | `@Index()` |
| `isFromMe` | `bool?` | -- |
| `hasDdResults` | `bool?` | Has data detector results (links, phone numbers) |
| `datePlayed` | `DateTime?` | Audio message played timestamp |
| `hasEffectPlayed` | `bool` | -- |
| `itemType` | `int?` | Group-event type (name change, photo change, participant add/remove, location, kept-audio, FaceTime, ...) |
| `groupTitle` | `String?` | -- |
| `groupActionType` | `int?` | -- |
| `balloonBundleId` | `String?` | iMessage app / interactive-message identifier |
| `associatedMessageGuid` / `associatedMessagePart` / `associatedMessageType` | `String?` / `int?` / `String?` | Reaction/reply linkage |
| `expressiveSendStyleId` | `String?` | -- |
| `handle` | `Handle?` | Legacy embedded object; being migrated off in favor of `handleRelation` |
| `hasAttachments` / `hasReactions` | `bool` | -- |
| `dateDeleted` | `DateTime?` | -- |
| `metadata` / `dbMetadata` | `Map<String, dynamic>?` / `String?` | JSON-backed pair |
| `threadOriginatorGuid` / `threadOriginatorPart` | `String?` | Reply-thread linkage |
| `bigEmoji` | `bool?` | -- |
| `attributedBody` / `dbAttributedBody` | `List<AttributedBody>` (`@Transient`) / `String?` | JSON-encoded getter/setter pair for persistence |
| `messageSummaryInfo` / `dbMessageSummaryInfo` | `List<MessageSummaryInfo>` (`@Transient`) / `String?` | JSON-backed pair |
| `payloadData` / `dbPayloadData` | `PayloadData?` (`@Transient`) / `String?` | JSON-backed pair |
| `hasApplePayloadData` | `bool` | -- |
| `wasDeliveredQuietly` / `didNotifyRecipient` | `bool` | -- |
| `isBookmarked` | `bool` | -- |
| `error` | `int` | Getter/setter backed by `RxInt`; 0 = no error |
| `errorMessage` | `String?` | Human-readable send-error description |
| `dateRead` / `dateDelivered` / `dateEdited` | `DateTime?` | Getter/setter pairs backed by `Rxn<DateTime>` |
| `isDelivered` | `bool` | Getter/setter backed by `RxBool`; getter also returns `true` if `dateDelivered != null` |
| `associatedMessages` | `List<Message>` | Plain field (reactions, replies), **not** an ObjectBox `ToMany` |

Relations:
- `chat` -- `ToOne<Chat>`
- `handleRelation` -- `ToOne<Handle>` (sender; migrating off the legacy embedded `handle` field above -- prefer `getHandle()`, which reads `handleRelation.target` and falls back to a lookup by `handleId`)
- `dbAttachments` -- `ToMany<Attachment>`, `@Backlink('message')`

### Attachment (`attachment.dart`)

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int?` | PK |
| `originalROWID` | `int?` | Server-side ROWID |
| `guid` | `String?` | `@Unique @Index(value)` |
| `uti` | `String?` | Uniform Type Identifier (e.g. `public.jpeg`) |
| `mimeType` | `String?` | MIME type |
| `isOutgoing` | `bool?` | -- |
| `transferName` | `String?` | Original filename |
| `totalBytes` | `int?` | File size |
| `height` / `width` | `int?` | -- |
| `bytes` | `Uint8List?` | `@Transient()` -- in-memory only |
| `webUrl` | `String?` | -- |
| `hasLivePhoto` | `bool` | -- |
| `isDownloaded` | `bool` | -- |
| `metadata` / `dbMetadata` | `Map<String, dynamic>?` / `String?` | JSON-backed pair |
| `exif` | `Map<String, dynamic>?` | JSON-encoded on `toMap()`; `null` = never loaded, `{}` = loaded with no EXIF data |

Relations:
- `message` -- `ToOne<Message>` (the owning side; `Message.dbAttachments` is the backlink)

### Handle (`handle.dart`)

Represents a contact address (phone/email) on a specific service.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int?` | PK |
| `originalROWID` | `int?` | Server-side ROWID |
| `uniqueAddressAndService` | `String` | `@Unique()` -- synthesized `"$address/$service"`; this, not `address`, is the unique field |
| `address` | `String` | Phone/email -- not unique on its own |
| `formattedAddress` | `String?` | Display-formatted phone number, filled in by sync or on demand |
| `service` | `String` | `iMessage` or `SMS` |
| `country` | `String?` | ISO country code |
| `defaultEmail` / `defaultPhone` | `String?` | User-chosen default address for a multi-address contact |
| `color` | `String?` | Custom avatar color override |

Relations:
- `contactsV2` -- `ToMany<ContactV2>`, `@Backlink('handles')` (no legacy v1 `Contact` relation remains -- that class was removed)

### ContactV2 (`contact_v2.dart`)

Current contact system. N:M relationship with Handle.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `int` | `@Id()` -- non-nullable, defaults to `0` until ObjectBox assigns one |
| `displayName` | `String` | Required, non-nullable |
| `nativeContactId` | `String` | `@Unique @Index()` -- device contact record ID (or a synthesized ID for server-only contacts, despite the name) |
| `avatarPath` | `String?` | Cached avatar file path |
| `addresses` | `List<String>` | Normalized (digits-only phone / lowercased email) addresses used for matching |
| `isNative` | `bool` | Whether this came from the device's native contact store vs. synced from the server |
| `nickname` / `firstName` / `lastName` / `middleName` / `namePrefix` / `nameSuffix` | `String?` | Structured name fields (this is where the old standalone `structured_name.dart` DTO's data now lives) |
| `company` | `String?` | -- |
| `phoneNumbers` / `dbPhoneNumbers` | `List<ContactPhone>` (`@Transient`) / `String?` | JSON-backed pair; `ContactPhone` is a labeled `{number, label}` value type in this same file |
| `emailAddresses` / `dbEmailAddresses` | `List<ContactEmail>` (`@Transient`) / `String?` | JSON-backed pair; `ContactEmail` is a labeled `{address, label}` value type in this same file |

Relations: `handles` -- `ToMany<Handle>` (N:M, owning side)

### Theme, ThemeEntry, ThemeObject

| Entity | Class | Purpose |
|--------|-------|---------|
| `theme.dart` | `ThemeStruct` | Current theme entity -- `name @Unique`, `gradientBg`, `googleFont`, `data` (ThemeData, persisted via `dbThemeData` getter/setter) |
| `theme_entry.dart` | `ThemeEntry` | A single style entry (color or font) belonging to a `ThemeObject`, via `themeObject: ToOne<ThemeObject>` |
| `theme_object.dart` | `ThemeObject` | `@Deprecated('Use ThemeStruct instead')` -- legacy theme metadata wrapper; still present for migration, don't build new features on it |

### Supporting Entities

| File | Class | Purpose |
|------|-------|---------|
| `fcm_data.dart` | `FCMData` | Firebase project/API config (`projectID`, `storageBucket`, `apiKey`, `firebaseURL`, `clientID`, `applicationID`) -- persisted per device |
| `launch_at_startup.dart` | -- | **Not an ObjectBox entity.** Plain static utility class wrapping the `launch_at_startup` package plus Windows/Linux/Flatpak autostart shell integration (`enable()`, `disable()`, `shortcutPath`, `setup()`). Stores no data of its own |
| `klipy.dart` | -- | **Not a data model.** Placeholder (`const KLIPY_API_KEY = ""`) so native/desktop builds compile without the real key, which lives in the untracked web `html/klipy.dart` |

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
| `parsed_log_entry.dart` | Parsed structure of a single log file line |
| `server_details.dart` | Server version, OS, build info from /server/info endpoint |
| `server_update_info.dart` | Server update availability info |
| `text_entity_match.dart` | A matched text entity (phone, email, URL) from ML Kit |
| `theme_pair.dart` | Light + dark ThemeData pair for a named theme |

Rules: no Rx* fields, no DB annotations, no GetX. When an action needs to return structured data without an ObjectBox entity, create a model here.
