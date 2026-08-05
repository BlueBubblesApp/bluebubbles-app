# ios/ — iOS Native (Minimal Custom Code)

Custom Swift: `Runner/AppDelegate.swift` — standard Flutter app delegate (13 lines). Registers plugins only via `GeneratedPluginRegistrant`.

All iOS-specific Flutter behavior is plugin-driven. iOS-specific Dart code lives in:
- `lib/services/backend/java_dart_interop/` — method channel setup
- `lib/services/network/` — push notification registration

## Adding a Method Channel on iOS
1. Add the channel handler in `AppDelegate.swift` inside `application(_:didFinishLaunchingWithOptions:)`
2. Register the channel name matching `lib/services/backend/java_dart_interop/method_channel_service.dart`
