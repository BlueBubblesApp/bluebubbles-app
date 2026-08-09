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

  /// For gallery parts created by collapsing consecutive media-only parts,
  /// maps each attachment (by index) to its original messagePart index.
  /// Null for non-gallery parts or single-source-part galleries.
  List<int>? attachmentPartIndices;

  /// Returns the original message part index for the attachment at [index].
  /// Falls back to [part] if [attachmentPartIndices] is not set.
  int partIndexForAttachment(int index) => attachmentPartIndices?[index] ?? part;

  bool get isEdited => edits.isNotEmpty;
  String? get url => text?.replaceAll("\n", " ").split(" ").firstWhereOrNull((String e) => e.hasUrl);
  String get fullText => sanitizeString([subject, text].where((e) => !isNullOrEmpty(e)).join("\n"));

  /// True when this part contains only images or videos with no text or subject.
  /// Used to determine whether adjacent parts can be collapsed into a gallery.
  bool get isMediaOnlyPart =>
      attachments.isNotEmpty &&
      text == null &&
      subject == null &&
      attachments.every((a) => a.mimeStart == 'image' || a.mimeStart == 'video');

  /// True when this part's attachments form a multi-item media gallery (>1 images/videos).
  /// Used to route the part to [MessageImageGallery] instead of [AttachmentHolder].
  bool get isMediaGallery =>
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
