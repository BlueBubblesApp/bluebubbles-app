# services/backend/notifications/ — Local Notifications

`notifications_service.dart` — dispatches local notifications across all platforms.
`desktop_notification.dart` — `DesktopNotifications` adapter over `flutter_local_notifications` for Windows/Linux.
`toast_button_images.dart` — `ToastButtonImages`: draws tapback/emoji action buttons as PNGs (cached on disk, keyed
by `_version`) so Windows toasts show the app's glyphs; the desktop settings preview draws the same images. It borrows
`TapbackIcon.asset` from the message UI for the SVG paths.

The desktop settings' toast preview colors (`ToastPreviewTheme`, formerly `WindowsToastTheme`) and preview widgets live
with the panel in `lib/app/layouts/settings/pages/desktop/widgets/`, not here.

## Notification Channels
| Channel | Purpose |
|---------|---------|
| `NEW_MESSAGE` | Incoming message notification |
| `ERROR` | App error alerts |
| `REMINDER` | Scheduled message reminders |
| `FACETIME` | Incoming FaceTime call alert |
| `FOREGROUND_SERVICE` | Android persistent foreground service notification |

## Platform Implementations
| Platform | Library |
|----------|---------|
| Android / iOS | `flutter_local_notifications` |
| Desktop (Windows, Linux) | `flutter_local_notifications` via the `DesktopNotifications` adapter (`desktop_notification.dart`) |
| Web | Browser Notification API |

## Key Behaviors
- Message preview display (text, sender name, avatar)
- Group notifications (grouped by chat on Android)
- Toast management via `PendingToastItem`
- FaceTime incoming call with accept/decline actions
- Desktop FaceTime toasts clear themselves if the call's end never arrives: after `faceTimeToastTimeout` (2 min)
  for calls with a UUID, `legacyFaceTimeToastTimeout` (30 s) for calls without one (server FaceTime calling off)

## Triggering Notifications
Called from `IncomingMessageHandler` when a new message arrives, and from `ScheduledMessage` reminders.
Don't call directly from UI code — route through the handler/service layer.
