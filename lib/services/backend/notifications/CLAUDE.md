# services/backend/notifications/ — Local Notifications

`notifications_service.dart` — dispatches local notifications across all platforms.

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

## Triggering Notifications
Called from `IncomingMessageHandler` when a new message arrives, and from `ScheduledMessage` reminders.
Don't call directly from UI code — route through the handler/service layer.
