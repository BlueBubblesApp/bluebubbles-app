/// Deprecated short-form service accessors.
///
/// These were the accessor names before services moved to the `XxxSvc` +
/// GetIt convention. They are kept as thin aliases so that code written
/// against the old names — long-lived branches, out-of-tree patches, and
/// downstream forks — keeps compiling across the rename instead of failing
/// at every call site.
///
/// This matters more than the rename's merge conflicts suggest: a textual
/// conflict is visible and gets resolved, but a file that merges *cleanly*
/// and then fails to compile is silent until build time, and there are far
/// more of those.
///
/// Nothing in this repo uses these. They cost one line each, and the file can
/// be deleted outright once downstream consumers have migrated.
///
/// Deliberately **not** aliased:
/// - `cs` — the old `ContactsService` was replaced by `ContactServiceV2`,
///   which has a different API. An alias would compile but silently change
///   behaviour, which is worse than a compile error.
/// - `ah`, `cm`, `inq`, `outq`, `fdb`, `upr` — those services no longer exist
///   in any form, so there is nothing to point at.
/// - `setup` — unchanged; still available under its original name.
library;

import 'package:bluebubbles/services/services.dart';

@Deprecated('Use SettingsSvc instead')
SettingsService get ss => SettingsSvc;

@Deprecated('Use ChatsSvc instead')
ChatsService get chats => ChatsSvc;

@Deprecated('Use HttpSvc instead')
HttpService get http => HttpSvc;

@Deprecated('Use NavigationSvc instead')
NavigatorService get ns => NavigationSvc;

@Deprecated('Use ThemeSvc instead')
ThemesService get ts => ThemeSvc;

@Deprecated('Use FilesystemSvc instead')
FilesystemService get fs => FilesystemSvc;

@Deprecated('Use LifecycleSvc instead')
LifecycleService get ls => LifecycleSvc;

@Deprecated('Use MethodChannelSvc instead')
MethodChannelService get mcs => MethodChannelSvc;

@Deprecated('Use NotificationsSvc instead')
NotificationsService get notif => NotificationsSvc;

@Deprecated('Use SyncSvc instead')
SyncService get sync => SyncSvc;

@Deprecated('Use AttachmentsSvc instead')
AttachmentsService get as => AttachmentsSvc;
