# BlueBubbles — Community Fork (v2.0.0+85)

> **This is an unofficial community fork** of [BlueBubblesApp/bluebubbles-app](https://github.com/BlueBubblesApp/bluebubbles-app) based on **v2.0.0+85 (beta 8)**. It adds two feature tracks and fixes several bugs found in that release. It is not affiliated with or endorsed by the BlueBubbles project.

---

## What This Fork Adds

### Feature 1: Per-Contact Do Not Disturb Bypass via Android Starred Contacts

The stock app adds the entire BlueBubbles notification channel to the DND override list — meaning *every* incoming message bypasses Do Not Disturb, which defeats the purpose of DND entirely.

This fork changes that. Instead of granting the whole app DND immunity, it uses Android's native **"Starred contacts can interrupt"** DND rule. Contacts you have marked as **Favorites** in your Android contacts app (the star in Google Contacts, the Favorites list in Samsung Contacts) can ring through DND. Everyone else respects it.

**How it works (technical summary):**

- The global `com.bluebubbles.new_messages` notification channel no longer calls `setBypassDnd(true)`.
- On each incoming message, Android's `ContactsContract` is queried for the sender's contact row. If the contact is starred (`STARRED = 1`), the notification's `Person` object is built with `setUri(lookupUri)` and `setImportant(true)`. Android's DND system sees this URI, verifies the contact is starred, and lets the notification through.
- Non-starred contacts get a `Person` with no URI and no importance flag — they respect DND normally.
- Legacy per-conversation notification channels (`bb-chat-*`) are cleaned up on first launch; they can otherwise linger in system notification settings.
- The feature is user-controlled via **Settings → Application Settings → Notification Settings → Override DND for Favorites** (default: off). When off, no contact lookup is performed and all contacts respect DND normally.

**Required Android setup:**

1. Enable **Override DND for Favorites** in the app under Settings → Application Settings → Notification Settings.
2. Open **Settings → Notifications → Do Not Disturb → Allowed during DND**.
3. Enable **"Starred contacts"** (label varies by Android version/manufacturer).
4. In your contacts app, star/favorite the contacts you want to reach you during DND.
5. Do **not** add BlueBubbles to the "Apps" override list — that would bypass DND for all messages again.

**Group chats:** DND bypass is triggered by the message sender, not the group. If the sender is starred, the notification breaks through.

---

### Feature 2: UnifiedPush / ntfy Reliability Improvements

Several latent bugs prevented push-delivered messages (via UnifiedPush providers such as ntfy) from being processed correctly, particularly in group chats and for messages with attachments.

**Root cause:** Android's Gson library parses JSON values into `JsonElement` subtypes (`JsonPrimitive`, `JsonArray`, `JsonObject`). When these were passed to the Dart side via Flutter's method channel, the channel delivered `Map<Object?, Object?>` rather than `Map<String, dynamic>`. Every `.cast<String, Object>()` call in the message deserialization path was an unsafe runtime cast that would silently fail or throw on mismatched types.

**Fixes applied:**

- **`UnifiedPushReceiver.kt`:** Replaced Gson's JSON tree model (`Map<String, JsonElement>`) with `HashMap<String, Any?>` using `ToNumberPolicy.LONG_OR_DOUBLE`, so numbers arrive as Kotlin `Long`/`Double` instead of `JsonPrimitive` wrappers. Full exception handling added; payload size logged for debugging.
- **`DartWorkManager.kt` / `DartWorker.kt`:** WorkManager input data is hard-capped at ~10 KB. Messages with attachments can exceed this, causing silent enqueue failures. The fork adds a file-spill mechanism: payloads under 9,000 bytes go inline; larger ones are written to a temp file in `cacheDir` and referenced by path (prefixed `@file:`). The worker reads and deletes the file on execution.
- **`lib/utils/deep_map_normalize.dart` (new):** A pure utility that recursively normalizes any `Map` or `List` from the platform channel into canonical `Map<String, dynamic>` / `List<dynamic>` types. Used as the entry point for all incoming method channel payloads.
- **All model `fromMap`/`fromJson` factories** (`Message`, `Chat`, `Handle`, `Attachment`, `AttributedBody`, `Run`, `MessageSummaryInfo`, `PayloadData`, `ServerPayload`): Replaced every `.cast<String, Object>()` with `asStringDynamicMapRequired()` from the normalize utility. Failures now throw a descriptive `FormatException` instead of silently producing wrong data.

---

### Feature 3: Reliable Handle Linking for Group Chat Notifications

In the original code, a notification for an incoming group message was silently dropped if the local participant list didn't include the sender's handle. This could happen when a new participant joined, when the app was first configured, or when a sync had not yet completed.

**Fixes applied:**

- **`incoming_message_handler.dart`:** New `_ensureMessageHandleLinked()` post-save repair pass. After saving a message, if `handleRelation` is still unset, it attempts four escalating lookups: global DB by ROWID → chat participants by ROWID → chat participants by address+service → global DB by address+service. Group chats always refresh their participant list from the server on each incoming message from another user.
- **`notifications_service.dart`:** New `resolveHandleForNotification()` function with a 7-step handle resolution chain. Notifications are no longer silently dropped when handle resolution fails — a fallback to the chat title is used instead, with a logged warning.
- **`chat_actions.dart`:** Handle lookup order corrected (embedded `handle` object checked before `handleId` DB query). Two participant-pool fallback lookups added. Participant-filter loop that dropped unmatched messages is now skipped entirely for group chats. When a new handle is resolved, it is immediately persisted to the chat's participant list.
- **`sync_actions.dart`:** Embedded `handle` maps inside message payloads are now extracted during the pre-processing pass and added to the `handlesByAddress` lookup, so bulk sync can resolve senders that were not previously seen.

**Additional fix in `message_state.dart`:** A null sender on an *incoming* message now shows `'Unknown'` instead of `'You'`, preventing falsely attributing unresolved incoming messages to the local user.

---

## Bug Fixes (Not Feature-Related)

### `SettingsHelper.kt` — SharedPreferences key prefix
Flutter's `shared_preferences` plugin stores all values under the prefix `flutter.` in the `FlutterSharedPreferences` file. `SettingsHelper.kt` had `PREFIX = ""`, so every settings read (server URL, auth key, API timeout, Private API flags, reaction action setting) silently returned the default value. This broke the native `LikeMessage` tapback feature: `hasServerUrl()` and `hasAuthKey()` always returned `false`, so the HTTP call was never made.

**Fixed:** `PREFIX = "flutter."`

### `Utils.kt` — Portrait image aspect ratio crash
`val aspectRatio = width / height` used integer division, which truncates to `0` for portrait images (e.g. `100 / 200 = 0`). `height = width / 0` then crashed at runtime. The landscape branch also had an inverted formula: `width = height / aspectRatio` (should be `height * aspectRatio` for a ratio < 1).

**Fixed:** float division, both branch formulas corrected.

### `method_channel_actions.dart` — Dead `channelId` parameter
`createIncomingMessageNotification()` sent a `channel_id` argument to Kotlin that was never read (Kotlin now uses the hardcoded `PARENT_CHANNEL_ID`). The parameter and call-site argument are removed.

### `messages_view.dart` — Infinite load-more loop
When a load-more request returned an empty list, `noMoreMessages` was not set immediately, allowing the scroll handler to fire again and request another empty page indefinitely.

**Fixed:** `noMoreMessages = true` when `newMessages.isEmpty`.

### `message.dart` / `chat_actions.dart` — Group message sender shown as "Unknown"
`Message.getHandle()` only checked the persisted `handleRelation` and a DB lookup — never the in-memory transient `handle` field populated from the push payload. So `toMap()` serialized `"handle": null`, `addMessageToChat` had no embedded handle object to work with, the handle relation was never set, and `notificationSenderName()` fell through to `return 'Unknown'`.

An additional wrinkle: the Mac can store the same phone number in two forms (e.g. `+15551234` and `15551234` as separate handle rows). A second rapid message from the same sender can arrive with the "alternate" ROWID that hasn't been synced locally. The exact `uniqueAddressAndService` query missed it.

**Fixed:**
- `Message.getHandle()`: checks the transient `handle` field before falling back to the DB lookup, so the embedded server payload survives serialization.
- `addMessageToChat`: after the exact `uniqueAddressAndService` lookup fails, tries the `+`/`−` prefix variant of the address. If the canonical handle (with ContactV2 linked) is found, it is used instead of creating an orphaned duplicate. When creating a truly new handle, `originalROWID` is set from the Mac ROWID carried in the `id` field.

### `chat_actions.dart` / `chat_interface.dart` / `chat.dart` — Messages missing in conversation view (spinner)
`getMessagesAsync` determined group vs. 1:1 exclusively from `participants.length > 1`. If the in-memory `Chat` object had a stale or empty handles list at the time the conversation was opened (e.g., race with the participant sync from the push handler), the filter treated the chat as a 1:1 and dropped incoming messages whose sender handle was not in the short participant list.

**Fixed:** `chatStyle` is now passed through `Chat.getMessagesAsync` → `ChatInterface.getMessagesAsync` → `ChatActions.getMessagesAsync`. The group-chat gate becomes `chatStyle == 43 || participants.length > 1`, where `43` is the iMessage group style constant.

### `startup_tasks.dart` — Missing `TypingIndicatorService` registration
`TypingIndicatorService` was not registered during app startup, causing a `GetIt` lookup failure if any code path tried to use it before explicit registration elsewhere.

**Fixed:** Explicit registration added to the startup task sequence.

---

## Changed Files

| File | Change type | Description |
|---|---|---|
| `android/.../utils/ContactNotificationHelper.kt` | **New** | Contacts DB query + `Person` builder with starred-contact DND logic |
| `lib/utils/deep_map_normalize.dart` | **New** | Platform channel type normalization utility |
| `android/.../services/notifications/NotificationChannelHandler.kt` | Modified | Remove `setBypassDnd(true)`; clean up legacy `bb-chat-*` channels |
| `android/.../services/notifications/CreateIncomingMessageNotification.kt` | Modified | Wire `nativeContactId`; fix channel to `PARENT_CHANNEL_ID`; add try/catch; conditional DND bypass gated on `dnd_favorites_override` method channel arg |
| `android/.../services/system/PushShareTargetsHandler.kt` | Modified | Add `ContactInfo` overload to avoid duplicate contacts DB query |
| `android/.../services/system/OpenConversationNotificationSettingsHandler.kt` | Modified | Remove per-conversation channel creation; open settings on global channel |
| `android/.../UnifiedPushReceiver.kt` | Modified | Fix Gson type strategy; add exception handling and size logging |
| `android/.../services/backend_ui_interop/DartWorkManager.kt` | Modified | Add file-spill for WorkManager payloads > 9 KB |
| `android/.../services/backend_ui_interop/DartWorker.kt` | Modified | Read and delete spilled payload files |
| `android/.../utils/SettingsHelper.kt` | Modified | Fix `PREFIX = ""` → `"flutter."` |
| `android/.../utils/Utils.kt` | Modified | Fix portrait image aspect ratio integer division and formula |
| `lib/services/backend/notifications/notifications_service.dart` | Modified | `nativeContactId` wiring; 7-step handle resolution; drop `channelId` param; pass `dndFavoritesOverride` setting to notification handler |
| `lib/services/network/method_channel_actions.dart` | Modified | Add `nativeContactId`; remove `channelId`; add `dndFavoritesOverride` param forwarded to Kotlin via method channel |
| `lib/services/backend/java_dart_interop/method_channel_handlers.dart` | Modified | Normalize incoming payloads; per-step error logging (`BB_MAP_FIX_V3`) |
| `lib/services/backend/java_dart_interop/method_channel_service.dart` | Modified | Normalize method channel arguments via utility |
| `lib/services/backend/incoming_message_handler.dart` | Modified | Post-save handle repair; group chat participant refresh |
| `lib/services/backend/actions/chat_actions.dart` | Modified | Handle lookup order fix; participant fallbacks; group message filter skip |
| `lib/services/backend/actions/sync_actions.dart` | Modified | Extract embedded handles during bulk sync pre-processing |
| `lib/database/global/server_payload.dart` | Modified | `asStringDynamicMapRequired` + `deepNormalizeJson` in `data` setter |
| `lib/database/global/attributed_body.dart` | Modified | Replace `.cast` with `asStringDynamicMapRequired` throughout |
| `lib/database/global/message_summary_info.dart` | Modified | Replace `.cast` with `asStringDynamicMapRequired` throughout |
| `lib/database/global/payload_data.dart` | Modified | Replace `.cast` with `asStringDynamicMapRequired` throughout |
| `lib/database/io/message.dart` | Modified | Normalize all nested maps; fix `metadata` nullability; `getHandle()` checks transient `handle` field before DB lookup |
| `lib/database/io/chat.dart` | Modified | Replace `.cast` on `lastMessage` and participants; pass `chatStyle` to `getMessagesAsync` interface |
| `lib/database/io/handle.dart` | Modified | Add normalization step to `fromMap` |
| `lib/database/io/attachment.dart` | Modified | Normalize `metadata` and `exif`; fix `dbMetadata` setter cast |
| `lib/app/state/message_state.dart` | Modified | Separate `isFromMe` and null-sender display name handling |
| `lib/app/layouts/conversation_view/pages/messages_view.dart` | Modified | Set `noMoreMessages` on empty load-more response |
| `lib/services/backend/actions/chat_actions.dart` | Modified | Handle lookup order fix; participant fallbacks; group message filter skip; normalized address fallback in `addMessageToChat`; `chatStyle` gate in `getMessagesAsync` |
| `lib/services/backend/interfaces/chat_interface.dart` | Modified | Thread `chatStyle` through `getMessagesAsync` |
| `lib/database/global/settings.dart` | Modified | Add `dndFavoritesOverride` `RxBool` field with `toMap`/`fromMap` persistence |
| `lib/app/layouts/settings/pages/system/notification_panel.dart` | Modified | Add "Override DND for Favorites" toggle before "Send Notifications on Chat List" |
| `lib/app/layouts/settings/widgets/search/settings_items_list.dart` | Modified | Add "Override DND for Favorites" to notification section search tags |
| `lib/helpers/backend/startup_tasks.dart` | Modified | Register `TypingIndicatorService` at startup |

---

## Building

This is a Flutter application. Requirements:

- Flutter SDK (see `.flutter-version` or `pubspec.yaml` for the required version)
- Android SDK with NDK 27.0, target SDK 35, Java/Kotlin 21
- A connected Android device or emulator

```bash
flutter pub get
flutter run --release   # or: flutter build apk --release
```

No new dependencies were added. All changes are within the existing dependency graph.

---

## Known Limitations

- **Dart-initiated shortcuts** (`chats_service.dart` startup push): The `pushShareTarget` call at startup does not pass `nativeContactId`, so conversation shortcuts in the Android Share Sheet will not carry contact URI information. This does not affect the DND bypass, which is driven by the notification itself.
- **ntfy startup messages**: Messages delivered via UnifiedPush while the Dart engine is not running go through `DartWorkManager`. If a spilled payload file is deleted by the OS before the worker runs, that message will be lost. The spill file lives in `cacheDir`, which Android can evict under memory pressure.
- **Group chat DND**: The DND bypass key is the *sender's* starred status, not the group itself. You cannot star a group to break through DND; individual participants must be starred.
- **SMS group edge case**: For SMS/MMS group chats whose style value is not `43` (iMessage group constant), the message filter in `getMessagesAsync` falls back to `participants.length > 1`. If the in-memory participant list is stale and shows only one member at conversation-open time, messages from unrecognized senders may be filtered. iMessage groups (style `43`) are unaffected.
- **`dndFavoritesOverride` setting storage**: Flutter v2.5+ uses `SharedPreferencesAsync` (Android DataStore) as its storage backend after migration. The Kotlin `SettingsHelper` reads from legacy `FlutterSharedPreferences` XML which DataStore does not write to. For this reason, the DND toggle value is passed directly from Dart to the Kotlin notification handler via method channel argument rather than being read from storage on the Kotlin side. Other settings in `SettingsHelper` that were persisted before the DataStore migration remain readable because they exist in both storage locations.

---

# BlueBubbles

BlueBubbles is an open-source, cross-platform ecosystem of apps that brings iMessage to Android, Windows, Linux, and the web. Send messages, media, reactions, and more — all from your non-Apple devices.

> **Note:** BlueBubbles requires a Mac running the BlueBubbles Server and an active Apple ID. A macOS virtual machine on Windows or Linux works as well.

---

## Features

### Core Messaging

- Send and receive iMessages, SMS, and MMS
- View and send tapbacks, stickers, and emoji reactions
- Full support for read receipts and delivered timestamps
- Threaded replies (requires macOS 11+)
- Create new chats and group conversations
- Mute or archive conversations
- Share your location

### Customization

- Robust theming engine with light and dark mode support
- Choose between iOS, Material, or Samsung-style UI skins
- Extensive settings to personalize your experience
- Full cross-platform support — message from Android, Linux, Windows, and macOS

### Private API Features

With optional Private API setup, you can unlock deeper iMessage integration:

- Send and receive typing indicators in real time
- Send tapbacks, subject lines, message effects, and replies
- Automatically mark chats as read on your Mac
- Rename group chats and manage participants

> Private API features require additional configuration. See the [Private API setup guide](https://docs.bluebubbles.app/helper-bundle/installation) for instructions.

---

## Screenshots

<table>
  <tr>
    <td align="center">Chat List</td>
    <td align="center">Message View</td>
    <td align="center">Private API Features</td>
  </tr>
  <tr>
    <td><img src="https://raw.githubusercontent.com/BlueBubblesApp/bluebubbles-app/master/screenshots/Samsung%20Galaxy%20S10%2B%20Prism%20Black%20-%20imessage_framed.png" width=270></td>
    <td><img src="https://raw.githubusercontent.com/BlueBubblesApp/bluebubbles-app/master/screenshots/Samsung%20Galaxy%20S10+%20Prism%20Black%20-%20messaging_framed.png" width=270></td>
    <td><img src="https://raw.githubusercontent.com/BlueBubblesApp/bluebubbles-app/master/screenshots/Samsung%20Galaxy%20S10+%20Prism%20Black%20-%20privateAPI_framed.png" width=270></td>
  </tr>
</table>

---

## Getting Started

1. Download and install the **BlueBubbles Server** on your Mac: [Server releases](https://github.com/BlueBubblesApp/BlueBubbles-Server/releases)
2. Download the **BlueBubbles client app** for your platform: [Client releases](https://github.com/BlueBubblesApp/blueBubbles-app/releases)
3. Follow the [installation guide](https://bluebubbles.app/install/) to connect everything together

The client is also available on:

- [Google Play](https://play.google.com/store/apps/details?id=com.bluebubbles.messaging)
- [Snap Store](https://snapcraft.io/bluebubbles)
- [Flathub](https://flathub.org/apps/app.bluebubbles.BlueBubbles)
- [Microsoft Store](https://www.microsoft.com/store/productId/9P3XF8KJ0LSM)

---

## Community

We have an active and welcoming community. Come say hello, get help, or follow along with development:

- **Discord:** [discord.gg/6nrGRHT](https://discord.gg/6nrGRHT) — the best place for support, feedback, and general chat
- **Reddit:** [r/BlueBubbles](https://www.reddit.com/r/BlueBubbles/)
- **Website:** [bluebubbles.app](https://bluebubbles.app)
- **Documentation:** [docs.bluebubbles.app](https://docs.bluebubbles.app)
- **FAQ:** [bluebubbles.app/faq](https://bluebubbles.app/faq)

---

## Contributing

Contributions are always welcome. Whether it's fixing a bug, improving performance, or adding a new feature — we appreciate the help.

Before getting started, please read [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions and code conventions.

To report a bug or request a feature, [open an issue on GitHub](https://github.com/BlueBubblesApp/bluebubbles-app/issues). Please search before opening a new ticket.

---

## Donating

BlueBubbles is free and open-source, maintained entirely by volunteers. If you find the project valuable, consider supporting its development:

[bluebubbles.app/donate](https://bluebubbles.app/donate)

---

## License

BlueBubbles is released under the terms of the [LICENSE](LICENSE) file in this repository.
