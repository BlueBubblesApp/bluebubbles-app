import 'package:bluebubbles/models/models.dart';

class MessagePart {
  MessagePart({
    this.subject,
    this.text,
    this.attachments = const [],
    this.mention,
    this.isUnsent = false,
    this.isEdited = false,
    this.edits = const [],
    required this.part,
  }) {
    if (attachments.isEmpty) attachments = [];
    if (edits.isEmpty) edits = [];
  }

  String? subject;
  String? text;
  List<Attachment> attachments;
  Mention? mention;
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