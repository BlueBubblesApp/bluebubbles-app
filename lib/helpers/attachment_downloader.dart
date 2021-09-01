import 'dart:io';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
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
  final Rxn<File> file = Rxn<File>();
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
    Logger.instance.log("Fetching $numOfChunks attachment chunks");
    stopwatch.start();
    getChunkRecursive(attachment.guid!, 0, numOfChunks, []);
  }

  void getChunkRecursive(String guid, int index, int total, List<int> currentBytes) {
    // if (index <= total) {
    Map<String, dynamic> params = new Map();
    params["identifier"] = guid;
    params["start"] = index * chunkSize;
    params["chunkSize"] = chunkSize;
    params["compress"] = false;
    SocketManager().sendMessage("get-attachment-chunk", params, (attachmentResponse) async {
      if (attachmentResponse['status'] != 200 ||
          (attachmentResponse.containsKey("error") && attachmentResponse["error"] != null)) {
        File file = new File(attachment.getPath());
        if (await file.exists()) {
          await file.delete();
        }

        if (onError != null) onError!.call();

        error.value = true;
        Get.find<AttachmentDownloadService>().removeFromQueue(this);
        return;
      }

      int? numBytes = attachmentResponse["byteLength"];

      if (numBytes == chunkSize) {
        // Calculate some stats
        double progress = ((index + 1) / total).clamp(0, 1).toDouble();
        Logger.instance.log("Progress: ${(progress * 100).round()}% of the attachment");

        // Update the progress in stream
        setProgress(progress);

        // Get the next chunk
        getChunkRecursive(guid, index + 1, total, currentBytes);
      } else {
        Logger.instance.log("Finished fetching attachment");
        stopwatch.stop();
        Logger.instance.log("Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

        try {
          // Compress the attachment
          await AttachmentHelper.compressAttachment(attachment, attachment.getPath());
          await attachment.update();
        } catch (ex) {
          // So what if it crashes here.... I don't care...
        }

        File downloadedFile = new File(attachment.getPath());

        // Finish the downloader
        Get.find<AttachmentDownloadService>().removeFromQueue(this);
        if (onComplete != null) onComplete!();

        // Add attachment to sink based on if we got data
        file.value = downloadedFile;
      }
    }, reason: "Attachment downloader " + attachment.guid!, path: attachment.getPath());
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
