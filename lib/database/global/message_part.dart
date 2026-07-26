import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
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
    this.shouldRedact = false,
    this.attachmentPartIndices,
    this.firstPartIndex,
  }) {
    if (attachments.isEmpty) attachments = [];
    if (mentions.isEmpty) mentions = [];
    if (edits.isEmpty) edits = [];
  }

  /// Whether this part's display text/subject should be replaced with fake
  /// content.  Managed by [MessageState.buildMessageParts] and updated via
  /// [MessageState.updateShouldHideMessageContentInternal] so widgets never
  /// need to check settings directly.
  bool shouldRedact;

  bool get isPkPass => attachments.any((a) => a.isPkPass);

  String? subject;
  late final String fakeSubject = faker.lorem.words(subject?.split(" ").length ?? 0).join(" ");
  String? get displaySubject {
    if (subject == null) return null;
    if (shouldRedact) return fakeSubject;
    return subject;
  }

  String? text;
  late final String fakeText = faker.lorem.words(text?.split(" ").length ?? 0).join(" ");
  String? get displayText {
    if (text == null) return null;
    if (shouldRedact) return fakeText;
    return text;
  }

  List<Attachment> attachments;
  List<Mention> mentions;
  bool isUnsent;
  List<MessagePart> edits;
  int part;

  /// For collection parts created by collapsing consecutive media-only parts,
  /// maps each attachment (by index) to its original messagePart index.
  /// Null for non-collection parts or single-source-part collections.
  List<int>? attachmentPartIndices;

  /// First raw message-part index covered by a collapsed media collection.
  /// Null for non-collection parts. Collections set [part] to the *last* raw
  /// index (avatar/tail checks) and this to the *first* (leading-part UI).
  int? firstPartIndex;

  /// Whether this bubble is the leading content of the message (raw part 0).
  bool get isLeadingMessagePart => (firstPartIndex ?? part) == 0;

  /// Returns the real source message-part index for the attachment at [index].
  /// Falls back to [part] for non-collection and single-source collection parts.
  int partIndexForAttachment(int index) => attachmentPartIndices?[index] ?? part;

  /// Whether a reaction/sticker targeting a real message-part index belongs on this bubble.
  bool includesAssociatedPart(int? associatedMessagePart) {
    final index = associatedMessagePart ?? 0;
    final indices = attachmentPartIndices;
    if (indices != null && indices.isNotEmpty) {
      return indices.contains(index);
    }
    return index == part;
  }

  bool get isEdited => edits.isNotEmpty;
  String? get url => text?.replaceAll("\n", " ").split(" ").firstWhereOrNull((String e) => e.hasUrl);
  String get fullText => sanitizeString([subject, text].where((e) => !isNullOrEmpty(e)).join("\n"));

  /// True when this part contains only images or videos with no text or subject.
  /// Used to determine whether adjacent parts can be collapsed into a collection.
  bool get isMediaOnlyPart =>
      attachments.isNotEmpty &&
      text == null &&
      subject == null &&
      attachments.every((a) => a.mimeStart == 'image' || a.mimeStart == 'video');

  /// Multi-item image/video group routed to collage/stack/grid instead of [AttachmentHolder].
  bool get isMediaCollection =>
      attachments.length > 1 && attachments.every((a) => a.mimeStart == 'image' || a.mimeStart == 'video');
}

class Mention {
  Mention({
    this.mentionedAddress,
    this.range = const [],
  });

  String? mentionedAddress;
  List<int> range;
}
