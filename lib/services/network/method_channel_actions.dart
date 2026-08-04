import 'package:bluebubbles/services/backend/java_dart_interop/method_channel_service.dart';
import 'package:flutter/services.dart';

class MethodChannelActions {
  final MethodChannelService service;
  MethodChannelActions(this.service);

  Future<void> signalReady() async {
    await service.invokeMethod('ready');
  }

  Future<void> openBrowser({required String? link}) async {
    if (link == null || link.isEmpty) return;
    await service.invokeMethod('open-browser', {'link': link});
  }

  Future<void> openContactForm({required String address, required bool isEmail}) async {
    await service.invokeMethod('open-contact-form', {
      'address': address,
      'address_type': isEmail ? 'email' : 'phone',
    });
  }

  Future<void> viewContactForm({required dynamic nativeContactId}) async {
    await service.invokeMethod('view-contact-form', {'id': nativeContactId});
  }

  Future<void> openCalendar({required int dateEpochMillis}) async {
    await service.invokeMethod('open-calendar', {'date': dateEpochMillis});
  }

  Future<void> pushShareTarget({required String title, required String guid, required Uint8List icon}) async {
    await service.invokeMethod('push-share-targets', {
      'title': title,
      'guid': guid,
      'icon': icon,
    });
  }

  Future<void> requestNotificationListenerPermission() async {
    await service.invokeMethod('request-notification-listener-permission');
  }

  Future<void> startNotificationListener() async {
    await service.invokeMethod('start-notification-listener');
  }

  Future<void> openConversationNotificationSettings({required String channelId, required String displayName}) async {
    await service.invokeMethod('open-conversation-notification-settings', {
      'channel_id': channelId,
      'display_name': displayName,
    });
  }

  Future<void> setNextRestart({required int value}) async {
    await service.invokeMethod('set-next-restart', {'value': value});
  }

  Future<void> startForegroundService() async {
    await service.invokeMethod('start-foreground-service');
  }

  Future<void> stopForegroundService() async {
    await service.invokeMethod('stop-foreground-service');
  }

  Future<void> deleteNotification({required int notificationId, String? tag}) async {
    await service.invokeMethod('delete-notification', {
      'notification_id': notificationId,
      if (tag != null) 'tag': tag,
    });
  }

  Future<String?> firebaseAuth({required Map<String, dynamic> fcmData}) async {
    return await service.invokeMethod('firebase-auth', fcmData) as String?;
  }

  Future<void> firebaseDeleteToken() async {
    await service.invokeMethod('firebase-delete-token');
  }

  Future<String?> getServerUrl() async {
    return await service.invokeMethod('get-server-url') as String?;
  }

  Future<void> createNotificationChannel({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    await service.invokeMethod('create-notification-channel', {
      'channel_name': channelName,
      'channel_description': channelDescription,
      'channel_id': channelId,
    });
  }

  Future<void> createIncomingMessageNotification({
    required String channelId,
    required int? chatId,
    required String chatGuid,
    required bool chatIsGroup,
    required String chatTitle,
    required Uint8List chatIcon,
    required String contactName,
    required Uint8List contactAvatar,
    required String? nativeContactId,
    required bool dndFavoritesOverride,
    required String messageGuid,
    required String messageText,
    required int messageDate,
    required bool messageIsFromMe,
    required bool showReactionAction,
    required String reactionType,
  }) async {
    await service.invokeMethod('create-incoming-message-notification', {
      'channel_id': channelId,
      'chat_id': chatId,
      'chat_guid': chatGuid,
      'chat_is_group': chatIsGroup,
      'chat_title': chatTitle,
      'chat_icon': chatIcon,
      'contact_name': contactName,
      'contact_avatar': contactAvatar,
      if (nativeContactId != null) 'native_contact_id': nativeContactId,
      'dnd_favorites_override': dndFavoritesOverride,
      'message_guid': messageGuid,
      'message_text': messageText,
      'message_date': messageDate,
      'message_is_from_me': messageIsFromMe,
      'show_reaction_action': showReactionAction,
      'reaction_type': reactionType,
    });
  }

  Future<void> createIncomingFaceTimeNotification({
    required String channelId,
    required int notificationId,
    required String title,
    required String body,
    required Uint8List callerAvatar,
    required String caller,
    String? callUuid,
  }) async {
    await service.invokeMethod('create-incoming-facetime-notification', {
      'channel_id': channelId,
      'notification_id': notificationId,
      'title': title,
      'body': body,
      'caller_avatar': callerAvatar,
      'caller': caller,
      'call_uuid': callUuid,
    });
  }

  Future<String> getContentUriPath({required String uri}) async {
    return (await service.invokeMethod('get-content-uri-path', {'uri': uri})).toString();
  }

  Future<void> googleDuo({required String number}) async {
    await service.invokeMethod('google-duo', {'number': number});
  }

  Future<void> updateUnifiedPushRegistration({required bool enabled}) async {
    await service.invokeMethod('UnifiedPushHandler', {
      'operation': enabled ? 'register' : 'unregister',
    });
  }

  Future<void> saveFileToDownloads({
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    await service.invokeMethod('save-file-to-downloads', {
      'filePath': filePath,
      'fileName': fileName,
      'mimeType': mimeType,
    });
  }
}
