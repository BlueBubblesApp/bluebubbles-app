import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'dart:typed_data';

import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

class AttachmentSender {
  final _stream = StreamController<dynamic>.broadcast();

  Stream<dynamic> get stream => _stream.stream;

  int _currentChunk = 0;
  int _totalChunks = 0;
  int _chunkSize = 1;
  Chat _chat;
  String _tempGuid;
  String _attachmentGuid;
  List<int> _imageBytes;
  String _text;
  String _attachmentName;

  double get progress => (_currentChunk) / _totalChunks;

  AttachmentSender(
    File attachment,
    Chat chat,
    String tempGuid,
    String text,
    String attachmentGuid,
  ) {
    _chat = chat;
    _tempGuid = tempGuid;
    _attachmentGuid = attachmentGuid;
    _text = text;
    sendAttachment(attachment);
  }

  // resumeChunkingAfterDisconnect() {
  //     debugPrint("restarting chunking");
  //     sendChunkRecursive(_guid, _currentchunk, _totalchunks, _currentbytes,
  //         _chunksize * 1024, _cb);
  // }

  sendChunkRecursive(int index, int total, int chunkSize) {
    // if (index < ) {
    Map<String, dynamic> params = new Map();
    // params["start"] = index * chunkSize;
    // params["chunkSize"] = chunkSize;
    // params["compress"] = false;
    params["guid"] = _chat.guid;
    params["tempGuid"] = _tempGuid;
    params["message"] = _text;
    params["attachmentGuid"] = _attachmentGuid;
    params["attachmentChunkStart"] = index;
    List<int> chunk = <int>[];
    for (int i = index; i < index + chunkSize; i++) {
      if (i == _imageBytes.length) {
        debugPrint("reached max");
        break;
      }
      chunk.add(_imageBytes[i]);
    }
    params["hasMore"] = index + chunkSize < _imageBytes.length;
    params["attachmentName"] = _attachmentName;
    params["attachmentData"] = base64Encode(chunk);
    debugPrint(chunk.length.toString() + "/" + _imageBytes.length.toString());
    SocketManager().socket.sendMessage("send-message-chunk", jsonEncode(params),
        (data) {
      Map<String, dynamic> response = jsonDecode(data);
      debugPrint(data.toString());
      if (response['status'] == 200) {
        if (index + chunkSize < _imageBytes.length) {
          sendChunkRecursive(index + chunkSize, total, chunkSize);
        } else {
          debugPrint("no more to send");
        }
      } else {
        debugPrint("failed to send");
      }
    });
    //01 23 45 67 89
    //0  1  2  3  4
    // }
  }

  Future<void> sendAttachment(File attachment) async {
    _attachmentName = basename(attachment.path);
    _imageBytes = await attachment.readAsBytes();

    int chunkSize = SettingsManager().settings.chunkSize * 1024;
    debugPrint("getting attachment");
    int numOfChunks = (_imageBytes.length / chunkSize).ceil();
    debugPrint("num Of Chunks is $numOfChunks");
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();

    Message sentMessage = Message(
      guid: _tempGuid,
      text: _text,
      dateCreated: DateTime.now(),
      hasAttachments: true,
    );

    await sentMessage.save();
    await _chat.save();
    await _chat.addMessage(sentMessage);
    NewMessageManager().updateWithMessage(_chat, sentMessage);

    _totalChunks = numOfChunks;
    _chunkSize = chunkSize;

    // _cb = (List<int> data) async {
    //   stopwatch.stop();
    //   debugPrint("time elapsed is ${stopwatch.elapsedMilliseconds}");

    //   if (data.length == 0) {
    //     _stream.sink.addError("unable to load");
    //     return;
    //   }

    //   String fileName = attachment.transferName;
    //   String appDocPath = SettingsManager().appDocDir.path;
    //   String pathName = "$appDocPath/${attachment.guid}/$fileName";
    //   debugPrint(
    //       "length of array is ${data.length} / ${attachment.totalBytes}");
    //   Uint8List bytes = Uint8List.fromList(data);

    //   // _stream.sink.add(file);
    //   _stream.close();
    // };

    // SocketManager().addAttachmentDownloader(attachment.guid, this);
    // LifeCycleManager().startDownloader();
    // SocketManager().disconnectCallback(() {
    //   _currentChunk = 0;
    //   _totalChunks = 0;
    //   _chunkSize = 1;
    //   sendAttachment(attachment);
    // }, attachment.guid);
    sendChunkRecursive(0, _totalChunks, _chunkSize);
  }
}
