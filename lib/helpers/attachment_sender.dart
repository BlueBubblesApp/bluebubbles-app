import 'dart:async';
import 'dart:convert';

import 'dart:io';
import 'dart:math';

import 'dart:typed_data';

import 'package:bluebubble_messages/helpers/contstants.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/life_cycle_manager.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';

class AttachmentSender {
  final _stream = StreamController<double>.broadcast();

  Stream<double> get stream => _stream.stream;

  int _totalChunks = 0;
  int _chunkSize = 512;
  Chat _chat;
  // String _tempGuid;
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

    sendAttachment(attachment);
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
        NewMessageManager().updateWithMessage(_chat, sentMessage);
        if (messageWithText != null) {
          tempGuid = messageWithText.guid;
          messageWithText.guid = messageWithText.guid
              .replaceAll("temp", "error-${response['error']['message']}");
          messageWithText.error = response['status'] == 400
              ? MessageError.BAD_REQUEST.code
              : MessageError.SERVER_ERROR.code;

          await Message.replaceMessage(tempGuid, sentMessage);
          NewMessageManager().updateWithMessage(_chat, sentMessage);
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

  Future<void> sendAttachment(File attachment) async {
    _attachmentName = basename(attachment.path);
    _imageBytes = await attachment.readAsBytes();

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
          ? ImageSizGetter.getSize(attachment).width
          : null,
      height: mime(_attachmentName).startsWith("image")
          ? ImageSizGetter.getSize(attachment).height
          : null,
    );

    sentMessage = Message(
      guid: _attachmentGuid,
      text: "",
      dateCreated: DateTime.now(),
      hasAttachments: true,
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

    await messageAttachment.save(sentMessage);
    await _chat.save();
    await _chat.addMessage(sentMessage);
    NewMessageManager().updateWithMessage(_chat, sentMessage);
    if (messageWithText != null) {
      await messageWithText.save();
      await _chat.save();
      await _chat.addMessage(messageWithText);
      NewMessageManager().updateWithMessage(_chat, messageWithText);
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
