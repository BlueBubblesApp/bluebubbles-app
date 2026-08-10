import 'package:bluebubbles/utils/file_utils.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

/// Download state for attachments
enum AttachmentDownloadState {
  /// Waiting in queue to start downloading
  queued,

  /// Currently downloading from server
  downloading,

  /// Download complete, now processing (EXIF extraction, format conversion, etc.)
  processing,

  /// Download and processing complete
  complete,

  /// Download or processing failed
  error,
}

/// Get an instance of our [AttachmentDownloadService]
// ignore: non_constant_identifier_names
AttachmentDownloadService AttachmentDownloader = Get.isRegistered<AttachmentDownloadService>()
    ? Get.find<AttachmentDownloadService>()
    : Get.put(AttachmentDownloadService());

class AttachmentDownloadService extends GetxService {
  final RxList<String> downloaders = <String>[].obs;
  final Map<String, List<AttachmentDownloadController>> _downloaders = {};

  bool _isActiveState(AttachmentDownloadState state) {
    return state == AttachmentDownloadState.queued ||
        state == AttachmentDownloadState.downloading ||
        state == AttachmentDownloadState.processing;
  }

  void _removeGuidFromQueueMap(String guid) {
    downloaders.remove(guid);
    final emptyKeys = <String>[];
    for (final entry in _downloaders.entries) {
      entry.value.removeWhere((e) => e.attachment.guid == guid);
      if (entry.value.isEmpty) {
        emptyKeys.add(entry.key);
      }
    }

    for (final key in emptyKeys) {
      _downloaders.remove(key);
    }
  }

  AttachmentDownloadController? getController(String? guid) {
    if (guid == null) return null;

    // Drop stale queued references first so callers only ever get live work.
    _removeGuidFromQueueMap(guid);

    final registered = Get.isRegistered<AttachmentDownloadController>(tag: guid)
        ? Get.find<AttachmentDownloadController>(tag: guid)
        : null;
    if (registered == null || !_isActiveState(registered.state.value)) {
      if (registered != null && Get.isRegistered<AttachmentDownloadController>(tag: guid)) {
        Get.delete<AttachmentDownloadController>(tag: guid);
      }
      return null;
    }

    // Ensure queue map reflects the currently active controller instance.
    final chatGuid = registered.attachment.message.target?.chat.target?.guid ?? "unknown";
    _downloaders.putIfAbsent(chatGuid, () => []);
    if (!_downloaders[chatGuid]!.contains(registered)) {
      _downloaders[chatGuid]!.add(registered);
    }
    if (!downloaders.contains(guid)) {
      downloaders.add(guid);
    }

    return registered;
  }

  void clearControllerForGuid(String guid, {bool deleteRegistered = true}) {
    _removeGuidFromQueueMap(guid);
    if (Get.isRegistered<AttachmentDownloadController>(tag: guid)) {
      // Abort any in-flight request before dropping the registration -- otherwise
      // a still-running fetchAttachment() keeps writing to the same deterministic
      // `.part` path a freshly-started controller (or a redownload's file wipe)
      // will also touch, and whichever one loses the race hits a rename/delete on
      // a file the other side already moved out from under it.
      Get.find<AttachmentDownloadController>(tag: guid).cancel();
      if (deleteRegistered) {
        Get.delete<AttachmentDownloadController>(tag: guid);
      }
    }
  }

  AttachmentDownloadController startDownload(Attachment a,
      {Function(PlatformFile)? onComplete, Function? onError, bool forceFresh = false}) {
    final guid = a.guid;
    if (guid != null && forceFresh) {
      clearControllerForGuid(guid);
    }

    if (guid != null) {
      final existing = getController(guid);
      if (existing != null) {
        if (onComplete != null) existing.completeFuncs.add(onComplete);
        if (onError != null) existing.errorFuncs.add(onError);
        return existing;
      }
    }

    return Get.put(
        AttachmentDownloadController(
          attachment: a,
          onComplete: onComplete,
          onError: onError,
        ),
        tag: a.guid!);
  }

  void _addToQueue(AttachmentDownloadController downloader) {
    downloaders.add(downloader.attachment.guid!);
    final chatGuid = downloader.attachment.message.target?.chat.target?.guid ?? "unknown";
    if (_downloaders.containsKey(chatGuid)) {
      _downloaders[chatGuid]!.add(downloader);
    } else {
      _downloaders[chatGuid] = [downloader];
    }
    _fetchNext();
  }

  void _removeFromQueue(AttachmentDownloadController downloader) {
    downloaders.remove(downloader.attachment.guid!);
    final chatGuid = downloader.attachment.message.target?.chat.target?.guid ?? "unknown";
    _downloaders[chatGuid]?.removeWhere((e) => e.attachment.guid == downloader.attachment.guid);
    if (_downloaders[chatGuid]?.isEmpty ?? false) _downloaders.remove(chatGuid);
    Get.delete<AttachmentDownloadController>(tag: downloader.attachment.guid!);
    _fetchNext();
  }

  void _fetchNext() {
    final maxDownloads = SettingsSvc.settings.maxConcurrentDownloads.value;
    if (_downloaders.values.flattened.where((e) => e.state.value == AttachmentDownloadState.downloading).length <
        maxDownloads) {
      AttachmentDownloadController? activeChatDownloader;
      // first check if we have an active chat that needs downloads, if so prioritize that chat
      if (ChatsSvc.activeChat != null && _downloaders.containsKey(ChatsSvc.activeChat!.chat.guid)) {
        activeChatDownloader = _downloaders[ChatsSvc.activeChat!.chat.guid]!
            .firstWhereOrNull((e) => e.state.value == AttachmentDownloadState.queued);
        activeChatDownloader?.fetchAttachment();
      }
      // otherwise just grab a random attachment that needs fetching
      if (activeChatDownloader == null) {
        _downloaders.values.flattened
            .firstWhereOrNull((e) => e.state.value == AttachmentDownloadState.queued)
            ?.fetchAttachment();
      }
    }
  }
}

class AttachmentDownloadController extends GetxController {
  final Attachment attachment;
  final List<Function(PlatformFile)> completeFuncs = [];
  final List<Function> errorFuncs = [];
  final RxnNum progress = RxnNum();
  final Rxn<PlatformFile> file = Rxn<PlatformFile>();
  final Rx<AttachmentDownloadState> state = Rx<AttachmentDownloadState>(AttachmentDownloadState.queued);
  Stopwatch stopwatch = Stopwatch();
  CancelToken? _cancelToken;

  /// Guards against [fetchAttachment] running twice for this instance. Every
  /// caller (both branches of [AttachmentDownloadService._fetchNext]) already
  /// checks `state.value == queued` before calling, but that check and the
  /// synchronous `state.value = downloading` assignment below aren't the same
  /// operation -- if two call sites both observe `queued` in the same tick,
  /// they'd otherwise both proceed to issue their own GET for the same file.
  bool _fetchStarted = false;

  /// Set once this download has been failed, so the request-level `catchError`
  /// and the checks that follow it can't run the error path twice.
  bool _failed = false;

  AttachmentDownloadController({
    required this.attachment,
    Function(PlatformFile)? onComplete,
    Function? onError,
  }) {
    if (onComplete != null) completeFuncs.add(onComplete);
    if (onError != null) errorFuncs.add(onError);
  }

  @override
  void onInit() {
    AttachmentDownloader._addToQueue(this);
    super.onInit();
  }

  /// Aborts an in-flight request. Called when a newer controller for the same
  /// attachment is about to reuse this one's deterministic `.part` path (see
  /// [AttachmentDownloadService.clearControllerForGuid]).
  void cancel() {
    if (_cancelToken?.isCancelled == false) _cancelToken?.cancel('superseded');
  }

  /// Fails this download: drops any partial file, notifies the error callbacks,
  /// moves to [AttachmentDownloadState.error], and frees the queue slot.
  ///
  /// Every abnormal exit from [fetchAttachment] must come through here. A path
  /// that returns without it leaves the controller parked in a non-terminal
  /// state forever: the UI keeps rendering the downloading widget, the tap
  /// handler refuses to retry (it only retries from `error`), and — because
  /// [AttachmentDownloadService._fetchNext] counts `downloading` controllers
  /// against `maxConcurrentDownloads` (default 2) — the slot is never released,
  /// so two stranded downloads deadlock the queue for the whole session.
  Future<void> _failDownload(String? tempPath, String reason, {Object? error, StackTrace? trace}) async {
    if (_failed) return;
    _failed = true;

    Logger.error(
      "Attachment download failed for ${attachment.guid} ($reason)",
      error: error,
      trace: trace,
    );

    if (!kIsWeb && tempPath != null) {
      try {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
    }

    for (Function f in errorFuncs) {
      try {
        f.call();
      } catch (e, s) {
        Logger.error("Attachment download error callback threw", error: e, trace: s);
      }
    }

    state.value = AttachmentDownloadState.error;
    AttachmentDownloader._removeFromQueue(this);
  }

  Future<void> fetchAttachment() async {
    if (attachment.guid == null || attachment.guid!.contains("temp")) return;
    if (_fetchStarted) return;
    _fetchStarted = true;
    state.value = AttachmentDownloadState.downloading;
    stopwatch.start();
    _cancelToken = CancelToken();

    // Mark as not downloaded while downloading (handles re-downloads)
    attachment.isDownloaded = false;

    // For web, download to memory. For native platforms, write to disk.
    //
    // Native downloads stream into a temporary `.part` file and are renamed into the
    // final path only after being fully written (and post-processed). This preserves the
    // invariant "file exists at attachment.path <=> file is complete" — consumers like
    // AttachmentsSvc.getContent and the gallery's image-size prober treat file presence
    // as readiness, and decoding a partially-written image poisons Flutter's ImageCache
    // with a failure that sticks until the widget is disposed ("Failed to display image").
    final savePath = kIsWeb ? null : attachment.path;
    final tempPath = savePath == null ? null : "$savePath.part";

    var response = await HttpSvc.attachment
        .download(
      attachment.guid!,
      savePath: tempPath,
      cancelToken: _cancelToken,
      onReceiveProgress: (count, total) {
        // `attachment.totalBytes` is preferred on native because dio reports
        // -1 for `total` when the server omits Content-Length. Either can be
        // missing, so fall back to whichever is usable rather than asserting
        // one with `!` -- a throw here fails an otherwise fine download.
        final int denominator = kIsWeb ? total : (attachment.totalBytes ?? total);
        setProgress(denominator > 0 ? count / denominator : 0);
      },
    ).catchError((err, stack) async {
      await _failDownload(tempPath, "request failed", error: err, trace: stack);
      return Response(requestOptions: RequestOptions(path: ''));
    });

    if (_failed) return;

    Logger.info("Finished downloading attachment");
    if (response.statusCode != 200) {
      await _failDownload(tempPath, "server returned status ${response.statusCode}");
      return;
    }

    try {
      await _processDownloadedFile(response, savePath, tempPath);
    } catch (e, s) {
      await _failDownload(tempPath, "post-processing failed", error: e, trace: s);
      return;
    }

    if (_failed) return;

    // The download is complete and the state machine has said so. Everything
    // past this point is best-effort -- a failure here must not walk that back.
    for (Function f in completeFuncs) {
      try {
        f.call(file.value);
      } catch (e, s) {
        Logger.error("Attachment download completion callback threw", error: e, trace: s);
      }
    }

    // Finally, remove the downloader from queue
    AttachmentDownloader._removeFromQueue(this);

    try {
      await _runPostCompletionHandling();
    } catch (e, s) {
      Logger.error("Post-download handling failed for ${attachment.guid}", error: e, trace: s);
    }
  }

  /// Converts the finished response into the on-disk (or in-memory) file and
  /// marks this controller complete.
  ///
  /// Everything in here runs while the UI is showing "Processing...", so any
  /// throw that escapes it strands the controller in that state — hence the
  /// caller wrapping this in a try/catch that routes to [_failDownload].
  Future<void> _processDownloadedFile(Response response, String? savePath, String? tempPath) async {
    attachment.webUrl = response.requestOptions.path;
    stopwatch.stop();
    Logger.info("Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

    // Set processing state to show indeterminate spinner
    progress.value = 1.0;
    state.value = AttachmentDownloadState.processing;

    // Handle web-specific processing (bytes in memory)
    Uint8List? bytes;
    if (kIsWeb) {
      if (attachment.mimeType == "image/gif") {
        bytes = await fixSpeedyGifs(response.data);
      } else {
        bytes = response.data;
      }
      attachment.bytes = bytes;
    } else {
      // For native platforms, the temp file is fully written to disk.
      // Handle GIF optimization on the temp file so the rewrite is covered by the
      // atomic rename below.
      if (attachment.mimeType == "image/gif" && tempPath != null) {
        final fileBytes = await File(tempPath).readAsBytes();
        final optimizedBytes = await fixSpeedyGifs(fileBytes);
        await File(tempPath).writeAsBytes(optimizedBytes);
      }

      // Atomically move the completed file into its final path. Only now does
      // attachment.path exist, so readers can never observe partial content.
      // (moveFile drops to a copy when the two paths are on different volumes —
      // a save location on another drive — which readers can observe partially.)
      if (tempPath != null && savePath != null) {
        try {
          await moveFile(File(tempPath), savePath);
        } on PathNotFoundException {
          // The `.part` file is gone. cancel() closes most of this race, but a
          // download that had already finished writing (just not renamed yet)
          // when a newer request superseded it can still lose it. If savePath
          // exists, the newer request already won and renamed its own copy in
          // -- there's nothing left for this one to do. Otherwise this really
          // is a lost file, so fail the same way the request-level catchError
          // above does rather than letting this escape as an unhandled Future
          // rejection (fetchAttachment() is fired off without being awaited).
          if (!await File(savePath).exists()) {
            await _failDownload(tempPath, "temp file lost before rename");
            return;
          }
        }
      }
    }

    // Load image properties before displaying (so UI shows correct dimensions immediately)
    if (!kIsWeb && attachment.mimeStart == "image") {
      try {
        await AttachmentsSvc.loadImageProperties(attachment, actualPath: attachment.path);
      } catch (ex) {
        Logger.warn("Failed to load image properties", error: ex);
      }
    }

    // Create the PlatformFile
    file.value = PlatformFile(
      name: attachment.transferName!,
      path: kIsWeb ? null : attachment.path,
      size: kIsWeb ? bytes!.length : await File(attachment.path).length(),
      bytes: kIsWeb ? bytes : null,
    );

    // Mark attachment as downloaded and save to database
    attachment.isDownloaded = true;
    await attachment.saveAsync(attachment.message.target);

    // Mark as complete
    state.value = AttachmentDownloadState.complete;
  }

  /// Optional work that runs after the download has already been marked
  /// complete: mirroring bytes to disk on desktop, and the auto-save setting.
  Future<void> _runPostCompletionHandling() async {
    // Desktop-specific handling
    if (kIsDesktop && attachment.bytes != null) {
      File _file = await File(attachment.path).create(recursive: true);
      await _file.writeAsBytes(attachment.bytes!.toList());
    }

    // Auto-save handling
    if (SettingsSvc.settings.autoSave.value &&
        !kIsWeb &&
        !kIsDesktop &&
        !(attachment.isOutgoing ?? false) &&
        !(attachment.message.target?.isInteractive ?? false)) {
      if (attachment.mimeType?.startsWith("image") ?? false) {
        await AttachmentsSvc.saveToDisk(file.value!, isAutoDownload: true);
      } else if (file.value?.bytes != null) {
        await File(join(await FilesystemSvc.downloadsDirectory, file.value!.name)).writeAsBytes(file.value!.bytes!);
      }
    }
  }

  void setProgress(double value) {
    if (value.isNaN) {
      value = 0;
    } else if (value.isInfinite) {
      value = 1.0;
    } else if (value.isNegative) {
      value = 0;
    }

    progress.value = value.clamp(0, 1);
  }
}
