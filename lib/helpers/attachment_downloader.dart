import 'dart:convert';

import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';

class AttachmentDownloadService extends GetxService {
  int maxDownloads = 10;
  final List<String> downloaders = [];
  final List<AttachmentDownloadController> _downloaders = [];

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

  void fetchAttachment() {
    if (attachment.guid == null) return;
    isFetching = true;
    int numOfChunks = (attachment.totalBytes! / chunkSize).ceil();
    Logger.info("Fetching $numOfChunks attachment chunks");
    stopwatch.start();
    getChunkRecursive(attachment.guid!, 0, numOfChunks, []);
  }

  Future<void> getChunkRecursive(String guid, int index, int total, List<int> currentBytes) async {
    // if (index <= total) {
    Map<String, dynamic> params = new Map();
    params["identifier"] = guid;
    params["start"] = index * chunkSize;
    params["chunkSize"] = chunkSize;
    params["compress"] = false;
    if (kIsWeb) {
      var response = await api.downloadAttachment(attachment.guid!);
      Logger.info("Finished fetching attachment");
      stopwatch.stop();
      Logger.info("Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

      if (CurrentChat.activeChat?.chatAttachments.firstWhereOrNull((e) => e.guid == attachment.guid) ==
          null) {
        CurrentChat.activeChat?.chatAttachments.add(attachment);
      }

      // Finish the downloader
      Get.find<AttachmentDownloadService>().removeFromQueue(this);
      if (onComplete != null) onComplete!();
      attachment.bytes = response.data;
      // Add attachment to sink based on if we got data

      file.value = PlatformFile(
        name: attachment.transferName!,
        path: kIsWeb ? null : attachment.getPath(),
        size: total,
        bytes: response.data,
      );
      return;
    }
    SocketManager().sendMessage("get-attachment-chunk", params, (attachmentResponse) async {
      if (attachmentResponse['status'] != 200 ||
          (attachmentResponse.containsKey("error") && attachmentResponse["error"] != null)) {
        if (!kIsWeb) {
          File file = new File(attachment.getPath());
          if (await file.exists()) {
            await file.delete();
          }
        }

        if (onError != null) onError!.call();

        error.value = true;
        Get.find<AttachmentDownloadService>().removeFromQueue(this);
        return;
      }

      int? numBytes = attachmentResponse["byteLength"];

      if (numBytes == chunkSize && (progress.value ?? 0) < 1) {
        // Calculate some stats
        double progress = ((index + 1) / total).clamp(0, 1).toDouble();
        Logger.info("Progress: ${(progress * 100).round()}% of the attachment");

        // Update the progress in stream
        setProgress(progress);

        // Get the next chunk
        getChunkRecursive(guid, index + 1, total, currentBytes);
      } else {
        Logger.info("Finished fetching attachment");
        stopwatch.stop();
        Logger.info("Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

        try {
          // Compress the attachment
          if (!kIsWeb) {
            await AttachmentHelper.compressAttachment(attachment, attachment.getPath());
            await attachment.update();
          } else if (CurrentChat.activeChat?.chatAttachments.firstWhereOrNull((e) => e.guid == attachment.guid) ==
              null) {
            CurrentChat.activeChat?.chatAttachments.add(attachment);
          }
        } catch (ex) {
          // So what if it crashes here.... I don't care...
        }

        // Finish the downloader
        Get.find<AttachmentDownloadService>().removeFromQueue(this);
        if (onComplete != null) onComplete!();
        attachment.bytes = base64.decode(attachmentResponse['data']);
        // Add attachment to sink based on if we got data

        file.value = PlatformFile(
          name: attachment.transferName!,
          path: kIsWeb ? null : attachment.getPath(),
          size: total,
          bytes: base64.decode(attachmentResponse['data']),
        );
        if (kIsDesktop) {
          File _file = await File(attachment.getPath()).create(recursive: true);
          _file.writeAsBytesSync(base64.decode(attachmentResponse['data']));
        }
      }
    }, reason: "Attachment downloader " + attachment.guid!, path: kIsWeb ? "" : attachment.getPath());
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
