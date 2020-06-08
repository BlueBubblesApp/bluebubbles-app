import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'dart:typed_data';

import 'package:bluebubble_messages/helpers/utils.dart';
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
  // String _tempGuid;
  String _attachmentGuid;
  List<int> _imageBytes;
  String _text;
  String _attachmentName;

  double get progress => (_currentChunk) / _totalChunks;

  AttachmentSender(
    File attachment,
    Chat chat,
    String text,
  ) {
    _chat = chat;
    // _tempGuid = ;
    _attachmentGuid = "temp-${randomString(8)}";
    _text = text;
    sendAttachment(attachment);
  }

  // resumeChunkingAfterDisconnect() {
  //     debugPrint("restarting chunking");
  //     sendChunkRecursive(_guid, _currentchunk, _totalchunks, _currentbytes,
  //         _chunksize * 1024, _cb);
  // }

  sendChunkRecursive(int index, int total, int chunkSize, String tempGuid) {
    // if (index < ) {
    Map<String, dynamic> params = new Map();
    params["guid"] = _chat.guid;
    params["tempGuid"] = tempGuid;
    params["message"] = _text;
    params["attachmentGuid"] = _attachmentGuid;
    params["attachmentChunkStart"] = index;
    List<int> chunk = <int>[];
    for (int i = index; i < index + chunkSize; i++) {
      if (i == _imageBytes.length) break;
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
          sendChunkRecursive(index + chunkSize, total, chunkSize, tempGuid);
        } else {
          debugPrint("no more to send");
        }
      } else {
        debugPrint("failed to send");
      }
    });
  }

  Future<void> sendAttachment(File attachment) async {
    _attachmentName = basename(attachment.path);
    _imageBytes = await attachment.readAsBytes();

    int chunkSize = SettingsManager().settings.chunkSize * 1024;
    int numOfChunks = (_imageBytes.length / chunkSize).ceil();

    Attachment messageAttachment = Attachment(
      guid: _attachmentGuid,
      totalBytes: _imageBytes.length,
      isOutgoing: true,
      isSticker: false,
      hideAttachment: false,
      uti: "public.jpg",
      transferName: _attachmentName,
    );

    Message sentMessage = Message(
      guid: _attachmentGuid,
      text: "",
      dateCreated: DateTime.now(),
      hasAttachments: true,
    );

    Message messageWithText;

    if (_text != "") {
      messageWithText = Message(
        guid: "temp-${randomString(8)}",
        text: _text,
        dateCreated: DateTime.now(),
        hasAttachments: false,
      );
    }

    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/${messageAttachment.guid}/$_attachmentName";
    File file = await new File(pathName).create(recursive: true);
    await file.writeAsBytes(Uint8List.fromList(_imageBytes));
    debugPrint("saved attachment with temp guid ${messageAttachment.guid}");

    await sentMessage.save();
    await messageAttachment.save(sentMessage);
    await _chat.save();
    await _chat.addMessage(sentMessage);

    NewMessageManager().updateWithMessage(_chat, sentMessage);
    _totalChunks = numOfChunks;
    _chunkSize = chunkSize;
    sendChunkRecursive(
        0,
        _totalChunks,
        _chunkSize,
        messageWithText == null
            ? "temp-${randomString(8)}"
            : messageWithText.guid);
  }
}
