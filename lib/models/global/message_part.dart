import 'package:bluebubbles/models/models.dart';

class MessagePart {
  MessagePart({
    this.subject,
    this.text,
    this.attachments = const [],
    this.mentions = const [],
    this.isUnsent = false,
    this.isEdited = false,
    this.edits = const [],
    required this.part,
  }) {
    if (attachments.isEmpty) attachments = [];
    if (mentions.isEmpty) mentions = [];
    if (edits.isEmpty) edits = [];
  }

  String? subject;
  String? text;
  List<Attachment> attachments;
  List<Mention> mentions;
  bool isUnsent;
  bool isEdited;
  List<List<MessagePart>> edits;
  int part;
}

class Mention {
  Mention({
    this.mentionedAddress,
    this.range = const [],
  });

  String? mentionedAddress;
  List<int> range;
}