import 'package:bluebubbles/services/backend/settings/shared_preferences_service.dart';

class ReplyToMessageState {
  final String messageGuid;
  final int messagePart;

  const ReplyToMessageState({required this.messageGuid, required this.messagePart});
}

class RecentReplyState {
  final String messageGuid;
  final String text;

  const RecentReplyState({required this.messageGuid, required this.text});
}

class SharedPreferencesMessagingActions {
  static const String _lastOpenedChatKey = 'lastOpenedChat';
  static const String _recentReplyKey = 'recent-reply';
  static const String _replyToMessagePrefix = 'replyToMessage';
  static const String _replyToMessagePartPrefix = 'replyToMessagePart';

  final SharedPreferencesService service;

  SharedPreferencesMessagingActions(this.service);

  String _replyMessageKey(String chatGuid) => '${_replyToMessagePrefix}_$chatGuid';

  String _replyMessagePartKey(String chatGuid) => '${_replyToMessagePartPrefix}_$chatGuid';

  String? getLastOpenedChat() => service.i.getString(_lastOpenedChatKey);

  Future<void> setLastOpenedChat(String chatGuid) async {
    await service.i.setString(_lastOpenedChatKey, chatGuid);
  }

  Future<void> clearLastOpenedChat() async {
    await service.i.remove(_lastOpenedChatKey);
  }

  Future<void> saveReplyToMessageState({
    required String chatGuid,
    String? messageGuid,
    int? messagePart,
  }) async {
    if (messageGuid != null && messagePart != null) {
      await service.i.setString(_replyMessageKey(chatGuid), messageGuid);
      await service.i.setInt(_replyMessagePartKey(chatGuid), messagePart);
      return;
    }

    await service.i.remove(_replyMessageKey(chatGuid));
    await service.i.remove(_replyMessagePartKey(chatGuid));
  }

  ReplyToMessageState? loadReplyToMessageState(String chatGuid) {
    final messageGuid = service.i.getString(_replyMessageKey(chatGuid));
    final messagePart = service.i.getInt(_replyMessagePartKey(chatGuid));

    if (messageGuid == null || messagePart == null) return null;
    return ReplyToMessageState(messageGuid: messageGuid, messagePart: messagePart);
  }

  RecentReplyState? getRecentReply() {
    final raw = service.i.getString(_recentReplyKey);
    if (raw == null || raw.isEmpty) return null;

    final divider = raw.indexOf('/');
    if (divider <= 0 || divider >= raw.length - 1) return null;

    return RecentReplyState(
      messageGuid: raw.substring(0, divider),
      text: raw.substring(divider + 1),
    );
  }

  String? getRecentReplyRaw() => service.i.getString(_recentReplyKey);

  Future<void> setRecentReply({required String messageGuid, required String text}) async {
    await service.i.setString(_recentReplyKey, '$messageGuid/$text');
  }
}
