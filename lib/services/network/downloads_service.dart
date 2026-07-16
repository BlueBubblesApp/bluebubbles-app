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
    if (deleteRegistered && Get.isRegistered<AttachmentDownloadController>(tag: guid)) {
      Get.delete<AttachmentDownloadController>(tag: guid);
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

  Future<void> fetchAttachment() async {
    if (attachment.guid == null || attachment.guid!.contains("temp")) return;
    state.value = AttachmentDownloadState.downloading;
    stopwatch.start();

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
      onReceiveProgress: (count, total) => setProgress(kIsWeb ? (count / total) : (count / attachment.totalBytes!)),
    )
        .catchError((err) async {
      if (!kIsWeb && tempPath != null) {
        File file = File(tempPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      for (Function f in errorFuncs) {
        f.call();
      }

      state.value = AttachmentDownloadState.error;
      AttachmentDownloader._removeFromQueue(this);
      return Response(requestOptions: RequestOptions(path: ''));
    });

    Logger.info("Finished downloading attachment");
    if (response.statusCode != 200) {
      // Don't leave a lingering partial file behind on a failed request.
      if (tempPath != null) {
        try {
          final tempFile = File(tempPath);
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
      return;
    }

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
      if (tempPath != null && savePath != null) {
        await File(tempPath).rename(savePath);
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

    // Call completion callbacks while controller is still registered
    for (Function f in completeFuncs) {
      f.call(file.value);
    }

    // Finally, remove the downloader from queue
    AttachmentDownloader._removeFromQueue(this);

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
