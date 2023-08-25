import 'package:bluebubbles/utils/file_utils.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

/// Get an instance of our [AttachmentDownloadService]
AttachmentDownloadService attachmentDownloader = Get.isRegistered<AttachmentDownloadService>()
    ? Get.find<AttachmentDownloadService>() : Get.put(AttachmentDownloadService());

class AttachmentDownloadService extends GetxService {
  int maxDownloads = 2;
  final RxList<String> downloaders = <String>[].obs;
  final Map<String, List<AttachmentDownloadController>> _downloaders = {};

  AttachmentDownloadController? getController(String? guid) {
    return _downloaders.values.flattened.firstWhereOrNull((element) => element.attachment.guid == guid);
  }

  AttachmentDownloadController startDownload(Attachment a, {Function(PlatformFile)? onComplete, Function? onError}) {
    return Get.put(AttachmentDownloadController(
      attachment: a,
      onComplete: onComplete,
      onError: onError,
    ), tag: a.guid!);
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
    _downloaders[chatGuid]!.removeWhere((e) => e.attachment.guid == downloader.attachment.guid);
    if (_downloaders[chatGuid]!.isEmpty) _downloaders.remove(chatGuid);
    Get.delete<AttachmentDownloadController>(tag: downloader.attachment.guid!);
    _fetchNext();
  }

  void _fetchNext() {
    if (_downloaders.values.flattened.where((e) => e.isFetching).length < maxDownloads) {
      AttachmentDownloadController? activeChatDownloader;
      // first check if we have an active chat that needs downloads, if so prioritize that chat
      if (cm.activeChat != null && _downloaders.containsKey(cm.activeChat!.chat.guid)) {
        activeChatDownloader = _downloaders[cm.activeChat!.chat.guid]!.firstWhereOrNull((e) => !e.isFetching);
        activeChatDownloader?.fetchAttachment();
      }
      // otherwise just grab a random attachment that needs fetching
      if (activeChatDownloader == null) {
        _downloaders.values.flattened.firstWhereOrNull((e) => !e.isFetching)?.fetchAttachment();
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
  final RxBool error = RxBool(false);
  Stopwatch stopwatch = Stopwatch();
  bool isFetching = false;

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
    attachmentDownloader._addToQueue(this);
    super.onInit();
  }

  Future<void> fetchAttachment() async {
    if (attachment.guid == null || attachment.guid!.contains("temp")) return;
    isFetching = true;
    stopwatch.start();
    var response = await http.downloadAttachment(attachment.guid!,
        onReceiveProgress: (count, total) => setProgress(kIsWeb ? (count / total) : (count / attachment.totalBytes!))).catchError((err) async {
      if (!kIsWeb) {
        File file = File(attachment.path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      for (Function f in errorFuncs) {
        f.call();
      }

      error.value = true;
      attachmentDownloader._removeFromQueue(this);
      return Response(requestOptions: RequestOptions(path: ''));
    });
    if (response.statusCode != 200) return;
    Uint8List bytes;
    if (attachment.mimeType == "image/gif") {
      bytes = await fixSpeedyGifs(response.data);
    } else {
      bytes = response.data;
    }
    if (!kIsWeb && !kIsDesktop) {
      await mcs.invokeMethod("download-file", {
        "data": bytes,
        "path": attachment.path,
      });
    }
    attachment.webUrl = response.requestOptions.path;
    Logger.info("Finished fetching attachment");
    stopwatch.stop();
    Logger.info("Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

    try {
      // Compress the attachment
      if (!kIsWeb) {
        await as.loadAndGetProperties(attachment, actualPath: attachment.path);
        attachment.save(null);
      }
    } catch (ex) {
      // So what if it crashes here.... I don't care...
    }

    // Finish the downloader
    attachmentDownloader._removeFromQueue(this);
    attachment.bytes = bytes;
    // Add attachment to sink based on if we got data

    file.value = PlatformFile(
      name: attachment.transferName!,
      path: kIsWeb ? null : attachment.path,
      size: bytes.length,
      bytes: bytes,
    );
    for (Function f in completeFuncs) {
      f.call(file.value);
    }
    if (kIsDesktop) {
      if (attachment.bytes != null) {
        File _file = await File(attachment.path).create(recursive: true);
        await _file.writeAsBytes(attachment.bytes!.toList());
      }
    }
    if (ss.settings.autoSave.value
        && !kIsWeb
        && !kIsDesktop
        && !(attachment.isOutgoing ?? false)
        && !(attachment.message.target?.isInteractive ?? false)) {
      String filePath = "/storage/emulated/0/Download/";
      if (attachment.mimeType?.startsWith("image") ?? false) {
        await as.saveToDisk(file.value!, isAutoDownload: true);
      } else if (file.value?.bytes != null) {
        await File(join(filePath, file.value!.name)).writeAsBytes(file.value!.bytes!);
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
