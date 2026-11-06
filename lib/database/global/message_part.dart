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
    this.collectionItems,
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

  /// Genmoji: attachments sharing a part with text, each drawn at its U+FFFC in [text].
  bool get hasInlineAttachments => attachments.isNotEmpty && (text?.contains(objectReplacementChar) ?? false);

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

  /// For collection parts built by [collapseMediaCollections], maps each attachment (by index) to its
  /// original message-part id. Null for every part that didn't come out of a collapse.
  List<int>? attachmentPartIndices;

  /// For collection parts built by [collapseMediaCollections], one single-attachment part per attachment
  /// (by index). An attachment that was alone in its raw part reuses that raw part, so its flags
  /// ([shouldRedact], [isUnsent]) stay live; the rest carry their source part's flags. Null otherwise.
  List<MessagePart>? collectionItems;

  /// Returns the original message-part id for the attachment at [index].
  /// Falls back to [part] if [attachmentPartIndices] is not set.
  int partIdForAttachment(int index) => attachmentPartIndices?[index] ?? part;

  /// The single-attachment part for the attachment at [index] of this collection: what a collection card
  /// hands to [AttachmentHolder] and the per-card popup. Prefer this over building a part per build, so the
  /// same instance comes back until the message's parts change.
  MessagePart itemPartFor(int index) =>
      collectionItems?[index] ??
      MessagePart(
        part: partIdForAttachment(index),
        attachments: [attachments[index]],
        shouldRedact: shouldRedact,
        isUnsent: isUnsent,
      );

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
  /// trailing-bubble checks against any id in the span. It also gets [collectionItems], one part per
  /// attachment. Non-media parts pass through unchanged.
  ///
  /// Every call builds new collection parts. In the conversation view read [MessageState.displayParts], which
  /// memoizes this so widgets keyed on part identity don't rebuild on every tick.
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

      final groupedAttachments = <Attachment>[];
      final groupedPartIndices = <int>[];
      final items = <MessagePart>[];
      int j = i;
      while (j < parts.length) {
        final next = parts[j];
        if (!next.isMediaOnlyPart) break;
        groupedAttachments.addAll(next.attachments);
        groupedPartIndices.addAll(List.filled(next.attachments.length, next.part));
        items.addAll(next.attachments.length == 1
            ? [next]
            : next.attachments.map((a) => MessagePart(
                  part: next.part,
                  attachments: [a],
                  shouldRedact: next.shouldRedact,
                  isUnsent: next.isUnsent,
                )));
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
          collectionItems: items,
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
  ///
  /// Deliberately doesn't require `text == null` like [isMediaOnlyPart]: [AttachmentHolder] renders only the first
  /// attachment, so a raw part holding several images *and* text still shows every image here. Its text isn't
  /// rendered either way (text and attachments in one part is a known gap, not handled by this branch).
  bool get isMediaCollection =>
      attachments.length > 1 &&
      !hasInlineAttachments &&
      attachments.every((a) => a.mimeStart == 'image' || a.mimeStart == 'video');
}

class Mention {
  Mention({
    this.mentionedAddress,
    this.range = const [],
  });

  String? mentionedAddress;
  List<int> range;
}
