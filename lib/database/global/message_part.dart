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

  /// For collection parts created by collapsing consecutive media-only parts,
  /// maps each attachment (by index) to its original message-part id.
  /// Null for non-collection parts or single-source-part collections.
  List<int>? attachmentPartIndices;

  /// Returns the original message-part id for the attachment at [index].
  /// Falls back to [part] if [attachmentPartIndices] is not set.
  int partIdForAttachment(int index) => attachmentPartIndices?[index] ?? part;

  /// Whether this bubble covers the raw message-part id [partId].
  ///
  /// For collapsed collections, [attachmentPartIndices] is the span of original
  /// ids; otherwise only [part] is covered. Collapsed bubbles set [part] to the
  /// first id in that span.
  bool coversPartId(int partId) {
    final span = attachmentPartIndices;
    if (span != null && span.isNotEmpty) return span.contains(partId);
    return part == partId;
  }

  /// Every raw message-part id this bubble covers: the collapsed span for collections, else just [part].
  /// Use for lookups keyed by part id (threads, reactions) so collapsed collections match all of their ids.
  Iterable<int> get coveredPartIds {
    final span = attachmentPartIndices;
    if (span != null && span.isNotEmpty) return span;
    return [part];
  }

  /// Collapses runs of consecutive media-only parts into one collection part for display.
  ///
  /// The collapsed part keeps the first raw id as [part] and records every attachment's original id in
  /// [attachmentPartIndices], so [coversPartId] / [coveredPartIds] still match reactions, threads and
  /// trailing-bubble checks against any id in the span. Non-media parts pass through unchanged.
  static List<MessagePart> collapseMediaCollections(List<MessagePart> parts) {
    final collapsed = <MessagePart>[];
    int i = 0;
    while (i < parts.length) {
      final current = parts[i];
      if (!current.isMediaOnlyPart) {
        collapsed.add(current);
        i++;
        continue;
      }

      final groupedAttachments = <Attachment>[...current.attachments];
      final groupedPartIndices = <int>[...List.filled(current.attachments.length, current.part)];
      int j = i + 1;
      while (j < parts.length) {
        final next = parts[j];
        if (!next.isMediaOnlyPart) break;
        groupedAttachments.addAll(next.attachments);
        groupedPartIndices.addAll(List.filled(next.attachments.length, next.part));
        j++;
      }

      if (groupedAttachments.length > 1) {
        collapsed.add(MessagePart(
          attachments: groupedAttachments,
          // First raw id is the bubble's part id; attachmentPartIndices holds the
          // full span. Trailing chrome uses MessageState.isTrailingMessagePart.
          part: current.part,
          shouldRedact: current.shouldRedact,
          mentions: const [],
          edits: const [],
          isUnsent: current.isUnsent,
          attachmentPartIndices: groupedPartIndices,
        ));
      } else {
        collapsed.add(current);
      }
      i = j;
    }
    return collapsed;
  }

  bool get isEdited => edits.isNotEmpty;
  String? get url => text?.replaceAll("\n", " ").split(" ").firstWhereOrNull((String e) => e.hasUrl);
  String get fullText => sanitizeString([subject, text].where((e) => !isNullOrEmpty(e)).join("\n"));

  /// True when this part contains only images or videos with no body text.
  /// Subject is allowed; it is display metadata, not a collapse barrier.
  /// Used to determine whether adjacent parts can be collapsed into a collection.
  bool get isMediaOnlyPart =>
      attachments.isNotEmpty &&
      text == null &&
      attachments.every((a) => a.mimeStart == 'image' || a.mimeStart == 'video');

  /// True when this part's attachments form a multi-item media collection (>1 images/videos).
  /// Routes the part to a collection layout (stack / collage / grid, see `resolveMediaCollectionLayout`)
  /// instead of a single [AttachmentHolder].
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
