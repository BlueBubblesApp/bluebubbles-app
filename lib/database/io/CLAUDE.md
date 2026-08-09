# database/io/ — ObjectBox Entities (Native & Desktop)

Not used on web — `database/html/` provides web stubs.
After any `@Entity` annotation change: **`dart run build_runner build`**

## Entities

| File | Key Fields | Relations |
|------|-----------|-----------|
| `chat.dart` | guid (unique+indexed), chatIdentifier, isArchived, isPinned, muteType, displayName | → dbLatestMessage (ToOne), → messages (ToMany backlink), → handles (ToMany) / participants (transient mirror) |
| `message.dart` | guid (unique+indexed, nullable), text, dateCreated (indexed), isFromMe, error, hasDdResults | → chat (ToOne), → handleRelation (ToOne, replacing legacy embedded `handle` field), → dbAttachments (ToMany backlink), → associatedMessages (plain list) |
| `attachment.dart` | guid (unique), uti, mimeType, transferName, totalBytes | → message (ToOne; owning side of `Message.dbAttachments` backlink) |
| `handle.dart` | uniqueAddressAndService (unique -- synthesized `"$address/$service"`), address, service (iMessage/SMS), country | ↔ contact_v2 (ToMany, `@Backlink('handles')`) |
| `contact_v2.dart` | displayName, nativeContactId (unique), avatarPath | ↔ handles (ToMany N:M) |

| `theme.dart` (`ThemeStruct`) | name (unique), serialized FlutterThemeData, googleFont, gradientBg | — |
| `theme_entry.dart` | style entry (color or font) | → themeObject (ToOne<ThemeObject>) |
| `theme_object.dart` | `@Deprecated('Use ThemeStruct instead')` legacy theme metadata wrapper | — |
| `fcm_data.dart` (`FCMData`) | FCM tokens and Firebase auth credentials | — |
| `launch_at_startup.dart` | not an `@Entity` -- plain static autostart helper (desktop only), no persisted fields | — |

## Rules
- Primary key: always `int? id` (nullable; ObjectBox assigns on first `put`)
- Unique business key: `@Unique()` + `@Index(type: IndexType.value)`
- Adding a field to an existing entity: include `@Property(uid: ...)` to avoid schema conflicts
- Non-persisted / `Rx*` fields: must be `@Transient()` — see `frontend.md`
- Pure data entities (like `contact_v2.dart`) should have no `Rx*` fields at all

## Platform Guard
```dart
if (kIsWeb) return; // always guard before any Database.* call
```

## Relationships
- ToMany updates: `.clear()` → `.addAll()` → `.applyToDb()`
- ToOne updates: set `.target = object` then `put()` the owning entity
