import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class AttachmentDownloader {
  final Rx<Tuple3<num?, File?, bool>> attachmentData = Rx<Tuple3<num?, File?, bool>>(Tuple3(null, null, false));

  int _currentChunk = 0;
  int _totalChunks = 0;
  int _chunkSize = 500; // Default to 500
  late Function _cb;
  late Attachment _attachment;
  Function? _onComplete;

  double get progress => (_totalChunks == 0) ? 0 : (_currentChunk) / _totalChunks;

  Attachment get attachment => _attachment;

  AttachmentDownloader(Attachment attachment, {Function? onComplete, Function? onError, bool autoFetch = true}) {
    // Set default chunk size based on the current settings
    _chunkSize = SettingsManager().settings.chunkSize.value * 1024;
    _attachment = attachment;
    _onComplete = onComplete;

    if (File(_attachment.getPath()).existsSync()) {
      return;
    }

    if (autoFetch) fetchAttachment(attachment);
  }

  getChunkRecursive(String guid, int index, int total, List<int> currentBytes, Function cb) {
    // if (index <= total) {
    Map<String, dynamic> params = new Map();
    params["identifier"] = guid;
    params["start"] = index * _chunkSize;
    params["chunkSize"] = _chunkSize;
    params["compress"] = false;
    SocketManager().sendMessage("get-attachment-chunk", params, (attachmentResponse) async {
      if (attachmentResponse['status'] != 200 ||
          (attachmentResponse.containsKey("error") && attachmentResponse["error"] != null)) {
        File file = new File(attachment.getPath());
        if (await file.exists()) {
          await file.delete();
        }

        // Finish the downloader
        SocketManager().finishDownloader(attachment.guid!);
        if (_onComplete != null) _onComplete!();

        attachmentData.value = Tuple3(null, null, true);
        attachmentData.close();
        return;
      }

      int? numBytes = attachmentResponse["byteLength"];

      if (numBytes == _chunkSize) {
        // Calculate some stats
        double progress = ((index + 1) / total).clamp(0, 1).toDouble();
        String progressStr = (progress * 100).round().toString();
        debugPrint("Progress: $progressStr% of the attachment");

        // Update the progress in stream
        setProgress(progress);
        _currentChunk = index + 1;

        // Get the next chunk
        getChunkRecursive(guid, index + 1, total, currentBytes, cb);
      } else {
        debugPrint("Finished fetching attachment");
        await cb.call();
      }
    }, reason: "Attachment downloader " + attachment.guid!, path: _attachment.getPath());
  }

  Future<void> fetchAttachment(Attachment attachment) async {
    if (attachment.guid == null) return;
    if (SocketManager().attachmentDownloaders.containsKey(attachment.guid)) {
      attachmentData.close();
      return;
    }
    int numOfChunks = (attachment.totalBytes! / _chunkSize).ceil();
    debugPrint("Fetching $numOfChunks attachment chunks");
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();

    _totalChunks = numOfChunks;

    _cb = () async {
      stopwatch.stop();
      debugPrint("Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

      try {
        // Compress the attachment
        await AttachmentHelper.compressAttachment(attachment, attachment.getPath());
        await attachment.update();
      } catch (ex) {
        // So what if it crashes here.... I don't care...
      }

      File file = new File(attachment.getPath());

      // Finish the downloader
      SocketManager().finishDownloader(attachment.guid!);
      if (_onComplete != null) _onComplete!();

      // Add attachment to sink based on if we got data
      attachmentData.value = Tuple3(1, file, false);
      // Close the stream
      attachmentData.close();
    };

    SocketManager().addAttachmentDownloader(attachment.guid!, this);

    getChunkRecursive(attachment.guid!, 0, numOfChunks, [], _cb);
  }

  void setProgress(double value) {
    if (value.isNaN) {
      value = 0;
    } else if (progress.isInfinite) {
      value = 1.0;
    } else if (progress.isNegative) {
      value = 0;
    }

    attachmentData.value = Tuple3(value.clamp(0, 1), null, false);
  }
}
