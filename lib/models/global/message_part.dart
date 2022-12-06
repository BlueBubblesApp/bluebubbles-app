import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';

class MessagePart {
  MessagePart({
    this.subject,
    this.text,
    this.attachments = const [],
    this.mentions = const [],
    this.isUnsent = false,
    this.edits = const [],
    required this.part,
  }) {
    if (attachments.isEmpty) attachments = [];
    if (mentions.isEmpty) mentions = [];
    if (edits.isEmpty) edits = [];
  }

  String? subject;
  late final String fakeSubject = faker.lorem.words(subject?.split(" ").length ?? 0).join(" ");
  String? get displaySubject {
    if (subject == null) return null;
    if (ss.settings.redactedMode.value) {
      if (ss.settings.generateFakeMessageContent.value) {
        return fakeSubject;
      } else if (ss.settings.hideContactInfo.value) {
        return "";
      }
    }
    return text;
  }
  String? text;
  late final String fakeText = faker.lorem.words(text?.split(" ").length ?? 0).join(" ");
  String? get displayText {
    if (text == null) return null;
    if (ss.settings.redactedMode.value) {
      if (ss.settings.generateFakeMessageContent.value) {
        return fakeText;
      } else if (ss.settings.hideContactInfo.value) {
        return "";
      }
    }
    return text;
  }
  List<Attachment> attachments;
  List<Mention> mentions;
  bool isUnsent;
  List<MessagePart> edits;
  int part;

  bool get isEdited => edits.isNotEmpty;
  String? get url => text?.replaceAll("\n", " ").split(" ").firstWhereOrNull((String e) => e.hasUrl);
  String get fullText => sanitizeString([subject, text].where((e) => !isNullOrEmpty(e)!).join("\n"));
}

class Mention {
  Mention({
    this.mentionedAddress,
    this.range = const [],
  });

  String? mentionedAddress;
  List<int> range;
}