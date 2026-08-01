import 'dart:io';

import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/generated/objectbox.g.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/isolates/global_isolate.dart';
import 'package:bluebubbles/services/isolates/isolate_event.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart' as p;

class StorageActions {
  /// data keys: 'chatGuid' (String?), 'ageFilter' (String — StorageAgeFilter
  /// name), 'runId' (String), 'attachmentsPath' (String), 'urlPreviewsPath'
  /// (String) — the paths are passed in because FilesystemSvc is a main-thread
  /// singleton, not available inside the isolate the same way.
  static Future<Map<String, dynamic>> analyze(Map<String, dynamic> data) async {
    final chatGuid = data['chatGuid'] as String?;
    final ageFilter = StorageAgeFilter.values.byName(data['ageFilter'] as String);
    final runId = data['runId'] as String;
    final attachmentsPath = data['attachmentsPath'] as String;
    final urlPreviewsPath = data['urlPreviewsPath'] as String?;
    final filtered = chatGuid != null || ageFilter != StorageAgeFilter.all;

    _emit(runId, StorageAnalysisStage.indexing, 0, 0, 0);
    final guids = _indexAttachments(chatGuid: chatGuid, ageFilter: ageFilter);
    _emit(runId, StorageAnalysisStage.indexing, 1, 1, 0);

    // Preview images are content-addressed and shared by every message linking
    // the same page, so they belong to no single chat or date — skipped
    // entirely on a narrowed scan rather than reported partially, exactly as
    // orphan folders are.
    final previews = filtered || urlPreviewsPath == null
        ? const _DirTotals(bytes: 0, files: 0)
        : _measureFlatDir(urlPreviewsPath);

    final result = await _walkFilesystem(
      attachmentsPath: attachmentsPath,
      guids: guids,
      filtered: filtered,
      runId: runId,
      seed: {StorageSegmentType.urlPreviews: previews},
    );

    _emit(runId, StorageAnalysisStage.finalizing, 1, 1, result.totalBytes);

    return StorageAnalysisResult(
      segments: result.segments,
      chatGuid: chatGuid,
      ageFilter: ageFilter,
      computedAt: DateTime.now(),
      globalScanValid: !filtered,
    ).toMap();
  }

  /// Total size and file count of a flat directory. Used for caches that are
  /// not organised per attachment GUID.
  static _DirTotals _measureFlatDir(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return const _DirTotals(bytes: 0, files: 0);

    var bytes = 0;
    var files = 0;
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      try {
        bytes += entity.lengthSync();
        files++;
      } catch (_) {
        // Raced with a writer; skip.
      }
    }
    return _DirTotals(bytes: bytes, files: files);
  }

  /// Stage 1 — one filtered ObjectBox query, a single `PropertyQuery` column.
  /// Never hydrates `Attachment` entities.
  ///
  /// Only the GUID is pulled here — **not** `mimeType` alongside it. ObjectBox's
  /// `PropertyQuery.find()` docs state results come back "in no particular
  /// order", so two separate `find()` calls on the same `Query` (one per
  /// property) are not guaranteed to return rows in the same relative order.
  /// Zipping guid[i] with mime[i] on that assumption silently pairs each
  /// attachment with an unrelated one's mime type — this was the actual cause
  /// of the "everything shows up as Videos" bug. Mime classification instead
  /// happens per-file, by extension, during the stage-2 walk (see
  /// `_segmentForFile`) — exactly the fallback the plan called for.
  static Set<String> _indexAttachments({
    required String? chatGuid,
    required StorageAgeFilter ageFilter,
  }) {
    final cutoff = ageFilter.cutoffMillis();
    final qb = Database.attachments.query();
    final mq = qb.link(
      Attachment_.message,
      cutoff != null ? Message_.dateCreated.lessThan(cutoff) : null,
    );
    if (chatGuid != null) {
      mq.link(Message_.chat, Chat_.guid.equals(chatGuid));
    }
    final q = qb.build();
    try {
      return q.property(Attachment_.guid).find(replaceNullWith: '').toSet();
    } finally {
      q.close();
    }
  }

  /// Stage 2 — walk `attachments/<guid>/` folders and classify every file.
  static Future<_WalkResult> _walkFilesystem({
    required String attachmentsPath,
    required Set<String> guids,
    required bool filtered,
    required String runId,
    Map<StorageSegmentType, _DirTotals> seed = const {},
  }) async {
    final root = Directory(attachmentsPath);
    if (!await root.exists()) {
      return _WalkResult(
        segments: _buildSegments(
          bytesByType: {for (final e in seed.entries) e.key: e.value.bytes},
          filesByType: {for (final e in seed.entries) e.key: e.value.files},
          filtered: filtered,
        ),
        totalBytes: seed.values.fold(0, (a, t) => a + t.bytes),
      );
    }

    final allFolders = root.listSync().whereType<Directory>().toList();
    final targetFolders = filtered ? allFolders.where((d) => guids.contains(p.basename(d.path))) : allFolders;
    final folderList = targetFolders.toList();
    final total = folderList.length;

    final bytesByType = <StorageSegmentType, int>{for (final e in seed.entries) e.key: e.value.bytes};
    final filesByType = <StorageSegmentType, int>{for (final e in seed.entries) e.key: e.value.files};
    void addBytes(StorageSegmentType t, int bytes) => bytesByType[t] = (bytesByType[t] ?? 0) + bytes;
    void addFile(StorageSegmentType t) => filesByType[t] = (filesByType[t] ?? 0) + 1;

    var processed = 0;
    var lastEmitted = 0;
    final stopwatch = Stopwatch()..start();
    var bytesSoFar = seed.values.fold(0, (a, t) => a + t.bytes);

    for (final folder in folderList) {
      final guid = p.basename(folder.path);
      final isOrphan = !guids.contains(guid);

      final files = folder.listSync().whereType<File>().toList();
      final originals = _findOriginals(files);
      final classified = _classifyOriginals(originals);

      for (final f in files) {
        final len = f.lengthSync();
        bytesSoFar += len;
        if (isOrphan) {
          addBytes(StorageSegmentType.orphaned, len);
          addFile(StorageSegmentType.orphaned);
          continue;
        }
        final info = classified[f];
        if (info != null) {
          addBytes(info.segment, len);
          // The Live Photo `.mov` companion's bytes fold into the still
          // image's segment (below) but don't add a second file to the
          // count — one Live Photo is one attachment, not two.
          if (info.countsAsFile) addFile(info.segment);
        } else {
          addBytes(StorageSegmentType.thumbnailsAndConversions, len);
          addFile(StorageSegmentType.thumbnailsAndConversions);
        }
      }

      processed++;
      if (processed - lastEmitted >= 100 || stopwatch.elapsedMilliseconds >= 150) {
        _emit(runId, StorageAnalysisStage.scanning, processed, total, bytesSoFar);
        lastEmitted = processed;
        stopwatch.reset();
      }
    }
    // Always emit a final 100% regardless of the throttle gate.
    _emit(runId, StorageAnalysisStage.scanning, total, total, bytesSoFar);

    return _WalkResult(
      segments: _buildSegments(bytesByType: bytesByType, filesByType: filesByType, filtered: filtered),
      totalBytes: bytesSoFar,
    );
  }

  /// Global segments (orphans, link previews) are hidden entirely on a
  /// filtered scan, since they were never measured — see [analyze].
  static List<StorageSegment> _buildSegments({
    required Map<StorageSegmentType, int> bytesByType,
    required Map<StorageSegmentType, int> filesByType,
    required bool filtered,
  }) {
    return StorageSegmentType.values
        .map((t) => StorageSegment(type: t, bytes: bytesByType[t] ?? 0, fileCount: filesByType[t] ?? 0))
        .where((s) => s.fileCount > 0 || !filtered)
        .toList();
  }

  /// A conversion is named `<original>.<ext>` alongside the original it was
  /// derived from, so the sibling check is what distinguishes it from a real
  /// attachment that merely happens to be a PNG or JPEG. `.jpg` is included
  /// because HEIC now converts to JPEG rather than PNG.
  static bool _isConvertedImage(String name, List<File> siblings) {
    for (final ext in const ['.png', '.jpg']) {
      if (!name.endsWith(ext)) continue;
      final base = name.substring(0, name.length - ext.length);
      if (siblings.any((f) => p.basename(f.path) == base)) return true;
    }
    return false;
  }

  /// Every regenerable file: thumbnails, partial downloads, format
  /// conversions, and the downsampled inline previews (`<name>.preview.qNN.jpg`,
  /// plus any `.tmp.jpg` left behind by a generation killed mid-write — the
  /// `.preview.` check covers those).
  ///
  /// The preview suffix has to be checked explicitly — `.preview.q90.jpg` ends
  /// in `.jpg` but has no sibling matching its stripped base, so
  /// [_isConvertedImage] does not catch it and previews would otherwise count
  /// as originals and survive "delete thumbnails & conversions".
  static bool _isDerived(String name, List<File> siblings) {
    return name.endsWith('.thumbnail') ||
        name.endsWith('.part') ||
        name.endsWith('.tmp') ||
        name.contains('.preview.') ||
        _isConvertedImage(name, siblings);
  }

  /// A folder can hold **more than one** real, non-derivative file — not just
  /// "the original" plus cache junk. The main case: Live Photos. The `.mov`
  /// companion is written as a plain sibling of the still image, named
  /// `<transferName-without-ext>.mov` (see `LivePhotoMixin.getLivePhotoPath()`
  /// — it is not a separate `Attachment`/GUID). That file isn't derived from
  /// anything, so it qualifies as an "original" here too — see
  /// `_classifyOriginals` for how its bytes get attributed.
  static List<File> _findOriginals(List<File> files) {
    return files.where((f) => !_isDerived(p.basename(f.path), files)).toList();
  }

  /// Maps each "original" file to the segment its bytes count toward.
  ///
  /// A Live Photo's `.mov` companion is folded into the **same** segment as
  /// its still image — one Live Photo is one attachment (original size +
  /// live-video size, combined), not a separate Photos entry and a separate
  /// Videos entry. `countsAsFile: false` on the `.mov` keeps the file-count
  /// stat from double-counting it as a second file.
  ///
  /// A lone `.mov` with no non-`.mov` sibling in the folder is a genuine
  /// video attachment (not a Live Photo companion) and classifies normally.
  static Map<File, ({StorageSegmentType segment, bool countsAsFile})> _classifyOriginals(List<File> originals) {
    final movFiles = originals.where((f) => p.basename(f.path).toLowerCase().endsWith('.mov')).toList();
    final nonMovFiles = originals.where((f) => !movFiles.contains(f)).toList();

    final result = <File, ({StorageSegmentType segment, bool countsAsFile})>{};

    if (nonMovFiles.isEmpty) {
      for (final f in movFiles) {
        result[f] = (segment: _segmentForFile(f), countsAsFile: true);
      }
      return result;
    }

    for (final f in nonMovFiles) {
      result[f] = (segment: _segmentForFile(f), countsAsFile: true);
    }
    final primarySegment = _segmentForFile(nonMovFiles.first);
    for (final f in movFiles) {
      result[f] = (segment: primarySegment, countsAsFile: false);
    }
    return result;
  }

  /// data keys: 'chatGuid' (String?), 'ageFilter' (String), 'segments'
  /// (List<String> — StorageSegmentType names to delete), 'attachmentsPath'
  /// (String), 'urlPreviewsPath' (String).
  ///
  /// Despite the name this deletes any selected segment, including the
  /// non-attachment ones. Re-runs stage 1 rather than trusting GUIDs the UI has
  /// been holding — the DB may have changed (new messages arrived) since the
  /// last Analyze.
  static Future<Map<String, dynamic>> deleteAttachments(Map<String, dynamic> data) async {
    final chatGuid = data['chatGuid'] as String?;
    final ageFilter = StorageAgeFilter.values.byName(data['ageFilter'] as String);
    final segments = (data['segments'] as List).map((e) => StorageSegmentType.values.byName(e as String)).toSet();
    final attachmentsPath = data['attachmentsPath'] as String;
    final urlPreviewsPath = data['urlPreviewsPath'] as String?;

    final guids = _indexAttachments(chatGuid: chatGuid, ageFilter: ageFilter);

    var bytesFreed = 0;
    var filesDeleted = 0;
    final resetGuids = <String>[];

    // Link preview images live outside the attachment tree and reference no
    // attachment row. The hashes recorded on each message are deliberately
    // left in place: `MetadataHelper.resolveCachedImage` checks the file
    // exists and re-fetches on demand, so a cleared preview simply reloads the
    // next time it is shown — subject to the same sender policy as any other
    // fetch.
    if (segments.contains(StorageSegmentType.urlPreviews) && urlPreviewsPath != null) {
      final removed = await _deleteFlatDir(urlPreviewsPath);
      bytesFreed += removed.bytes;
      filesDeleted += removed.files;
    }

    final root = Directory(attachmentsPath);
    if (!await root.exists()) {
      return {
        'bytesFreed': bytesFreed,
        'filesDeleted': filesDeleted,
        'attachmentsReset': 0,
        'guids': <String>[],
      };
    }

    final deleteOrphans = segments.contains(StorageSegmentType.orphaned);
    final deleteDerivedOnly = segments.contains(StorageSegmentType.thumbnailsAndConversions);
    // Global segments (orphans, link previews) are handled separately and must
    // not make this true on their own, or a previews-only selection would walk
    // the attachment tree looking for matches it can never find.
    final deleteOriginals =
        segments.any((s) => s != StorageSegmentType.thumbnailsAndConversions && !s.isGlobal);

    for (final folder in root.listSync().whereType<Directory>()) {
      final guid = p.basename(folder.path);
      final isOrphan = !guids.contains(guid);

      if (isOrphan) {
        if (!deleteOrphans) continue;
        bytesFreed += _dirSize(folder);
        filesDeleted += folder.listSync().whereType<File>().length;
        await folder.delete(recursive: true);
        continue;
      }

      final folderFiles = folder.listSync().whereType<File>().toList();
      final classified = _classifyOriginals(_findOriginals(folderFiles));
      // Same combined segment mapping the analyze walk uses (Live Photo
      // `.mov` folded into its still image's segment) — so "delete Photos"
      // correctly sweeps a Live Photo folder even though it physically
      // contains a .mov, and a folder isn't matched twice under two
      // different segments for what's really one attachment.
      final matchesSelectedType = deleteOriginals && classified.values.any((info) => segments.contains(info.segment));

      if (matchesSelectedType) {
        // Whole-folder delete — catches thumbnails, conversions, .part, and
        // the Live Photo .mov companion in one pass. Broader than the
        // 5-file list in redownloadAttachment (attachments_service.dart:360),
        // which is the point: nothing regenerable survives.
        bytesFreed += _dirSize(folder);
        filesDeleted += folder.listSync().whereType<File>().length;
        await folder.delete(recursive: true);
        resetGuids.add(guid);
      } else if (deleteDerivedOnly) {
        // Original stays; only regenerable siblings go.
        final files = folder.listSync().whereType<File>().toList();
        for (final f in files) {
          final name = p.basename(f.path);
          if (_isDerived(name, files)) {
            bytesFreed += f.lengthSync();
            filesDeleted++;
            await f.delete();
          }
        }
        // Original file untouched → isDownloaded stays true, no DB reset for this guid.
      }
    }

    if (resetGuids.isNotEmpty) {
      Database.runInTransaction(TxMode.write, () {
        for (final guid in resetGuids) {
          final row = Database.attachments.query(Attachment_.guid.equals(guid)).build().findFirst();
          if (row == null) continue;
          row.isDownloaded = false;
          // Must match the keys loadImageProperties actually writes, or the
          // reset silently fails to force reprocessing on next view.
          row.metadata
            ?..remove('_orientation_processed')
            ..remove('_orientation')
            ..remove('_raw_width')
            ..remove('_raw_height');
          row.height = null;
          row.width = null;
          row.exif = null;
          Database.attachments.put(row);
        }
      });
    }

    return {
      'bytesFreed': bytesFreed,
      'filesDeleted': filesDeleted,
      'attachmentsReset': resetGuids.length,
      'guids': resetGuids,
    };
  }

  static int _dirSize(Directory d) => d.listSync().whereType<File>().fold(0, (a, f) => a + f.lengthSync());

  /// Deletes every file directly inside [path], keeping the directory itself.
  static Future<_DirTotals> _deleteFlatDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return const _DirTotals(bytes: 0, files: 0);

    var bytes = 0;
    var files = 0;
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final size = entity.lengthSync();
        await entity.delete();
        bytes += size;
        files++;
      } catch (_) {
        // Deleted underneath us, or locked; skip it.
      }
    }
    return _DirTotals(bytes: bytes, files: files);
  }

  /// Classifies by file extension (via `mime_type`'s `mime()`, the same
  /// lookup `Attachment.fromMap` uses to backfill a missing server mime type)
  /// rather than the DB `mimeType` column — see `_indexAttachments` for why.
  static StorageSegmentType _segmentForFile(File file) => _segmentForMime(mime(p.basename(file.path)));

  static StorageSegmentType _segmentForMime(String? mime) {
    if (mime == null) return StorageSegmentType.other;
    if (mime.startsWith('image/')) return StorageSegmentType.photos;
    if (mime.startsWith('video/')) return StorageSegmentType.videos;
    if (mime.startsWith('audio/')) return StorageSegmentType.audio;
    if (mime.startsWith('application/pdf') || mime.startsWith('text/')) return StorageSegmentType.documents;
    return StorageSegmentType.other;
  }

  static void _emit(String runId, StorageAnalysisStage stage, int processed, int total, int bytes) {
    IsolateEventEmitter.emit(IsolateEvent.storageAnalysisProgress, {
      'runId': runId,
      'stage': stage.name,
      'processed': processed,
      'total': total,
      'bytes': bytes,
    });
  }
}

/// Size and file count of a flat cache directory.
class _DirTotals {
  final int bytes;
  final int files;
  const _DirTotals({required this.bytes, required this.files});
}

class _WalkResult {
  final List<StorageSegment> segments;
  final int totalBytes;
  const _WalkResult({required this.segments, required this.totalBytes});
}
