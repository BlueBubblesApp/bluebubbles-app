import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'dart:typed_data';

import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/singleton.dart';
import 'package:flutter/material.dart';

class AttachmentDownloader {
  final _stream = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _stream.stream;

  int _currentChunk = 0;
  int _totalChunks = 0;
  List<int> _currentBytes = <int>[];
  String _guid = "";
  Function _cb;
  int _chunkSize = 1;

  double get progress => (_currentChunk) / _totalChunks;

  AttachmentDownloader(Attachment attachment) {
    getImage(attachment);
  }

  resumeChunkingAfterDisconnect() {
    if (_guid != "" && _cb != null) {
      debugPrint("restarting chunking");
      getChunkRecursive(_guid, _currentChunk + 1, _totalChunks, _currentBytes,
          _chunkSize * 1024, _cb);
    } else {
      debugPrint("could not restart chunking");
    }
  }

  getChunkRecursive(String guid, int index, int total, List<int> currentBytes,
      int chunkSize, Function cb) {
    _guid = guid;
    _currentChunk = index;
    _totalChunks = total;
    _currentBytes = currentBytes;
    _cb = cb;
    _chunkSize = chunkSize;
    if (index <= total) {
      Map<String, dynamic> params = new Map();
      params["identifier"] = guid;
      params["start"] = index * chunkSize;
      params["chunkSize"] = chunkSize;
      params["compress"] = false;
      Singleton().socket.sendMessage("get-attachment-chunk", jsonEncode(params),
          (chunk) async {
        Map<String, dynamic> attachmentResponse = jsonDecode(chunk);
        if (!attachmentResponse.containsKey("data") ||
            attachmentResponse["data"] == null) {
          await cb(currentBytes);
        }

        Uint8List bytes = base64Decode(attachmentResponse["data"]);
        currentBytes.addAll(bytes.toList());
        if (index < total) {
          debugPrint("${(index + 1) / total * 100}% of the image");
          debugPrint("next start is ${index + 1} out of $total");
          _stream.sink.add({"Progress": (index + 1) / total as double});
          getChunkRecursive(
              guid, index + 1, total, currentBytes, chunkSize, cb);
        } else {
          debugPrint("finished getting image");
          await cb(currentBytes);
        }
      });
    }
  }

  void getImage(Attachment attachment) {
    int chunkSize = Singleton().settings.chunkSize * 1024;
    debugPrint("getting attachment");
    int numOfChunks = (attachment.totalBytes / chunkSize).ceil();
    debugPrint("num Of Chunks is $numOfChunks");
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    Singleton().addAttachmentDownloader(attachment.guid, this);
    Singleton()
        .disconnectCallback(resumeChunkingAfterDisconnect, attachment.guid);
    _cb = (List<int> data) async {
      stopwatch.stop();
      debugPrint("time elapsed is ${stopwatch.elapsedMilliseconds}");

      if (data.length == 0) {
        _stream.sink.addError("unable to load");
        return;
      }

      String fileName = attachment.transferName;
      String appDocPath = Singleton().appDocDir.path;
      String pathName = "$appDocPath/${attachment.guid}/$fileName";
      debugPrint(
          "length of array is ${data.length} / ${attachment.totalBytes}");
      Uint8List bytes = Uint8List.fromList(data);

      File file = await writeToFile(bytes, pathName);
      Singleton().finishDownloader(attachment.guid);
      _stream.sink.add(file);
    };
    getChunkRecursive(attachment.guid, 0, numOfChunks, [], chunkSize, _cb);
  }

  Future<File> writeToFile(Uint8List data, String path) async {
    File file = await new File(path).create(recursive: true);
    return file.writeAsBytes(data);
  }
}
