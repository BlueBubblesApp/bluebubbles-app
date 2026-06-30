import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/services/network/method_channel_actions.dart';
import 'package:bluebubbles/services/backend/java_dart_interop/method_channel_handlers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/deep_map_normalize.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
MethodChannelService get MethodChannelSvc => GetIt.I<MethodChannelService>();

class MethodChannelService implements MethodChannelServiceDelegate {
  late final MethodChannel channel;
  late final MethodChannelActions actions;
  late final MethodChannelHandlers _handlers;

  @override
  bool headless = false;
  bool isBubble = false;

  // music theme
  @override
  bool isRunning = false;
  @override
  Uint8List? previousArt;

  @override
  bool get shouldIgnoreMessage {
    if (headless) return false;
    final hasLifecycle = GetIt.I.isRegistered<LifecycleService>();
    final hasSettings = GetIt.I.isRegistered<SettingsService>();
    if (!hasLifecycle || !hasSettings) return false;
    return !LifecycleSvc.isAlive && SettingsSvc.settings.keepAppAlive.value;
  }

  Future<void> init({bool headless = false, bool isBubble = false, BinaryMessenger? binaryMessenger}) async {
    if (kIsWeb || kIsDesktop) return;
    if (binaryMessenger == null) {
      WidgetsFlutterBinding.ensureInitialized();
    }
    Logger.debug("Initializing MethodChannelService${headless ? " in headless mode" : ""}");

    this.headless = headless;
    this.isBubble = isBubble;

    channel = MethodChannel('com.bluebubbles.messaging', const StandardMethodCodec(), binaryMessenger);
    actions = MethodChannelActions(this);
    _handlers = MethodChannelHandlers(this);

    // Only set a method call handler on direct-engine connections. Isolates
    // using BackgroundIsolateBinaryMessenger should not own a channel handler.
    if (binaryMessenger == null) {
      channel.setMethodCallHandler(_callHandler);
      unawaited(actions.signalReady());
    }

    if (!kIsWeb && !kIsDesktop && !headless) {
      try {
        if (SettingsSvc.settings.colorsFromMedia.value) {
          await actions.startNotificationListener();
        }
        if (!this.isBubble) {
          BackgroundIsolate.initialize();
        }
        // chromeOS = await mcs().invokeMethod("check-chromeos") ?? false;
      } catch (_) {}
    }

    // Only create notification channels when running on the main engine connection.
    // The GlobalIsolate passes a BackgroundIsolateBinaryMessenger whose reply ports are
    // invalidated by concurrent isolate work, causing a fatal SIGABRT. The DartWorker
    // and the main isolate both pass null (direct engine), so they are safe to call this.
    if (binaryMessenger == null && !headless) unawaited(createAllNotificationChannels());

    Logger.debug("MethodChannelService initialized");
  }

  Future<bool> _callHandler(MethodCall call) async {
    final Map<String, dynamic>? arguments = normalizeMethodChannelArguments(call.arguments);

    // ONLY RETURN Future.value or Future.error
    // Future.value(false) will have the engine retry the call
    // Future.value(true) will have the engine stop trying to call the method

    return _handlers.handle(call, arguments);
  }

  Future<dynamic> invokeMethod(String method, [dynamic arguments]) async {
    if (kIsWeb || kIsDesktop) return;
    Logger.info("Sending method $method to Kotlin");
    return await channel.invokeMethod(method, arguments);
  }

  /// Not in the NotificationService to avoid circular dependency.
  /// The method channel service handles kotlin messages, which may
  /// invoke actions that use notifications (i.e. new-message events).
  Future<void> createAllNotificationChannels() async {
    await actions.createNotificationChannel(
      channelId: NotificationsService.NEW_MESSAGE_CHANNEL,
      channelName: "New Messages",
      channelDescription: "Displays all received new messages",
    );
    await actions.createNotificationChannel(
      channelId: NotificationsService.ERROR_CHANNEL,
      channelName: "Errors",
      channelDescription: "Displays message send failures, connection failures, and more",
    );
    await actions.createNotificationChannel(
      channelId: NotificationsService.REMINDER_CHANNEL,
      channelName: "Message Reminders",
      channelDescription: "Displays message reminders set through the app",
    );
    await actions.createNotificationChannel(
      channelId: NotificationsService.FACETIME_CHANNEL,
      channelName: "Incoming FaceTimes",
      channelDescription: "Displays incoming FaceTimes detected by the server",
    );
    await actions.createNotificationChannel(
      channelId: NotificationsService.FOREGROUND_SERVICE_CHANNEL,
      channelName: "Foreground Service",
      channelDescription:
          "Allows BlueBubbles to stay open in the background for notifications if FCM is not being used",
    );
  }
}
