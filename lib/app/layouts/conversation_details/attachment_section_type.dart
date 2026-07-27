import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';

/// Attachment categories shown in conversation details and the attachments page.
enum AttachmentSectionType {
  media,
  links,
  locations,
  documents,
}

/// Max items shown per section on the conversation details preview.
const int kAttachmentPreviewLimit = 6;

/// Horizontal inset for attachment section list/grid content.
int attachmentSectionHorizontalPadding({required bool fullPage, required bool iOS, bool expressive = false}) {
  if (expressive) return 16;
  if (fullPage) return iOS ? 12 : 8;
  return iOS ? 20 : 10;
}

EdgeInsets attachmentSectionListPadding({
  required bool fullPage,
  required bool iOS,
  bool expressive = false,
  double top = 0,
  double bottom = 10,
}) {
  final inset = attachmentSectionHorizontalPadding(fullPage: fullPage, iOS: iOS, expressive: expressive).toDouble();
  return EdgeInsets.only(left: inset, right: inset, top: top, bottom: bottom);
}

/// Media grid column count by Material window size class (compact / medium / expanded),
/// used by the expressive attachment sections instead of `max(2, width ~/ 200)`.
int expressiveMediaCrossAxisCount(double width) {
  if (width < 600) return 2;
  if (width < 840) return 3;
  return 4;
}

enum MediaFilter {
  all,
  images,
  videos,
}

extension MediaFilterLabels on MediaFilter {
  String get label {
    switch (this) {
      case MediaFilter.all:
        return "All";
      case MediaFilter.images:
        return "Photos";
      case MediaFilter.videos:
        return "Videos";
    }
  }

  String get emptyMessage {
    switch (this) {
      case MediaFilter.all:
        return "No photos or videos";
      case MediaFilter.images:
        return "No photos";
      case MediaFilter.videos:
        return "No videos";
    }
  }
}

List<Attachment> filterMedia(List<Attachment> media, MediaFilter filter) {
  switch (filter) {
    case MediaFilter.all:
      return media;
    case MediaFilter.images:
      return media.where((e) => e.mimeStart == "image").toList();
    case MediaFilter.videos:
      return media.where((e) => e.mimeStart == "video").toList();
  }
}

enum MediaSenderFilterKind { any, fromYou, fromOthers, participant }

class MediaSenderFilter {
  final MediaSenderFilterKind kind;
  final Handle? participant;

  const MediaSenderFilter._(this.kind, this.participant);

  const MediaSenderFilter.any() : this._(MediaSenderFilterKind.any, null);
  const MediaSenderFilter.fromYou() : this._(MediaSenderFilterKind.fromYou, null);
  const MediaSenderFilter.fromOthers() : this._(MediaSenderFilterKind.fromOthers, null);
  const MediaSenderFilter.participant(Handle handle) : this._(MediaSenderFilterKind.participant, handle);

  bool get isActive => kind != MediaSenderFilterKind.any;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaSenderFilter && other.kind == kind && other.participant?.address == participant?.address;
  }

  @override
  int get hashCode => Object.hash(kind, participant?.address);
}

bool messageMatchesSenderFilter(Message message, MediaSenderFilter filter) {
  if (!filter.isActive) return true;

  switch (filter.kind) {
    case MediaSenderFilterKind.any:
      return true;
    case MediaSenderFilterKind.fromYou:
      return message.isFromMe == true;
    case MediaSenderFilterKind.fromOthers:
      return message.isFromMe != true;
    case MediaSenderFilterKind.participant:
      final participant = filter.participant;
      if (participant == null) return true;
      final messageHandle = message.handleRelation.target;
      if (messageHandle != null) {
        return messageHandle.address == participant.address ||
            (participant.originalROWID != null && messageHandle.originalROWID == participant.originalROWID);
      }
      return participant.originalROWID != null && message.handleId == participant.originalROWID;
  }
}

bool attachmentMatchesSenderFilter(Attachment attachment, MediaSenderFilter filter) {
  final message = attachment.message.target;
  if (message == null) return false;
  return messageMatchesSenderFilter(message, filter);
}

List<Message> applyMessageFilters(
  List<Message> messages, {
  required MediaSenderFilter senderFilter,
  DateTime? sinceDate,
}) {
  var result = messages;
  if (senderFilter.isActive) {
    result = result.where((e) => messageMatchesSenderFilter(e, senderFilter)).toList();
  }
  if (sinceDate != null) {
    result = result.where((e) {
      final created = e.dateCreated;
      if (created == null) return false;
      return !created.isBefore(sinceDate);
    }).toList();
  }
  return result;
}

List<Attachment> applyMediaFilters(
  List<Attachment> media, {
  required MediaFilter typeFilter,
  required MediaSenderFilter senderFilter,
  DateTime? sinceDate,
}) {
  var result = filterMedia(media, typeFilter);
  if (senderFilter.isActive) {
    result = result.where((e) => attachmentMatchesSenderFilter(e, senderFilter)).toList();
  }
  if (sinceDate != null) {
    result = result.where((e) {
      final created = e.message.target?.dateCreated;
      if (created == null) return false;
      return !created.isBefore(sinceDate);
    }).toList();
  }
  return result;
}

enum FileTypeFilter {
  all,
  documents,
  audio,
  other,
}

/// Which type chips to show in [showAttachmentFiltersSheet].
enum AttachmentFiltersTypeSection {
  none,
  media,
  files,
}

/// Shared filter state for attachment category pages.
class AttachmentFiltersState {
  final MediaFilter mediaFilter;
  final FileTypeFilter fileTypeFilter;
  final MediaSenderFilter senderFilter;
  final DateTime? sinceDate;

  const AttachmentFiltersState({
    this.mediaFilter = MediaFilter.all,
    this.fileTypeFilter = FileTypeFilter.all,
    this.senderFilter = const MediaSenderFilter.any(),
    this.sinceDate,
  });

  AttachmentFiltersState copyWith({
    MediaFilter? mediaFilter,
    FileTypeFilter? fileTypeFilter,
    MediaSenderFilter? senderFilter,
    DateTime? sinceDate,
    bool clearSinceDate = false,
  }) {
    return AttachmentFiltersState(
      mediaFilter: mediaFilter ?? this.mediaFilter,
      fileTypeFilter: fileTypeFilter ?? this.fileTypeFilter,
      senderFilter: senderFilter ?? this.senderFilter,
      sinceDate: clearSinceDate ? null : (sinceDate ?? this.sinceDate),
    );
  }

  bool hasActiveFilter(AttachmentFiltersTypeSection typeSection) {
    switch (typeSection) {
      case AttachmentFiltersTypeSection.media:
        return mediaFilter != MediaFilter.all || senderFilter.isActive || sinceDate != null;
      case AttachmentFiltersTypeSection.files:
        return fileTypeFilter != FileTypeFilter.all || senderFilter.isActive || sinceDate != null;
      case AttachmentFiltersTypeSection.none:
        return senderFilter.isActive || sinceDate != null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttachmentFiltersState &&
        other.mediaFilter == mediaFilter &&
        other.fileTypeFilter == fileTypeFilter &&
        other.senderFilter == senderFilter &&
        other.sinceDate == sinceDate;
  }

  @override
  int get hashCode => Object.hash(mediaFilter, fileTypeFilter, senderFilter, sinceDate);
}

FileTypeFilter classifyFileAttachment(Attachment attachment) {
  if (attachment.mimeStart == 'audio') return FileTypeFilter.audio;
  if (_isDocumentAttachment(attachment)) return FileTypeFilter.documents;
  return FileTypeFilter.other;
}

bool _isDocumentAttachment(Attachment attachment) {
  final mime = attachment.mimeType ?? '';
  if (mime.isEmpty) return false;

  if (attachment.mimeStart == 'text') {
    return !mime.contains('vcard') && !mime.contains('calendar');
  }

  return mime == 'application/pdf' ||
      mime == 'application/msword' ||
      mime == 'application/vnd.ms-excel' ||
      mime == 'application/vnd.ms-powerpoint' ||
      mime == 'application/rtf' ||
      mime.contains('wordprocessingml') ||
      mime.contains('spreadsheetml') ||
      mime.contains('presentationml');
}

List<Attachment> filterFilesByType(List<Attachment> files, FileTypeFilter filter) {
  if (filter == FileTypeFilter.all) return files;
  return files.where((e) => classifyFileAttachment(e) == filter).toList();
}

List<Attachment> applyFileFilters(
  List<Attachment> files, {
  required FileTypeFilter typeFilter,
  required MediaSenderFilter senderFilter,
  DateTime? sinceDate,
}) {
  var result = filterFilesByType(files, typeFilter);
  if (senderFilter.isActive) {
    result = result.where((e) => attachmentMatchesSenderFilter(e, senderFilter)).toList();
  }
  if (sinceDate != null) {
    result = result.where((e) {
      final created = e.message.target?.dateCreated;
      if (created == null) return false;
      return !created.isBefore(sinceDate);
    }).toList();
  }
  return result;
}

extension AttachmentSectionTypeLabels on AttachmentSectionType {
  /// ALL CAPS label for section headers on the conversation details screen.
  String get sectionLabel {
    switch (this) {
      case AttachmentSectionType.media:
        return "PHOTOS & VIDEOS";
      case AttachmentSectionType.links:
        return "LINKS";
      case AttachmentSectionType.locations:
        return "LOCATIONS";
      case AttachmentSectionType.documents:
        return "OTHER FILES";
    }
  }

  /// Title case label for the attachments page app bar.
  String get pageTitle {
    switch (this) {
      case AttachmentSectionType.media:
        return "Photos & Videos";
      case AttachmentSectionType.links:
        return "Links";
      case AttachmentSectionType.locations:
        return "Locations";
      case AttachmentSectionType.documents:
        return "Other Files";
    }
  }

  /// Sentence case label for expressive (Material/Samsung) section headers.
  String get expressiveSectionLabel {
    switch (this) {
      case AttachmentSectionType.media:
        return "Photos & videos";
      case AttachmentSectionType.links:
        return "Links";
      case AttachmentSectionType.locations:
        return "Locations";
      case AttachmentSectionType.documents:
        return "Files";
    }
  }
}
