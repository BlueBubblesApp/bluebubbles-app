import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

class AttachmentDownloadService extends GetxService {
  int maxDownloads = 2;
  final RxList<String> downloaders = <String>[].obs;
  final List<AttachmentDownloadController> _downloaders = [];

  AttachmentDownloadController? getController(String? guid) {
    return _downloaders.firstWhereOrNull((element) => element.attachment.guid == guid);
  }

  void addToQueue(AttachmentDownloadController downloader) {
    downloaders.add(downloader.attachment.guid!);
    _downloaders.add(downloader);
    if (_downloaders.where((e) => e.isFetching).length < maxDownloads) {
      _downloaders.firstWhereOrNull((e) => !e.isFetching)?.fetchAttachment();
    }
  }

  void removeFromQueue(AttachmentDownloadController downloader) {
    downloaders.remove(downloader.attachment.guid!);
    _downloaders.removeWhere((e) => e.attachment.guid == downloader.attachment.guid);
    Get.delete<AttachmentDownloadController>(tag: downloader.attachment.guid!);
    if (_downloaders.where((e) => e.isFetching).length < maxDownloads) {
      _downloaders.firstWhereOrNull((e) => !e.isFetching)?.fetchAttachment();
    }
  }
}

class AttachmentDownloadController extends GetxController {
  final Attachment attachment;
  final Function? onComplete;
  final Function? onError;
  final RxnNum progress = RxnNum();
  final Rxn<PlatformFile> file = Rxn<PlatformFile>();
  final RxBool error = RxBool(false);
  int chunkSize = 500;
  Stopwatch stopwatch = Stopwatch();
  bool isFetching = false;

  AttachmentDownloadController({
    required this.attachment,
    this.onComplete,
    this.onError,
  });

  @override
  void onInit() {
    chunkSize = SettingsManager().settings.chunkSize.value * 1024;
    Get.find<AttachmentDownloadService>().addToQueue(this);
    super.onInit();
  }

  Future<void> fetchAttachment() async {
    if (attachment.guid == null) return;
    isFetching = true;
    int numOfChunks = (attachment.totalBytes! / chunkSize).ceil();
    Logger.info("Fetching $numOfChunks attachment chunks");
    stopwatch.start();
    var response = await api.downloadAttachment(attachment.guid!,
        onReceiveProgress: (count, total) => setProgress(kIsWeb ? (count / total) : (count / attachment.totalBytes!)));
    if (response.statusCode != 200) {
      if (!kIsWeb) {
        File file = File(attachment.getPath());
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (onError != null) onError!.call();

      error.value = true;
      Get.find<AttachmentDownloadService>().removeFromQueue(this);
      return;
    } else if (!kIsWeb && !kIsDesktop) {
      await MethodChannelInterface().invokeMethod("download-file", {
        "data": response.data,
        "path": attachment.getPath(),
      });
    }
    attachment.webUrl = response.requestOptions.path;
    Logger.info("Finished fetching attachment");
    stopwatch.stop();
    Logger.info("Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

    try {
      // Compress the attachment
      if (!kIsWeb) {
        await AttachmentHelper.compressAttachment(attachment, attachment.getPath());
        attachment.save(null);
      } else if (ChatManager().activeChat?.chatAttachments.firstWhereOrNull((e) => e.guid == attachment.guid) == null) {
        ChatManager().activeChat?.chatAttachments.add(attachment);
      }
    } catch (ex) {
      // So what if it crashes here.... I don't care...
    }

    // Finish the downloader
    Get.find<AttachmentDownloadService>().removeFromQueue(this);
    if (onComplete != null) onComplete!();
    attachment.bytes = response.data;
    // Add attachment to sink based on if we got data

    file.value = PlatformFile(
      name: attachment.transferName!,
      path: kIsWeb ? null : attachment.getPath(),
      size: response.data.length,
      bytes: response.data,
    );
    if (kIsDesktop) {
      if (attachment.bytes != null) {
        File _file = await File(attachment.getPath()).create(recursive: true);
        _file.writeAsBytesSync(attachment.bytes!.toList());
      }
    }
    if (SettingsManager().settings.autoSave.value && !kIsWeb && !kIsDesktop && !(attachment.isOutgoing ?? false)) {
      String filePath = "/storage/emulated/0/Download/";
      if (attachment.mimeType?.startsWith("image") ?? false) {
        await AttachmentHelper.saveToGallery(file.value!, showAlert: false);
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
