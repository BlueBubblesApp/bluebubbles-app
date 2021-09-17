import 'package:objectbox/objectbox.dart';

@Entity()
class AttachmentMessageJoin {
  int? id;
  int attachmentId;
  int messageId;

  AttachmentMessageJoin({
    required this.attachmentId,
    required this.messageId,
  });
}

@Entity()
class ChatHandleJoin {
  int? id;
  int chatId;
  int handleId;

  ChatHandleJoin({
    required this.chatId,
    required this.handleId,
  });
}

@Entity()
class ChatMessageJoin {
  int? id;
  int chatId;
  int messageId;

  ChatMessageJoin({
    required this.chatId,
    required this.messageId,
  });
}

@Entity()
class ThemeValueJoin {
  int? id;
  int themeId;
  int themeValueId;

  ThemeValueJoin({
    required this.themeId,
    required this.themeValueId,
  });
}