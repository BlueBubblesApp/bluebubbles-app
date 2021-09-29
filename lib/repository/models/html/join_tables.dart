class AttachmentMessageJoin {
  int? id;
  int attachmentId;
  int messageId;

  AttachmentMessageJoin({
    required this.attachmentId,
    required this.messageId,
  });

  factory AttachmentMessageJoin.fromMap(Map<String, dynamic> map) {
    return AttachmentMessageJoin(
      attachmentId: map['attachmentId'] as int,
      messageId: map['messageId'] as int,
    );
  }
}

class ChatHandleJoin {
  int? id;
  int chatId;
  int handleId;

  ChatHandleJoin({
    required this.chatId,
    required this.handleId,
  });

  factory ChatHandleJoin.fromMap(Map<String, dynamic> map) {
    return ChatHandleJoin(
      chatId: map['chatId'] as int,
      handleId: map['handleId'] as int,
    );
  }
}

class ChatMessageJoin {
  int? id;
  int chatId;
  int messageId;

  ChatMessageJoin({
    required this.chatId,
    required this.messageId,
  });

  factory ChatMessageJoin.fromMap(Map<String, dynamic> map) {
    return ChatMessageJoin(
      chatId: map['chatId'] as int,
      messageId: map['messageId'] as int,
    );
  }
}

class ThemeValueJoin {
  int? id;
  int themeId;
  int themeValueId;

  ThemeValueJoin({
    required this.themeId,
    required this.themeValueId,
  });

  factory ThemeValueJoin.fromMap(Map<String, dynamic> map) {
    return ThemeValueJoin(
      themeId: map['themeId'] as int,
      themeValueId: map['themeValueId'] as int,
    );
  }
}
