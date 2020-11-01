import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

class AttachmentDownloader {
  final _stream = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _stream.stream;

  int _currentChunk = 0;
  int _totalChunks = 0;
  int _chunkSize = 500; // Default to 500
  List<int> _currentBytes = <int>[];
  String _guid = "";
  Function _cb;
  Attachment _attachment;
  String _title;
  Chat _chat;
  bool _createNotification;
  int _socketProcessId;
  Function _onComplete;
  Function _onError;

  double get progress => (_currentChunk) / _totalChunks;
  Attachment get attachment => _attachment;

  AttachmentDownloader(Attachment attachment,
      {bool createNotification = false, Function onComplete, Function onError}) {
    // Set default chunk size based on the current settings
    _chunkSize = SettingsManager().settings.chunkSize * 1024;
    _attachment = attachment;
    _createNotification = createNotification;
    _onComplete = onComplete;
    _onError = onError;

    String appDocPath = SettingsManager().appDocDir.path;
    String pathName =
        "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";
    if (File(pathName).existsSync()) {
      return;
    }

    fetchAttachment(attachment);
  }

  getChunkRecursive(
      String guid, int index, int total, List<int> currentBytes, Function cb) {
    _currentBytes = currentBytes;

    // if (index <= total) {
    Map<String, dynamic> params = new Map();
    params["identifier"] = guid;
    params["start"] = index * _chunkSize;
    params["chunkSize"] = _chunkSize;
    params["compress"] = false;
    SocketManager().sendMessage("get-attachment-chunk", params,
        (attachmentResponse) async {
      if (attachmentResponse['status'] != 200) {
        cb(null);
        _onError(attachmentResponse);
        return;
      }
      if (!attachmentResponse.containsKey("data") ||
          attachmentResponse["data"] == null) {
        await cb(currentBytes);
      }

      Uint8List bytes = base64Decode(attachmentResponse["data"]);
      currentBytes.addAll(bytes.toList());
      if (bytes.length == _chunkSize) {
        // Calculate some stats
        double progress = ((index + 1) / total).clamp(0, 1).toDouble();
        // updateProgressNotif(progress);
        String progressStr = (progress * 100).round().toString();
        debugPrint("Progress: $progressStr% of the attachment");

        // Update the progress in stream
        _stream.sink.add({"Progress": progress});
        _currentBytes = currentBytes;
        _currentChunk = index + 1;

        // Get the next chunk
        getChunkRecursive(guid, index + 1, total, currentBytes, cb);
      } else {
        debugPrint("Finished fetching attachment");
        await cb(currentBytes);
      }
    }, reason: "Attachment downloader " + attachment.guid);
    // }
  }

  // void updateProgressNotif(double _progress) {
  //   if (_createNotification && _attachment.mimeType != null) {
  //     NotificationManager().updateProgressNotification(
  //       _attachment.id,
  //       _progress,
  //     );
  //   }
  // }

  void fetchAttachment(Attachment attachment) async {
    if (SocketManager().attachmentDownloaders.containsKey(attachment.guid)) {
      _stream.close();
      return;
    }
    int numOfChunks = (attachment.totalBytes / _chunkSize).ceil();
    debugPrint("Fetching $numOfChunks attachment chunks");
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();

    _guid = attachment.guid;
    _totalChunks = numOfChunks;

    // if (_createNotification &&
    //     _attachment.mimeType != null &&
    //     _message != null) {
    //   _chat = await Message.getChat(_message);
    //   _title = await getFullChatTitle(_chat);
    //   NotificationManager().createProgressNotification(
    //     _title,
    //     "Downloading Attachment",
    //     _chat.guid,
    //     _attachment.id,
    //     _chat.id,
    //     0.0,
    //   );
    // }

    _cb = (List<int> data) async {
      stopwatch.stop();
      debugPrint(
          "Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

      if (data == null || data.length == 0) {
        SocketManager().finishDownloader(attachment.guid);
        // NotificationManager().finishProgressWithAttachment(
        //     "Failed to download", _attachment.id, _attachment);
        _stream.sink.addError("unable to load");
        _stream.close();
        return;
      }

      File file;
      String fileName = attachment.transferName;
      String appDocPath = SettingsManager().appDocDir.path;
      String pathName = "$appDocPath/attachments/${attachment.guid}/$fileName";

      // If there is data, save it to a file
      if (data != null && data.length > 0) {
        Uint8List bytes = Uint8List.fromList(data);
        file = await writeToFile(bytes, pathName);
      }

      // Finish the downloader
      SocketManager().finishDownloader(attachment.guid);
      if (_onComplete != null) _onComplete();

      // Add attachment to sink based on if we got data
      if (data == null || data.length == 0) {
        _stream.sink.addError("unable to load");
      } else if (file != null) {
        _stream.sink.add(file);
      }

      // Close the stream
      _stream.close();
    };

    // Only donwload if auto download is on or the wifi stars align
    if ((await AttachmentHelper.canAutoDownload())) {
      SocketManager().addAttachmentDownloader(attachment.guid, this);
    }

    getChunkRecursive(attachment.guid, 0, numOfChunks, [], _cb);
  }

  Future<File> writeToFile(Uint8List data, String path) async {
    File file = await new File(path).create(recursive: true);
    return file.writeAsBytes(data);
  }
}
