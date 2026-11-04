import 'dart:convert';

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
  static const String _tapbackEmojiUsageKey = 'tapback-emoji-usage';
  static const int _tapbackEmojiLimit = 28;
  // Enough for a chat's own favourites; kept short since there's one list per chat
  static const int _chatTapbackEmojiLimit = 8;

  final SharedPreferencesService service;

  SharedPreferencesMessagingActions(this.service);

  /// Emoji used as tapbacks: those used in [chatGuid] first, then the rest of everywhere. Each list is ordered most
  /// used first, and of equal use the most recent first. Kept apart from the emoji pickers' recents, which are what
  /// people type: the two sets tend to differ.
  List<String> getRecentTapbackEmojis({required String chatGuid}) => {
        ..._tapbackEmojiUsage(_chatTapbackEmojiKey(chatGuid)).map((u) => u.emoji),
        ..._tapbackEmojiUsage(_tapbackEmojiUsageKey).map((u) => u.emoji),
      }.toList();

  /// Counts a use of [emoji] in [chatGuid] and overall. A full list drops its least used, longest unused emoji, so
  /// a new one isn't pushed out by its own low count. The two lists evict independently: an emoji kept for one
  /// chat survives churn everywhere else.
  Future<void> addRecentTapbackEmoji(String emoji, {required String chatGuid}) async {
    await _countTapbackEmoji(_tapbackEmojiUsageKey, emoji, _tapbackEmojiLimit);
    await _countTapbackEmoji(_chatTapbackEmojiKey(chatGuid), emoji, _chatTapbackEmojiLimit);
  }

  String _chatTapbackEmojiKey(String chatGuid) => '$_tapbackEmojiUsageKey:$chatGuid';

  Future<void> _countTapbackEmoji(String key, String emoji, int limit) async {
    final usage = _tapbackEmojiUsage(key);
    final index = usage.indexWhere((u) => u.emoji == emoji);
    final count = index == -1 ? 1 : usage.removeAt(index).count + 1;
    usage.add((emoji: emoji, count: count, lastUsed: DateTime.now().millisecondsSinceEpoch));
    _sortTapbackEmojiUsage(usage);
    final kept = usage.take(limit).map((u) => {'e': u.emoji, 'n': u.count, 't': u.lastUsed}).toList();
    await service.i.setString(key, jsonEncode(kept));
  }

  List<({String emoji, int count, int lastUsed})> _tapbackEmojiUsage(String key) {
    final raw = service.i.getString(key);
    if (raw == null) return [];
    try {
      final usage = [
        for (final entry in (jsonDecode(raw) as List).cast<Map>())
          (emoji: entry['e'] as String, count: entry['n'] as int, lastUsed: entry['t'] as int),
      ];
      return _sortTapbackEmojiUsage(usage);
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  static List<({String emoji, int count, int lastUsed})> _sortTapbackEmojiUsage(
      List<({String emoji, int count, int lastUsed})> usage) {
    return usage
      ..sort((a, b) => a.count != b.count ? b.count.compareTo(a.count) : b.lastUsed.compareTo(a.lastUsed));
  }

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
