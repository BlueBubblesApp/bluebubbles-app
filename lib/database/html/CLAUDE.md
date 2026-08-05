# database/html/ — Web Platform Stubs (Deprecated)

**Web support is deprecated. Do not extend these files.**

These are stub implementations of the ObjectBox entity classes that compile for the web platform, where ObjectBox is unavailable. They mirror the API surface of `lib/database/io/` but hold no data and perform no actual persistence.

All 12 files here (`chat.dart`, `message.dart`, `attachment.dart`, `handle.dart`, `theme.dart`, `fcm_data.dart`, `launch_at_startup.dart`, `media_kit.dart`, `network_tools.dart`, `objectbox.dart`, `theme_entry.dart`, `theme_object.dart`) exist solely so the codebase compiles for web without ObjectBox-specific imports. They should be treated as read-only.

If you need to modify an entity (e.g. add a field to `Chat`), edit `lib/database/io/chat.dart` and the shared DTO in `lib/database/global/` — not this directory.

Conditional imports in `lib/database/models.dart` route to `io/` or `html/` at compile time.
