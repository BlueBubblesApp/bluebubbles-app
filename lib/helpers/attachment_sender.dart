import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'dart:typed_data';

import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';

class AttachmentSender {
  final _stream = StreamController<double>.broadcast();

  Stream<double> get stream => _stream.stream;

  int _totalChunks = 0;
  int _chunkSize = 500;
  Chat _chat;
  // String _tempGuid;

  File _attachment;
  String _attachmentGuid;
  List<int> _imageBytes;
  String _text;
  String _attachmentName;
  Attachment messageAttachment;
  Message sentMessage;
  Message messageWithText;
  double progress = 0.0;

  String get guid => _attachmentGuid;

  AttachmentSender(
    File attachment,
    Chat chat,
    String text,
  ) {

    // Set default chunk size to what is set in the settings
    _chunkSize = SettingsManager().settings.chunkSize * 1024;
    _chat = chat;
    _attachmentGuid = "temp-${randomString(8)}";
    _text = text;
    _attachment = attachment;
  }

  // resumeChunkingAfterDisconnect() {
  //     debugPrint("restarting chunking");
  //     sendChunkRecursive(_guid, _currentchunk, _totalchunks, _currentbytes,
  //         _chunksize * 1024, _cb);
  // }

  sendChunkRecursive(int index, int total, String tempGuid) {
    // if (index < ) {
    Map<String, dynamic> params = new Map();
    params["guid"] = _chat.guid;
    params["tempGuid"] = tempGuid;
    params["message"] = _text;
    params["attachmentGuid"] = _attachmentGuid;
    params["attachmentChunkStart"] = index;
    List<int> chunk = <int>[];
    for (int i = index; i < index + _chunkSize; i++) {
      if (i == _imageBytes.length) break;
      chunk.add(_imageBytes[i]);
    }
    params["hasMore"] = index + _chunkSize < _imageBytes.length;
    params["attachmentName"] = _attachmentName;
    params["attachmentData"] = base64Encode(chunk);
    debugPrint(chunk.length.toString() + "/" + _imageBytes.length.toString());
    SocketManager().sendMessage("send-message-chunk", params, (data) async {
      Map<String, dynamic> response = data;
      debugPrint(data.toString());
      if (response['status'] == 200) {
        if (index + _chunkSize < _imageBytes.length) {
          progress = index / _imageBytes.length;
          if (!_stream.isClosed) _stream.sink.add(progress);
          sendChunkRecursive(index + _chunkSize, total, tempGuid);
        } else {
          progress = index / _imageBytes.length;
          if (!_stream.isClosed) _stream.sink.add(progress);
          debugPrint("no more to send");
          SocketManager().finishSender(_attachmentGuid);
          LifeCycleManager().finishDownloader();
        }
      } else {
        debugPrint("failed to send");
        String tempGuid = sentMessage.guid;
        sentMessage.guid = sentMessage.guid
            .replaceAll("temp", "error-${response['error']['message']}");
        sentMessage.error = response['status'] == 400
            ? MessageError.BAD_REQUEST.code
            : MessageError.SERVER_ERROR.code;

        await Message.replaceMessage(tempGuid, sentMessage);
        NewMessageManager().addMessage(_chat, sentMessage, outgoing: true);
        if (messageWithText != null) {
          tempGuid = messageWithText.guid;
          messageWithText.guid = messageWithText.guid
              .replaceAll("temp", "error-${response['error']['message']}");
          messageWithText.error = response['status'] == 400
              ? MessageError.BAD_REQUEST.code
              : MessageError.SERVER_ERROR.code;

          await Message.replaceMessage(tempGuid, sentMessage);
          NewMessageManager().addMessage(_chat, sentMessage, outgoing: true);
        }
        // sendChunkRecursive(index, total, tempGuid);
        SocketManager().finishSender(_attachmentGuid);
        LifeCycleManager().finishDownloader();
        _stream.sink.addError("failed to send");
        _stream.close();
      }
    });
  }
  //{"identifier":"160E8D64-0A22-400D-93BE-7D4C19346F1F","start":1048576,"chunkSize":524288,"compress":false}

  Future<void> send() async {
    _attachmentName = basename(_attachment.path);
    _imageBytes = await _attachment.readAsBytes();

    int numOfChunks = (_imageBytes.length / _chunkSize).ceil();

    messageAttachment = Attachment(
      guid: _attachmentGuid,
      totalBytes: _imageBytes.length,
      isOutgoing: true,
      isSticker: false,
      hideAttachment: false,
      uti: "public.jpg",
      transferName: _attachmentName,
      mimeType: mime(_attachmentName),
      width: mime(_attachmentName).startsWith("image")
          ? ImageSizGetter.getSize(_attachment).width
          : null,
      height: mime(_attachmentName).startsWith("image")
          ? ImageSizGetter.getSize(_attachment).height
          : null,
    );

    sentMessage = Message(
      guid: _attachmentGuid,
      text: "",
      dateCreated: DateTime.now(),
      hasAttachments: true,
      attachments: [messageAttachment]
    );

    if (_text != "") {
      messageWithText = Message(
        guid: "temp-${randomString(8)}",
        text: _text,
        dateCreated: DateTime.now(),
        hasAttachments: false,
      );
    }

    String appDocPath = SettingsManager().appDocDir.path;
    String pathName =
        "$appDocPath/attachments/${messageAttachment.guid}/$_attachmentName";
    File file = await new File(pathName).create(recursive: true);
    await file.writeAsBytes(Uint8List.fromList(_imageBytes));
    debugPrint("saved attachment with temp guid ${messageAttachment.guid}");

    await sentMessage.save();
    await _chat.addMessage(sentMessage);
    NewMessageManager().addMessage(_chat, sentMessage, outgoing: true);
    if (messageWithText != null) {
      await _chat.addMessage(messageWithText);
      NewMessageManager().addMessage(_chat, messageWithText, outgoing: true);
    }

    _totalChunks = numOfChunks;
    SocketManager().addAttachmentSender(this);
    sendChunkRecursive(
        0,
        _totalChunks,
        messageWithText == null
            ? "temp-${randomString(8)}"
            : messageWithText.guid);
  }
}
