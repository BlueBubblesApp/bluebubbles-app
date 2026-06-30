import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/settings/pages/scheduling/scheduled_messages_panel.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/ui/facetime_helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/models/models.dart' show HandleLookupKey;
import 'package:bluebubbles/services/backend/interfaces/contact_v2_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:get/get.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart';
import 'package:synchronized/synchronized.dart';
import 'package:timezone/timezone.dart';
import 'package:universal_html/html.dart' hide File, Platform, Navigator;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
NotificationsService get NotificationsSvc => GetIt.I<NotificationsService>();

/// Android Contacts row ID for linking notifications to system DND starred-contact rules.
String? nativeContactIdForHandle(Handle? handle) {
  if (handle == null) return null;

  ContactV2? contact = handle.contactsV2.where((c) => c.isNative).firstOrNull;
  contact ??= handle.contactsV2.firstOrNull;
  if (contact == null) return null;

  final id = contact.nativeContactId;
  if (id.isEmpty || int.tryParse(id) == null) return null;
  return id;
}

Future<String?> nativeContactIdForMessage(Message message) async {
  final handle = message.handleRelation.target;
  final fromHandle = nativeContactIdForHandle(handle);
  if (fromHandle != null) return fromHandle;

  final address = handle?.address;
  if (address == null || address.isEmpty) return null;

  final contact = await ContactV2Interface.getContactByAddress(address: address);
  if (contact == null) return null;
  final id = contact.nativeContactId;
  if (id.isEmpty || int.tryParse(id) == null) return null;
  return id;
}

/// Incoming pushes can arrive before ObjectBox ToOne links are hydrated on the
/// in-memory [Message]. Reload and fall back to chat participants so attachment
/// notifications are not dropped.
String notificationSenderName(Message message, Chat chat) {
  if (message.handleRelation.hasValue) {
    return message.handleRelation.target!.displayName;
  }
  if (message.handle != null) {
    return message.handle!.displayName;
  }
  if (message.handleId != null && message.handleId! > 0) {
    for (final h in chat.handles) {
      if (h.originalROWID == message.handleId) return h.displayName;
    }
    final global = Handle.findOne(originalROWID: message.handleId);
    if (global != null) return global.displayName;
  }
  return 'Unknown';
}

Message resolveHandleForNotification(Message message, Chat chat) {
  Message m = message;

  if (!m.handleRelation.hasValue && m.guid != null) {
    final reloaded = Message.findOne(guid: m.guid);
    if (reloaded != null) {
      m = reloaded;
    }
  }

  if (!m.handleRelation.hasValue && m.handleId != null && m.handleId! > 0) {
    final handle = Handle.findOne(originalROWID: m.handleId);
    if (handle != null) {
      m.handleRelation.target = handle;
      return m;
    }
  }

  if (!m.handleRelation.hasValue && m.handle != null) {
    final handle = Handle.findOne(
          addressAndService: HandleLookupKey(m.handle!.address, m.handle!.service),
        ) ??
        m.handle;
    if (handle != null) {
      m.handleRelation.target = handle;
      return m;
    }
  }

  final participantPool = chat.handles.isNotEmpty ? chat.handles.toList() : chat.participants;
  if (!m.handleRelation.hasValue && m.handleId != null && participantPool.isNotEmpty) {
    final participant = participantPool.cast<Handle?>().firstWhereOrNull(
          (h) => h?.originalROWID == m.handleId,
        );
    if (participant != null) {
      m.handleRelation.target = participant;
      return m;
    }
  }

  if (!m.handleRelation.hasValue && chat.isGroup && m.handle != null && participantPool.isNotEmpty) {
    final byAddress = participantPool.cast<Handle?>().firstWhereOrNull(
          (h) => h?.address == m.handle!.address && h?.service == m.handle!.service,
        );
    if (byAddress != null) {
      m.handleRelation.target = byAddress;
      return m;
    }
  }

  if (!m.handleRelation.hasValue && !chat.isGroup && chat.participants.isNotEmpty) {
    m.handleRelation.target = chat.participants.first;
  }

  return m;
}

class PendingToastItem {
  final String? sender;
  final String text;
  final bool isReaction;
  final bool isGroupEvent;

  String get senderText => sender == null ? text : "$sender: $text";

  PendingToastItem({required this.sender, required this.text, required this.isReaction, required this.isGroupEvent});
}

class NotificationsService {
  static const String NEW_MESSAGE_CHANNEL = "com.bluebubbles.new_messages";
  static const String ERROR_CHANNEL = "com.bluebubbles.errors";
  static const String REMINDER_CHANNEL = "com.bluebubbles.reminders";
  static const String FACETIME_CHANNEL = "com.bluebubbles.incoming_facetimes";
  static const String FOREGROUND_SERVICE_CHANNEL = "com.bluebubbles.foreground_service";

  static const String NEW_MESSAGE_TAG = "com.bluebubbles.messaging.NEW_MESSAGE_NOTIFICATION";
  static const String NEW_FACETIME_TAG = "com.bluebubbles.messaging.NEW_FACETIME_NOTIFICATION";

  final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();
  StreamSubscription? countSub;
  int currentCount = 0;

  bool headless = false;

  /// For desktop use only
  static LocalNotification? failedToast;
  static LocalNotification? aliasesToast;
  static Map<String, LocalNotification> facetimeNotifications = {};
  static Map<String, LocalNotification> activeToasts = {};
  static Map<String, Timer> debounceTimers = {};
  static Map<String, List<PendingToastItem>> pendingMessages = {};
  static final Lock _lock = Lock();
  static Player? _desktopNotificationPlayer;

  static const int maxLines = 4;
  static const int charsPerLineEst = 40;

  bool get hideContent => SettingsSvc.settings.hideTextPreviews.value;

  Future<void> init({bool headless = false}) async {
    this.headless = headless;
    if (!kIsWeb && !kIsDesktop && !headless) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('ic_stat_icon');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await flnp.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse? response) {
            if (response?.payload != null) {
              if (GetIt.I.isRegistered<IntentsService>()) {
                IntentsSvc.openChat(response!.payload);
              } else {
                Logger.warn('IntentsService not registered, cannot open chat from notification tap');
              }
            }
          });
      final details = await flnp.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp && details.notificationResponse?.payload != null) {
        if (GetIt.I.isRegistered<IntentsService>()) {
          IntentsSvc.openChat(details.notificationResponse!.payload!);
        } else {
          Logger.warn('IntentsService not registered, cannot process notification launch payload');
        }
      }
    }
  }

  void close() {
    countSub?.cancel();
  }

  Future<void> createReminder(Chat? chat, Message? message, DateTime time,
      {String? chatTitle, String? messageText}) async {
    await flnp.zonedSchedule(
      id: Random().nextInt(9998) + 50000,
      title: chatTitle ?? 'Reminder: ${chat!.getTitle()}',
      body: messageText ?? (hideContent ? "iMessage" : message!.getNotificationText()),
      scheduledDate: TZDateTime.from(time, local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          REMINDER_CHANNEL,
          'Reminders',
          channelDescription: 'Message reminder notifications',
          priority: Priority.max,
          importance: Importance.max,
          color: HexColor("4990de"),
        ),
      ),
      payload: "${time.millisecondsSinceEpoch}",
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> createNotification(Chat chat, Message message) async {
    if (GetIt.I.isRegistered<LifecycleService>()) {
      await GetIt.I.isReady<LifecycleService>();
    }

    if (chat.shouldMuteNotification(message) || message.isFromMe!) return;
    final isGroup = chat.isGroup;
    final guid = chat.guid;
    final contactName = notificationSenderName(message, chat);
    final title = isGroup ? chat.getTitle() : contactName;
    final text = hideContent ? "iMessage" : message.getNotificationText();
    final isReaction = !isNullOrEmpty(message.associatedMessageGuid);

    if (kIsWeb && Notification.permission == "granted") {
      final chatIcon = await avatarAsBytes(chat: chat, quality: 256);
      final notif =
          Notification(title, body: text, icon: "data:image/png;base64,${base64Encode(chatIcon)}", tag: message.guid);
      notif.onClick.listen((event) async {
        await IntentsSvc.openChat(guid);
      });
    } else if (kIsDesktop) {
      // Avatar loading is deferred to _buildAndShowToast — don't load it here.
      _lock.synchronized(
          () => showDesktopNotif(text, chat, title, contactName, message, isReaction, message.isGroupEvent));
    } else {
      if (message.guid != null && message.dateCreated != null) {
        if (!GetIt.I.isRegistered<MethodChannelService>()) {
          Logger.warn('MethodChannelService not registered; skipping incoming message notification');
          return;
        }

        final personIcon = (await rootBundle.load("assets/images/person64.png")).buffer.asUint8List();
        Uint8List chatIcon = await avatarAsBytes(chat: chat, quality: 256);
        final isFromMe = message.isFromMe ?? false;
        Uint8List contactIcon = isFromMe
            ? personIcon
            : await avatarAsBytes(
                participantsOverride: !chat.isGroup
                    ? null
                    : chat.handles.where((e) => e.address == message.handleRelation.target?.address).toList(),
                chat: chat,
                quality: 256);
        if (chatIcon.isEmpty) chatIcon = personIcon;
        if (contactIcon.isEmpty) contactIcon = personIcon;

        // Determine if reaction action should be shown (only if Private API is enabled & not a reaction message)
        final bool showReactionAction = SettingsSvc.settings.enablePrivateAPI.value &&
            SettingsSvc.settings.notificationReactionAction.value &&
            message.associatedMessageGuid == null;
        final String reactionType = SettingsSvc.settings.notificationReactionActionType.value;
        String? nativeContactId;
        try {
          nativeContactId = await nativeContactIdForMessage(message);
        } catch (e, s) {
          Logger.warn(
            'Contact lookup failed for notification; continuing without contact link',
            tag: 'NotificationsService',
            error: e,
            trace: s,
          );
        }

        await GetIt.I.isReady<MethodChannelService>();
        await MethodChannelSvc.actions.createIncomingMessageNotification(
          chatId: chat.id,
          chatGuid: guid,
          chatIsGroup: isGroup,
          chatTitle: title,
          chatIcon: isGroup ? chatIcon : contactIcon,
          contactName: contactName,
          contactAvatar: contactIcon,
          nativeContactId: nativeContactId,
          messageGuid: message.guid!,
          messageText: text,
          messageDate: message.dateCreated!.millisecondsSinceEpoch,
          messageIsFromMe: false,
          showReactionAction: showReactionAction,
          reactionType: reactionType,
          dndFavoritesOverride: SettingsSvc.settings.dndFavoritesOverride.value,
        );
      }
    }
  }

  Future<void> tryCreateNewMessageNotification(Message message, Chat chat) async {
    if (message.isFromMe!) return;

    message = resolveHandleForNotification(message, chat);
    if (!message.handleRelation.hasValue) {
      Logger.warn(
        'Handle relation not resolved for ${message.guid}; posting notification with chat fallback',
        tag: 'NotificationsService',
      );
    }
    if (message.isKeptAudio) return;
    if (chat.shouldMuteNotification(message)) return;
    if (!headless && LifecycleSvc.isAlive) {
      if (ChatsSvc.isChatActive(chat.guid)) return;
      if (ChatsSvc.activeChat == null &&
          Get.rawRoute?.settings.name == "/" &&
          !SettingsSvc.settings.notifyOnChatList.value) {
        return;
      }
    }

    await createNotification(chat, message);
  }

  Future<void> createIncomingFaceTimeNotification(
      String? callUuid, String caller, Uint8List? chatIcon, bool isAudio) async {
    // Set some notification defaults
    String title = caller;
    String text = "${callUuid == null ? "Incoming" : "Answer"} FaceTime ${isAudio ? 'Audio' : 'Video'} Call";
    chatIcon ??= (await rootBundle.load("assets/images/person64.png")).buffer.asUint8List();

    if (kIsWeb && Notification.permission == "granted") {
      final notif =
          Notification(title, body: text, icon: "data:image/png;base64,${base64Encode(chatIcon)}", tag: callUuid);
      if (callUuid != null) {
        notif.onClick.listen((event) async {
          await IntentsSvc.answerFaceTime(callUuid);
        });
      }
    } else if (kIsDesktop) {
      _lock.synchronized(() async => await showPersistentDesktopFaceTimeNotif(callUuid, caller, chatIcon, isAudio));
    } else {
      final numeric = callUuid?.numericOnly();
      await MethodChannelSvc.actions.createIncomingFaceTimeNotification(
        channelId: FACETIME_CHANNEL,
        notificationId:
            numeric != null ? int.parse(numeric.substring(0, min(8, numeric.length))) : Random().nextInt(9998) + 1,
        title: title,
        body: text,
        callerAvatar: chatIcon,
        caller: caller,
        callUuid: callUuid,
      );
    }
  }

  Future<void> clearFaceTimeNotification(String callUuid) async {
    if (kIsDesktop) {
      await clearDesktopFaceTimeNotif(callUuid);
    } else if (!kIsWeb) {
      final numeric = callUuid.numericOnly();
      MethodChannelSvc.actions.deleteNotification(
        notificationId: int.parse(numeric.substring(0, min(8, numeric.length))),
        tag: NEW_FACETIME_TAG,
      );
    }
  }

  Future<void> showPersistentDesktopFaceTimeNotif(
      String? callUuid, String caller, Uint8List? avatar, bool isAudio) async {
    List<String> actions = ["Answer", "Ignore"];
    List<LocalNotificationAction> nActions = actions.map((String a) => LocalNotificationAction(text: a)).toList();
    LocalNotification? toast;
    String? path;

    if (avatar != null) {
      Uint8List? _avatar = await clip(avatar, size: 256, circle: true);
      if (_avatar != null) {
        // Create a temp file with the avatar
        path = join(FilesystemSvc.appTempPath, "${randomString(8)}.png");
        await File(path).create(recursive: true);
        await File(path).writeAsBytes(_avatar);
      }
    }

    toast = LocalNotification(
      type: LocalNotificationType.imageAndText02,
      imagePath: path,
      title: caller,
      body: "Incoming FaceTime ${isAudio ? 'Audio' : 'Video'} Call",
      duration: LocalNotificationDuration.long,
      actions: callUuid == null ? null : nActions,
      systemSound: LocalNotificationSound.call,
      soundOption: LocalNotificationSoundOption.loop,
    );

    toast.onClick = () async {
      await windowManager.show();
    };

    if (callUuid != null) {
      toast.onClickAction = (index) async {
        if (actions[index] == "Answer") {
          await windowManager.show();
          await IntentsSvc.answerFaceTime(callUuid);
        } else {
          hideFaceTimeOverlay(callUuid);
          await toast?.close();
        }
      };
    }

    toast.onClose = (reason) async {
      if (reason == LocalNotificationCloseReason.timedOut && faceTimeOverlays.containsKey(callUuid)) {
        await toast?.show();
      }
    };

    if (facetimeNotifications[callUuid ?? caller] != null) {
      await facetimeNotifications[callUuid ?? caller]?.close();
    }

    facetimeNotifications[callUuid ?? caller] = toast;

    await toast.show();
  }

  Future<void> clearDesktopFaceTimeNotif(String callerUuid) async {
    await facetimeNotifications[callerUuid]?.close();
    facetimeNotifications.remove(callerUuid);
  }

  void showDesktopNotif(
      String text, Chat chat, String title, String contactName, Message message, bool isReaction, bool isGroupEvent) {
    if (kIsDesktop && !SettingsSvc.settings.desktopNotifications.value) return;

    final String guid = chat.guid;

    pendingMessages[guid] ??= [];

    pendingMessages[guid]!.add(PendingToastItem(
      sender: chat.isGroup && !isReaction ? contactName.split(" ").first : null,
      text: text,
      isReaction: isReaction,
      isGroupEvent: isGroupEvent,
    ));

    // Cancel and clean up old timer
    final oldTimer = debounceTimers[guid];
    oldTimer?.cancel();
    debounceTimers[guid] = Timer(
      const Duration(milliseconds: 300),
      () async => await _buildAndShowToast(chat, title, message),
    );
  }

  Future<void> _buildAndShowToast(Chat chat, String title, Message message) async {
    final String guid = chat.guid;
    if (pendingMessages[guid]?.isEmpty ?? true) return;

    String path;
    bool isTemporaryFile = false;

    // Optimization: For single-participant chats, use existing ContactV2 avatar if available
    if (chat.handles.length == 1 && chat.customAvatarPath == null) {
      final contactV2 = chat.handles.first.contactsV2.firstOrNull;
      if (contactV2?.avatarPath != null && await File(contactV2!.avatarPath!).exists()) {
        // Use existing avatar file directly, no need to generate and write a temp file
        path = contactV2.avatarPath!;
      } else {
        // Need to generate composite avatar
        isTemporaryFile = true;
        final Uint8List avatar = await avatarAsBytes(chat: chat, quality: 256);
        path = join(FilesystemSvc.appTempPath, "${randomString(8)}.png");
        final File avatarFile = File(path);
        await avatarFile.create(recursive: true);
        await avatarFile.writeAsBytes(avatar);
      }
    } else {
      // Group chat or custom avatar - need to generate composite avatar
      isTemporaryFile = true;
      final Uint8List avatar = await avatarAsBytes(chat: chat, quality: 256);
      path = join(FilesystemSvc.appTempPath, "${randomString(8)}.png");
      final File avatarFile = File(path);
      await avatarFile.create(recursive: true);
      await avatarFile.writeAsBytes(avatar);
    }

    int usedLines = 0;
    int numToShow = 0;
    int numMessages = pendingMessages[guid]!.length;

    final int numSenders = pendingMessages[guid]!.map((p) => p.sender).nonNulls.toSet().length;
    for (int i = numMessages - 1; i >= 0; i--) {
      final PendingToastItem item = pendingMessages[guid]![i];
      final String displayText = numSenders > 1 ? item.senderText : item.text;
      final int newLines = _estimateLines(displayText);
      if (usedLines + newLines > maxLines) {
        break;
      }

      usedLines += newLines;
      numToShow += 1;
    }
    if (numToShow == 0) {
      numToShow = 1;
    }

    final int overflowCount = numMessages - numToShow;
    String body = "";
    body += pendingMessages[guid]!
        .slice(overflowCount)
        .map((PendingToastItem e) => numSenders > 1 ? e.senderText : e.text)
        .join("\n");

    final PendingToastItem lastItem = pendingMessages[guid]!.last;

    final papi = SettingsSvc.settings.enablePrivateAPI.value;
    final List<int> selectedIndices = SettingsSvc.settings.selectedActionIndices;
    List<String> actions = SettingsSvc.settings.actionList
        .whereIndexed((i, e) => selectedIndices.contains(i))
        .map((action) => action == "Mark Read"
            ? action
            : !lastItem.isReaction && !lastItem.isGroupEvent && papi
                ? ReactionTypes.reactionToEmoji[action]!
                : null)
        .nonNulls
        .toList();

    bool showMarkRead = actions.contains("Mark Read");
    List<LocalNotificationAction> nActions = actions.map((String a) => LocalNotificationAction(text: a)).toList();

    activeToasts[guid]?.close();

    String displayTitle;
    if (numSenders == 1 && !lastItem.isReaction && !lastItem.isGroupEvent) {
      displayTitle = "$title: ${lastItem.sender}";
    } else {
      displayTitle = title;
    }

    final LocalNotification toast = LocalNotification(
      type: LocalNotificationType.imageAndText03,
      imagePath: path,
      title: displayTitle,
      body: body,
      attributionText: overflowCount > 0 ? "+$overflowCount earlier message${overflowCount > 1 ? "s" : ""}\n" : null,
      duration: LocalNotificationDuration.long,
      actions: numMessages > 1
          ? showMarkRead
              ? [LocalNotificationAction(text: "Mark $numMessages Messages Read")]
              : []
          : nActions,
      hasInput: SettingsSvc.settings.showReplyField.value,
      inputPlaceholder: "Type a reply...",
      inputButtonText: "Reply",
      systemSound: LocalNotificationSound.sms,
      soundOption: SettingsSvc.settings.desktopNotificationSoundPath.value != null
          ? LocalNotificationSoundOption.silent
          : LocalNotificationSoundOption.defaultOption,
    );

    activeToasts[guid] = toast;

    _attachToastHandlers(toast, chat, message, path, actions, numMessages > 1, deleteFileOnClose: isTemporaryFile);

    await playDesktopNotificationSound();

    await toast.show();
  }

  int _estimateLines(String text) {
    return (text.length / charsPerLineEst).ceil() + "\n".allMatches(text).length;
  }

  void _attachToastHandlers(LocalNotification toast, Chat chat, Message message, String avatarPath,
      List<String> actions, bool multipleMessages,
      {bool deleteFileOnClose = true}) {
    toast.onClick = () async {
      _cleanNotificationState(chat.guid);
      await _openChat(chat);
      await windowManager.show();
      if (deleteFileOnClose) {
        _deleteTempFile(avatarPath);
      }
    };

    toast.onClickAction = (index) {
      _cleanNotificationState(chat.guid);
      if (actions[index] == "Mark Read" || multipleMessages) {
        chat.toggleHasUnreadAsync(false);
        EventDispatcher().emit('refresh', null);
      } else if (SettingsSvc.settings.enablePrivateAPI.value) {
        final String reaction = ReactionTypes.emojiToReaction[actions[index]]!;
        final Message _message = Message(
          associatedMessageGuid: message.guid!,
          associatedMessageType: reaction,
          associatedMessagePart: 0,
          dateCreated: DateTime.now(),
          handleId: 0,
        );
        _message.generateTempGuid();
        OutgoingMsgHandler.queue(
          OutgoingReaction(
            chat: chat,
            message: _message,
            selectedMessage: message,
            reaction: reaction,
          ),
        );
      }
      if (deleteFileOnClose) {
        _deleteTempFile(avatarPath);
      }
    };

    toast.onInput = (text) {
      _cleanNotificationState(chat.guid);
      final Message _message = Message(
        dateCreated: DateTime.now(),
        handleId: 0,
        text: text,
        hasDdResults: true,
      );

      _message.generateTempGuid();

      OutgoingMsgHandler.queue(
        OutgoingMessage(
          chat: chat,
          message: _message,
        ),
      );

      if (deleteFileOnClose) {
        _deleteTempFile(avatarPath);
      }
    };

    toast.onClose = (reason) async {
      if (reason != LocalNotificationCloseReason.unknown) {
        _cleanNotificationState(chat.guid);
      }

      if (deleteFileOnClose) {
        _deleteTempFile(avatarPath);
      }
    };
  }

  void _cleanNotificationState(String guid) {
    activeToasts.remove(guid);
  }

  Future<void> _openChat(Chat chat) async {
    if (ChatsSvc.isChatActive(chat.guid) && Get.context != null) {
      NavigationSvc.pushAndRemoveUntil(
        Get.context!,
        ConversationView(chat: chat),
        (route) => route.isFirst,
      );
    }
  }

  Future<void> _deleteTempFile(String path) async {
    try {
      final File file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore file deletion errors
    }
  }

  Future<void> playDesktopNotificationSound() async {
    if (SettingsSvc.settings.desktopNotificationSoundPath.value != null) {
      _desktopNotificationPlayer?.dispose();
      final player = Player();
      _desktopNotificationPlayer = player;
      await player.setVolume(SettingsSvc.settings.desktopNotificationSoundVolume.value.toDouble());
      await player.open(Media(SettingsSvc.settings.desktopNotificationSoundPath.value!));
      player.stream.completed.firstWhere((completed) => completed).then((_) async {
        await Future.delayed(const Duration(milliseconds: 450));
        if (_desktopNotificationPlayer == player) {
          await player.dispose();
          _desktopNotificationPlayer = null;
        }
      });
    }
  }

  Future<void> createAliasesRemovedNotification(List<String> aliases) async {
    const title = "iMessage alias deregistered!";
    const notifId = -3;
    final text = aliases.length == 1
        ? "${aliases[0]} has been deregistered!"
        : "The following aliases have been deregistered:\n${aliases.join("\n")}";

    if (kIsDesktop) {
      if (aliasesToast?.body == text) {
        return;
      } else {
        await aliasesToast?.close();
      }

      aliasesToast = LocalNotification(
        type: LocalNotificationType.text02,
        title: title,
        body: text,
        actions: [],
      );

      aliasesToast!.onClick = () async {
        aliasesToast = null;
        await windowManager.show();
      };

      await aliasesToast!.show();
    } else {
      final notifs = await flnp.getActiveNotifications();

      //Already have this notification
      if (notifs.firstWhereOrNull((n) => n.id == notifId && n.body == text) != null) {
        return;
      }

      await flnp.show(
        id: notifId,
        title: title,
        body: text,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(ERROR_CHANNEL, 'Errors',
              channelDescription: 'Displays message send failures, connection failures, and more',
              priority: Priority.max,
              importance: Importance.max,
              color: HexColor("4990de"),
              ongoing: false,
              onlyAlertOnce: false,
              styleInformation: const BigTextStyleInformation('')),
        ),
      );
    }
  }

  Future<void> createFailedToSend(Chat chat, {bool scheduled = false}) async {
    final title = 'Failed to send${scheduled ? " scheduled" : ""} message';
    final subtitle = scheduled ? 'Tap to open scheduled messages list' : 'Tap to see more details or retry';
    if (kIsDesktop) {
      failedToast = LocalNotification(
        type: LocalNotificationType.text02,
        title: title,
        body: subtitle,
        actions: [],
      );

      failedToast!.onClick = () async {
        failedToast = null;
        await windowManager.show();
        if (scheduled) {
          Navigator.of(Get.context!).push(
            ThemeSwitcher.buildPageRoute(
              builder: (BuildContext context) {
                return const ScheduledMessagesPanel();
              },
            ),
          );
        } else {
          bool chatIsOpen = ChatsSvc.activeChat?.chat.guid == chat.guid;
          if (!chatIsOpen) {
            NavigationSvc.pushAndRemoveUntil(
              Get.context!,
              ConversationView(
                chat: chat,
              ),
              (route) => route.isFirst,
            );
          }
        }
      };

      await failedToast!.show();
      return;
    }
    await flnp.show(
      id: (chat.id! + 75000) * (scheduled ? -1 : 1),
      title: title,
      body: subtitle,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          ERROR_CHANNEL,
          'Errors',
          channelDescription: 'Displays message send failures, connection failures, and more',
          priority: Priority.max,
          importance: Importance.max,
          color: HexColor("4990de"),
        ),
      ),
      payload: chat.guid + (scheduled ? "-scheduled" : ""),
    );
  }

  Future<void> clearFailedToSend(int id) async {
    if (kIsDesktop) {
      await failedToast?.close();
      failedToast = null;
      return;
    }
    await flnp.cancel(id: id);
  }

  Future<void> clearDesktopNotificationsForChat(String chatGuid) async {
    await _lock.synchronized(() async {
      await activeToasts[chatGuid]?.close();
      _cleanNotificationState(chatGuid);
      debounceTimers[chatGuid]?.cancel();
      debounceTimers.remove(chatGuid);
      pendingMessages.remove(chatGuid);
    });
  }
}
