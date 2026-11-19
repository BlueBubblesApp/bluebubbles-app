# services/ui/ — UI State Services

All are GetX singletons. Shorthand getters live in `lib/services/services.dart`.

## Chat → `chat/CLAUDE.md`
- `chat/chats_service.dart` (`ChatsSvc`) — sorted chat list, unread count, `ChatState` map, active chat tracking; loads in batches of 100
- `chat/conversation_view_controller.dart` — state for the currently open conversation (text, attachments, reply, scroll position)

## Messages → `message/CLAUDE.md`
- `message/messages_service.dart` (`MessagesSvc`) — per-chat service tagged by GUID; owns `MessageState` map for granular widget reactivity. Per-message controller state now lives directly on `MessageState` (`lib/app/state/message_state.dart`) — the old `MessageWidgetController` was merged into it.

## Contacts
- `contact_service_v2.dart` (`ContactsSvcV2`) — desktop sync (requires server v42+); the only place that writes to the device address book (`setNativeContactPhoto`)
- `name_and_photo_sharing_service.dart` (`NameAndPhotoSharingSvc`) — Messages' "Share Name and Photo": whether to offer sharing yours, what participants shared with you, and what the user dismissed. Not a contacts service: it reads the server and hands any address book write to `ContactsSvcV2`

## Handles & Typing
- `handle_service.dart` — owns the `HandleState` map, mirrors `handle_state.dart` reactive fields
- `typing_indicator_service.dart` — typing indicator state per chat

## Other
- `theme/themes_service.dart` (`ThemeSvc`) — theme switching, custom theme management, preset themes
- `navigator/navigator_service.dart` (`NavigationSvc`) — GetX-based app routing; always use this over `Navigator.of(context)` directly
- `attachments_service.dart` — tracks file attachments in the composer + send progress state
- `unifiedpush.dart` — push notification provider abstraction (UnifiedPush protocol)
- `remote_library_cache.dart` — `RemoteLibraryCache<T>`, the shared base of the two library mirrors below: Rx state (`entries`, `cachedThumbnails`, `loaded`, `syncing`, `syncError`, `unavailableReason`), `library.json` + `thumbnails/` + `full/` under the service's own root, `load()`, shared-future `runSync()` (listing hook → missing thumbnails → prune), `cachedFullImage()`, `removeFromCache()`, `clearCache()`. Subclasses supply the listing, thumbnail fetch, sync error sentence and any extra index fields. The index records the server's iCloud account (`detected_icloud`); when the server reports a different one (switching servers), the cache is dropped. `clearRemoteLibraryCaches()` drops the in-memory copies of whichever services exist, without creating them; reset and "delete all messaging data" call it after `FilesystemSvc.deleteCacheDirectories()`, which removes both roots
- `genmoji_library_service.dart` (`GenmojiLibrarySvc`, lazy) — mirror of the server Mac's Genmoji library (v2). `<appDocDir>/genmoji/`: `library.json` (listing + ETag), `thumbnails/<id>.png` (320px, batch-fetched only when missing), `full/<id>.png` (512px send copy). `sync()` revalidates with `If-None-Match`, fetches new thumbnails, prunes files for removed Genmoji; `delete()` removes from the Mac (needs Private API) and the cache
- `sticker_library_service.dart` (`StickerLibrarySvc`, lazy) — mirror of the server Mac's sticker library (v2). `<appDocDir>/stickers/`: `library.json` (listing; the route has no ETag, so every sync re-reads it), `thumbnails/<id>` (fetched only when missing), `full/<id>` (send copy, fetched on first send). `sync()` refreshes and prunes files and recent tapbacks (`PrefsSvc.messaging.pruneStickerTapbacks`) for removed stickers, leaving tapbacks alone when the library is unavailable; `add()` uploads to the Mac (needs Private API) then syncs. `byIdentifier()` is a map lookup and `identifierOfImage()` (which library sticker a sent image is) compares only the full-size copies of the same file length; both indexes rebuild from `entries` whenever it changes. A listing entry it can't read (`LibrarySticker.tryFromMap`) is skipped, not fatal
- `cache/cache_service.dart` (`CacheSvc`) — registry of clearable in-memory caches plus per-level purge policies; `LifecycleService` purges on background and on memory pressure → `cache/CLAUDE.md`

## Key Separation Rule
`ChatState` / `MessageState` (in `lib/app/state/`) are what widgets **read**.
`ChatsService` / `MessagesService` call `updateXxxInternal()` on state — **widgets never write state directly**.
