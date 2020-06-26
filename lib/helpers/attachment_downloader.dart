import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'dart:typed_data';

import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';

class AttachmentDownloader {
  final _stream = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _stream.stream;

  int _currentChunk = 0;
  int _totalChunks = 0;
  int _chunkSize = 512; // Default to 512kb
  List<int> _currentBytes = <int>[];
  String _guid = "";
  Function _cb;
  Attachment _attachment;

  double get progress => (_currentChunk) / _totalChunks;
  Attachment get attachment => _attachment;

  AttachmentDownloader(Attachment attachment) {
    // Set default chunk size based on the current settings
    _chunkSize = SettingsManager().settings.chunkSize * 1024;
    _attachment = attachment;

    fetchAttachment(attachment);
  }

  resumeChunkingAfterDisconnect() {
    if (_stream.isClosed) return;
    if (_guid != "" && _cb != null) {
      debugPrint("restarting chunking " + _currentBytes.length.toString());
      getChunkRecursive(_guid, _currentChunk, _totalChunks, _currentBytes, _cb);
    } else {
      debugPrint("could not restart chunking");
    }
  }

  getChunkRecursive(
      String guid, int index, int total, List<int> currentBytes, Function cb) {
    _currentBytes = currentBytes;

    if (index <= total) {
      Map<String, dynamic> params = new Map();
      params["identifier"] = guid;
      params["start"] = index * _chunkSize;
      params["chunkSize"] = _chunkSize;
      params["compress"] = false;
      SocketManager().socket.sendMessage(
          "get-attachment-chunk", jsonEncode(params), (chunk) async {
        Map<String, dynamic> attachmentResponse = jsonDecode(chunk);
        if (!attachmentResponse.containsKey("data") ||
            attachmentResponse["data"] == null) {
          await cb(currentBytes);
        }

        Uint8List bytes = base64Decode(attachmentResponse["data"]);
        currentBytes.addAll(bytes.toList());
        if (index < total) {
          // Calculate some stats
          double progress = (index + 1) / total;
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
      });
    }
  }

  void fetchAttachment(Attachment attachment) {
    int numOfChunks = (attachment.totalBytes / _chunkSize).ceil();
    debugPrint("Fetching $numOfChunks attachment chunks");
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();

    _guid = attachment.guid;
    _totalChunks = numOfChunks;
    _cb = (List<int> data) async {
      stopwatch.stop();
      debugPrint(
          "Attachment downloaded in ${stopwatch.elapsedMilliseconds} ms");

      if (data.length == 0) {
        _stream.sink.addError("unable to load");
        return;
      }

      String fileName = attachment.transferName;
      String appDocPath = SettingsManager().appDocDir.path;
      String pathName = "$appDocPath/attachments/${attachment.guid}/$fileName";
      Uint8List bytes = Uint8List.fromList(data);

      File file = await writeToFile(bytes, pathName);
      SocketManager().finishDownloader(attachment.guid);
      LifeCycleManager().finishDownloader();
      _stream.sink.add(file);
      _stream.close();
    };

    SocketManager().addAttachmentDownloader(attachment.guid, this);
    LifeCycleManager().startDownloader();
    SocketManager().disconnectCallback(() {
      _currentChunk = 0;
      _totalChunks = 0;
      _currentBytes = <int>[];
      _guid = "";
      _cb = null;
      fetchAttachment(attachment);
    }, attachment.guid);

    getChunkRecursive(attachment.guid, 0, numOfChunks, [], _cb);
  }

  Future<File> writeToFile(Uint8List data, String path) async {
    File file = await new File(path).create(recursive: true);
    return file.writeAsBytes(data);
  }
}
