import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/backend/settings_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

import 'method_channel_constants.dart';

abstract class MethodChannelServiceDelegate {
  bool get headless;
  bool get shouldIgnoreMessage;
  bool get isRunning;
  set isRunning(bool value);
  Uint8List? get previousArt;
  set previousArt(Uint8List? value);
}

class MethodChannelHandlers {
  MethodChannelHandlers(this.service) {
    _handlers = {
      MethodChannelInboundMethods.newServerUrl: _handleNewServerUrl,
      MethodChannelInboundMethods.newMessage: _handleNewMessage,
      MethodChannelInboundMethods.updatedMessage: _handleUpdatedMessage,
      MethodChannelInboundMethods.groupNameChange: _handleGroupUpdate,
      MethodChannelInboundMethods.participantRemoved: _handleGroupUpdate,
      MethodChannelInboundMethods.participantAdded: _handleGroupUpdate,
      MethodChannelInboundMethods.participantLeft: _handleGroupUpdate,
      MethodChannelInboundMethods.groupIconChanged: _handleGroupIconChanged,
      MethodChannelInboundMethods.scheduledMessageError: _handleScheduledMessageError,
      MethodChannelInboundMethods.replyChat: _handleReplyChat,
      MethodChannelInboundMethods.markChatRead: _handleMarkChatRead,
      MethodChannelInboundMethods.chatReadStatusChanged: _handleChatReadStatusChanged,
      MethodChannelInboundMethods.mediaColors: _handleMediaColors,
      MethodChannelInboundMethods.incomingFacetime: _handleIncomingFacetime,
      MethodChannelInboundMethods.ftCallStatusChanged: _handleFtCallStatusChanged,
      MethodChannelInboundMethods.answerFacetime: _handleAnswerFacetime,
      MethodChannelInboundMethods.iMessageAliasesRemoved: _handleAliasesRemoved,
      MethodChannelInboundMethods.socketEvent: _handleSocketEvent,
      MethodChannelInboundMethods.unifiedpushSettings: _handleUnifiedPushSettings,
    };
  }

  final MethodChannelServiceDelegate service;
  late final Map<String, Future<bool> Function(MethodCall, Map<String, dynamic>?)> _handlers;

  Future<bool> handle(MethodCall call, Map<String, dynamic>? arguments) {
    final handler = _handlers[call.method];
    if (handler == null) return _ok();
    return handler(call, arguments);
  }

  static Future<bool> _ok() => Future.value(true);
  static Future<bool> _retry() => Future.value(false);

  Future<bool> _handleNewServerUrl(MethodCall _, Map<String, dynamic>? arguments) async {
    if (arguments == null) return _retry();
    await Database.waitForInit();

    final String address = arguments['server_url'];
    final bool updated = await saveNewServerUrl(address, restartSocket: false);
    if (updated && !service.headless) {
      SocketSvc.restartSocket();
    }
    return _ok();
  }

  Future<bool> _handleNewMessage(MethodCall _, Map<String, dynamic>? arguments) async {
    await Database.waitForInit();
    Logger.info('Received new message from MethodChannel');

    if (!GetIt.I.isRegistered<IncomingMessageHandler>()) {
      Logger.warn('IncomingMessageHandler not registered yet, requesting method channel retry');
      return _retry();
    }

    try {
      if (!service.headless &&
          LifecycleSvc.isAlive &&
          (SocketSvc.socket?.connected ?? false) &&
          SettingsSvc.settings.endpointUnifiedPush.value == '') {
        Logger.debug('App is alive, ignoring new message...');
        return _ok();
      } else if (!service.headless && !LifecycleSvc.isAlive && SettingsSvc.settings.keepAppAlive.value) {
        Logger.debug('Ignoring FCM message while app is not alive, but keepAppAlive is enabled');
        return _ok();
      }

      final Map<String, dynamic>? data = arguments;
      if (!isNullOrEmpty(data)) {
        final payload = ServerPayload.fromJson(data!);
        await IncomingMsgHandler.handle(IncomingPayload(
          type: MessageEventType.newMessage,
          source: MessageSource.methodChannel,
          chat: Chat.fromMap(payload.data['chats'].first.cast<String, Object>()),
          message: Message.fromMap(payload.data),
          attachments: ((payload.data['attachments'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Attachment.fromMap(e.cast<String, Object>()))
              .toList(),
          tempGuid: payload.data['tempGuid'],
        ));
      }
    } catch (e, s) {
      debugPrint('Error processing new message: $e');
      debugPrint(s.toString());
      Logger.error('Error processing new message: $e', trace: s);
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleUpdatedMessage(MethodCall _, Map<String, dynamic>? arguments) async {
    await Database.waitForInit();
    Logger.info('Received updated message from MethodChannel');

    if (!GetIt.I.isRegistered<IncomingMessageHandler>()) {
      Logger.warn('IncomingMessageHandler not registered yet, requesting method channel retry');
      return _retry();
    }

    if (!service.headless && !LifecycleSvc.isAlive && SettingsSvc.settings.keepAppAlive.value) {
      Logger.debug('Ignoring FCM message while app is not alive, but keepAppAlive is enabled');
      return _ok();
    }

    try {
      final Map<String, dynamic>? data = arguments;
      if (!isNullOrEmpty(data)) {
        final payload = ServerPayload.fromJson(data!);

        if (payload.data['chats'] == null || payload.data['chats'].isEmpty) {
          Logger.info('No chat data found, attempting to find chat from message guid: ${payload.data['guid']}...');
          final existingMsg = Message.findOne(guid: payload.data['guid']);
          if (existingMsg != null && existingMsg.chat.target != null) {
            Logger.info('Found chat from message guid, adding to payload');
            payload.data['chats'] = [existingMsg.chat.target!.toMap()];
          } else {
            Logger.warn('No chat data found, and unable to find chat from message guid: ${payload.data['guid']}');
            return _retry();
          }
        }

        await IncomingMsgHandler.handle(IncomingPayload(
          type: MessageEventType.updatedMessage,
          source: MessageSource.methodChannel,
          chat: Chat.fromMap(payload.data['chats'].first.cast<String, Object>()),
          message: Message.fromMap(payload.data),
          attachments: ((payload.data['attachments'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Attachment.fromMap(e.cast<String, Object>()))
              .toList(),
          tempGuid: payload.data['tempGuid'],
        ));
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleGroupUpdate(MethodCall call, Map<String, dynamic>? arguments) async {
    await Database.waitForInit();
    Logger.info('Received ${call.method} from MethodChannel');

    if (service.shouldIgnoreMessage) {
      Logger.debug('Ignoring FCM message while app is not alive, but keepAppAlive is enabled');
      return _ok();
    }

    try {
      final Map<String, dynamic>? data = arguments;
      if (!isNullOrEmpty(data)) {
        final payload = ServerPayload.fromJson(data!);
        await MessageHandlerSvc.handleNewOrUpdatedChat(
            Chat.fromMap(payload.data['chats'].first.cast<String, Object>()));
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleGroupIconChanged(MethodCall _, Map<String, dynamic>? arguments) async {
    await Database.waitForInit();
    Logger.info('Received group icon change from MethodChannel');

    if (service.shouldIgnoreMessage) {
      Logger.debug('Ignoring FCM message while app is not alive, but keepAppAlive is enabled');
      return _ok();
    }

    try {
      final Map<String, dynamic>? data = arguments;
      if (!isNullOrEmpty(data)) {
        final payload = ServerPayload.fromJson(data!);
        final guid = payload.data['chats'].first['guid'];
        final chat = Chat.findOne(guid: guid);
        if (chat != null) {
          await Chat.getIcon(chat);
        }
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleScheduledMessageError(MethodCall _, Map<String, dynamic>? arguments) async {
    Logger.info('Received scheduled message error from FCM');
    if (!GetIt.I.isRegistered<NotificationsService>()) {
      Logger.warn('NotificationsService not registered yet, requesting method channel retry');
      return _retry();
    }

    try {
      await GetIt.I.isReady<NotificationsService>();
      if (arguments == null) return _ok();
      final payload = ServerPayload.fromJson(arguments);
      final Chat? chat = Chat.findOne(guid: payload.data['payload']['chatGuid']);
      if (chat != null) {
        await NotificationsSvc.createFailedToSend(chat, scheduled: true);
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleReplyChat(MethodCall _, Map<String, dynamic>? arguments) async {
    await Database.waitForInit();
    Logger.info('Received reply to message from Kotlin');
    final Map<String, dynamic>? data = arguments;
    if (data == null) return _ok();

    final recentReply = PrefsSvc.messaging.getRecentReply();
    final recentReplyGuid = recentReply?.messageGuid;
    final recentReplyText = recentReply?.text;
    if (recentReplyGuid == data['messageGuid'] && recentReplyText == data['text']) return _retry();

    await PrefsSvc.messaging.setRecentReply(
      messageGuid: data['messageGuid'],
      text: data['text'],
    );
    Logger.info('Updated recent reply cache to ${PrefsSvc.messaging.getRecentReplyRaw()}');

    final Chat? chat = Chat.findOne(guid: data['chatGuid']);
    if (chat == null) return _retry();

    final Completer<void> completer = Completer();
    OutgoingMsgHandler.queue(
      OutgoingMessage(
        completer: completer,
        chat: chat,
        message: Message(
          text: data['text'],
          dateCreated: DateTime.now(),
          hasAttachments: false,
          isFromMe: true,
          handleId: 0,
        ),
        clearNotificationsIfFromMe: false,
      ),
    );

    await completer.future;
    return _ok();
  }

  Future<bool> _handleMarkChatRead(MethodCall _, Map<String, dynamic>? arguments) async {
    if (!service.headless && LifecycleSvc.isAlive) return _ok();
    await Database.waitForInit();
    Logger.info('Received markAsRead from Kotlin');

    try {
      if (arguments != null) {
        final Chat? chat = Chat.findOne(guid: arguments['chatGuid']);
        if (chat != null) {
          await chat.toggleHasUnreadAsync(false, clearLocalNotifications: false);
          ChatsSvc.getChatState(chat.guid)?.updateHasUnreadInternal(false);
          return _ok();
        }
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _retry();
  }

  Future<bool> _handleChatReadStatusChanged(MethodCall _, Map<String, dynamic>? arguments) async {
    if (!service.headless && LifecycleSvc.isAlive) return _ok();
    await Database.waitForInit();
    Logger.info('Received chat status change from FCM');

    try {
      final Map<String, dynamic>? data = arguments;
      if (!isNullOrEmpty(data)) {
        final payload = ServerPayload.fromJson(data!);
        final Chat? chat = Chat.findOne(guid: payload.data['chatGuid']);
        if (chat == null || (payload.data['read'] != true && payload.data['read'] != false)) {
          return _retry();
        }

        chat.toggleHasUnreadAsync(!payload.data['read']!, privateMark: false);
        return _ok();
      }

      return _retry();
    } catch (e, s) {
      return Future.error(e, s);
    }
  }

  Future<bool> _handleMediaColors(MethodCall call, Map<String, dynamic>? _) async {
    await Database.waitForInit();
    if (!SettingsSvc.settings.colorsFromMedia.value) return _ok();

    final Uint8List art = call.arguments['albumArt'];
    if (Get.context != null && (!service.isRunning || art != service.previousArt)) {
      ThemeSvc.updateMusicTheme(Get.context!, art);
      service.isRunning = false;
    }

    return _ok();
  }

  Future<bool> _handleIncomingFacetime(MethodCall _, Map<String, dynamic>? arguments) async {
    await Database.waitForInit();
    Logger.info('Received legacy incoming facetime from FCM');
    try {
      final Map<String, dynamic>? data = arguments;
      if (!isNullOrEmpty(data)) {
        final payload = ServerPayload.fromJson(data!);
        await ActionHandler().handleIncomingFaceTimeCallLegacy(payload.data);
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleFtCallStatusChanged(MethodCall _, Map<String, dynamic>? arguments) async {
    if (!service.headless && LifecycleSvc.isAlive) return _ok();
    await Database.waitForInit();
    Logger.info('Received facetime call status change from FCM');

    try {
      final Map<String, dynamic>? data = arguments;
      if (!isNullOrEmpty(data)) {
        final payload = ServerPayload.fromJson(data!);
        await ActionHandler().handleFaceTimeStatusChange(payload.data);
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleAnswerFacetime(MethodCall _, Map<String, dynamic>? arguments) async {
    Logger.info('Answering FaceTime call');
    if (arguments == null) return _ok();

    await IntentsSvc.answerFaceTime(arguments['callUuid']);
    return _ok();
  }

  Future<bool> _handleAliasesRemoved(MethodCall _, Map<String, dynamic>? arguments) async {
    if (!GetIt.I.isRegistered<NotificationsService>()) {
      Logger.warn('NotificationsService not registered yet, requesting method channel retry');
      return _retry();
    }
    try {
      await GetIt.I.isReady<NotificationsService>();
      final Map<String, dynamic>? data = arguments;
      if (!isNullOrEmpty(data)) {
        final payload = ServerPayload.fromJson(data!);
        Logger.info('Alias(es) removed ${payload.data['aliases']}');
        await NotificationsSvc.createAliasesRemovedNotification((payload.data['aliases'] as List).cast<String>());
      } else {
        Logger.warn('Aliases removed data empty or null');
      }
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleSocketEvent(MethodCall _, Map<String, dynamic>? arguments) async {
    if (arguments == null) return _ok();

    try {
      final Map<String, dynamic> jsonData = jsonDecode(arguments['data']);
      await MessageHandlerSvc.handleEvent(arguments['event'], jsonData, 'MethodChannel', useQueue: false);
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }

  Future<bool> _handleUnifiedPushSettings(MethodCall _, Map<String, dynamic>? arguments) async {
    if (arguments == null) return _retry();

    try {
      final String endpoint = arguments['endpoint'].toString();
      upr.update(endpoint);
    } catch (e, s) {
      return Future.error(e, s);
    }

    return _ok();
  }
}
