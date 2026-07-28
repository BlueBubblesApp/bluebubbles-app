import 'package:collection/collection.dart';

enum StorageSegmentType {
  photos, videos, audio, documents, other,
  thumbnailsAndConversions,
  orphaned,
}

extension StorageSegmentTypeX on StorageSegmentType {
  /// Whether files in this segment map to a DB row that must be reset on delete.
  /// false only for [StorageSegmentType.thumbnailsAndConversions] (touches an existing row's
  /// derived files, not the tracked original) and [StorageSegmentType.orphaned] (no row at all).
  bool get resetsAttachmentRow => this != StorageSegmentType.orphaned;
}

class StorageSegment {
  final StorageSegmentType type;
  final int bytes;
  final int fileCount;
  const StorageSegment({required this.type, required this.bytes, required this.fileCount});

  factory StorageSegment.fromMap(Map<String, dynamic> json) => StorageSegment(
        type: StorageSegmentType.values.byName(json['type'] as String),
        bytes: json['bytes'] as int,
        fileCount: json['fileCount'] as int,
      );

  Map<String, dynamic> toMap() => {'type': type.name, 'bytes': bytes, 'fileCount': fileCount};
}

/// Result of a completed analysis. Immutable — a new analyze run produces a
/// new instance rather than mutating this one, so the controller can diff
/// "was this computed with the filters currently selected".
class StorageAnalysisResult {
  final List<StorageSegment> segments;
  final String? chatGuid; // null = all chats, mirrors the request
  final StorageAgeFilter ageFilter;
  final DateTime computedAt;

  /// false whenever [chatGuid] or [ageFilter] narrowed the scan — orphan
  /// folders can't be attributed to a chat or a date, so the walk skips
  /// orphan detection entirely rather than report a partial number.
  final bool orphanScanValid;

  const StorageAnalysisResult({
    required this.segments,
    required this.chatGuid,
    required this.ageFilter,
    required this.computedAt,
    required this.orphanScanValid,
  });

  int get totalBytes => segments.fold(0, (a, s) => a + s.bytes);
  int get totalFiles => segments.fold(0, (a, s) => a + s.fileCount);
  StorageSegment? segment(StorageSegmentType t) => segments.where((s) => s.type == t).firstOrNull;

  factory StorageAnalysisResult.fromMap(Map<String, dynamic> json) => StorageAnalysisResult(
        segments:
            (json['segments'] as List).map((e) => StorageSegment.fromMap(e as Map<String, dynamic>)).toList(),
        chatGuid: json['chatGuid'] as String?,
        ageFilter: StorageAgeFilter.values.byName(json['ageFilter'] as String),
        computedAt: DateTime.fromMillisecondsSinceEpoch(json['computedAt'] as int),
        orphanScanValid: json['orphanScanValid'] as bool,
      );

  Map<String, dynamic> toMap() => {
        'segments': segments.map((e) => e.toMap()).toList(),
        'chatGuid': chatGuid,
        'ageFilter': ageFilter.name,
        'computedAt': computedAt.millisecondsSinceEpoch,
        'orphanScanValid': orphanScanValid,
      };
}

/// "Older than N" — the inverse of chat-stats' StatsTimeframe, which means
/// "within the last N days". Do not reuse that enum; the semantics invert.
enum StorageAgeFilter { all, month1, months6, year1, years2, years3 }

extension StorageAgeFilterX on StorageAgeFilter {
  String get label => switch (this) {
        StorageAgeFilter.all => 'All Time',
        StorageAgeFilter.month1 => 'Older than 1 Month',
        StorageAgeFilter.months6 => 'Older than 6 Months',
        StorageAgeFilter.year1 => 'Older than 1 Year',
        StorageAgeFilter.years2 => 'Older than 2 Years',
        StorageAgeFilter.years3 => 'Older than 3 Years',
      };

  /// Epoch millis cutoff. Matching rows have `Message.dateCreated < cutoff`.
  /// `null` means no bound — every attachment qualifies.
  int? cutoffMillis({DateTime? now}) {
    if (this == StorageAgeFilter.all) return null;
    final days = switch (this) {
      StorageAgeFilter.month1 => 30,
      StorageAgeFilter.months6 => 182,
      StorageAgeFilter.year1 => 365,
      StorageAgeFilter.years2 => 730,
      StorageAgeFilter.years3 => 1095,
      StorageAgeFilter.all => throw StateError('unreachable'),
    };
    return (now ?? DateTime.now()).subtract(Duration(days: days)).millisecondsSinceEpoch;
  }
}

/// Mirrors the stages emitted over `IsolateEvent.storageAnalysisProgress`.
/// Order matters — [weight] values must sum to 1.0.
enum StorageAnalysisStage {
  indexing(0.10, 'Indexing attachments…'),
  scanning(0.85, 'Scanning files…'),
  finalizing(0.05, 'Finalizing…');

  const StorageAnalysisStage(this.weight, this.label);
  final double weight;
  final String label;

  double get startFraction {
    final i = StorageAnalysisStage.values.indexOf(this);
    return StorageAnalysisStage.values.take(i).fold(0.0, (a, s) => a + s.weight);
  }
}

/// Result of a completed [StorageActions.deleteAttachments] run.
class StorageDeleteResult {
  final int bytesFreed;
  final int filesDeleted;
  final int attachmentsReset;

  const StorageDeleteResult({
    required this.bytesFreed,
    required this.filesDeleted,
    required this.attachmentsReset,
  });

  factory StorageDeleteResult.fromMap(Map<String, dynamic> json) => StorageDeleteResult(
        bytesFreed: json['bytesFreed'] as int,
        filesDeleted: json['filesDeleted'] as int,
        attachmentsReset: json['attachmentsReset'] as int,
      );

  Map<String, dynamic> toMap() => {
        'bytesFreed': bytesFreed,
        'filesDeleted': filesDeleted,
        'attachmentsReset': attachmentsReset,
      };
}

/// Reactive progress state held by the controller. Rebuilt from each
/// `storageAnalysisProgress` event payload — see Task 03 for the emit side
/// and Task 04 for the runId-filtered apply side.
class StorageAnalysisProgress {
  final StorageAnalysisStage? stage; // null = idle, nothing running
  final int processed;
  final int total;
  final int bytesSoFar;

  const StorageAnalysisProgress.idle()
      : stage = null,
        processed = 0,
        total = 0,
        bytesSoFar = 0;

  const StorageAnalysisProgress({
    required this.stage,
    required this.processed,
    required this.total,
    required this.bytesSoFar,
  });

  double get fraction {
    final s = stage;
    if (s == null) return 0;
    final stageProgress = total == 0 ? 0.0 : processed / total;
    return s.startFraction + s.weight * stageProgress;
  }

  String get label => stage?.label ?? '';
}
