import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
import 'package:tuple/tuple.dart';

class AttachmentSender {
  final Rx<Tuple2<num?, bool>> attachmentData = Rx<Tuple2<num?, bool>>(Tuple2(null, false));

  int _totalChunks = 0;
  int _chunkSize = 500;
  late Chat _chat;

  // String _tempGuid;

  late File _attachment;
  late String _attachmentGuid;
  late List<int> _imageBytes;
  late String _text;
  String? _attachmentName;
  Attachment? messageAttachment;
  Message? sentMessage;
  Message? messageWithText;
  double progress = 0.0;

  String? get guid => _attachmentGuid;

  AttachmentSender(
    File attachment,
    Chat chat,
    String text,
  ) {
    // Set default chunk size to what is set in the settings
    _chunkSize = SettingsManager().settings.chunkSize.value * 1024;
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

  sendChunkRecursive(int index, int total, String? tempGuid) {
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
    if (index == 0) {
      debugPrint("(Sigabrt) Before sending first chunk");
    }
    SocketManager().sendMessage("send-message-chunk", params, (data) async {
      Map<String, dynamic> response = data;
      if (response['status'] == 200) {
        if (index + _chunkSize < _imageBytes.length) {
          progress = index / _imageBytes.length;
          attachmentData.value = Tuple2(progress, false);
          sendChunkRecursive(index + _chunkSize, total, tempGuid);
        } else {
          progress = index / _imageBytes.length;
          attachmentData.value = Tuple2(progress, false);
          SocketManager().finishSender(_attachmentGuid);
        }
      } else {
        debugPrint("failed to send");
        String? tempGuid = sentMessage!.guid;
        sentMessage!.guid = sentMessage!.guid!.replaceAll("temp", "error-${response['error']['message']}");
        sentMessage!.error = response['status'] == 400 ? MessageError.BAD_REQUEST.code : MessageError.SERVER_ERROR.code;

        await Message.replaceMessage(tempGuid, sentMessage);
        NewMessageManager().updateMessage(_chat, tempGuid!, sentMessage!);
        if (messageWithText != null) {
          tempGuid = messageWithText!.guid;
          messageWithText!.guid = messageWithText!.guid!.replaceAll("temp", "error-${response['error']['message']}");
          messageWithText!.error =
              response['status'] == 400 ? MessageError.BAD_REQUEST.code : MessageError.SERVER_ERROR.code;

          await Message.replaceMessage(tempGuid, messageWithText);
          NewMessageManager().updateMessage(_chat, tempGuid!, messageWithText!);
        }
        SocketManager().finishSender(_attachmentGuid);
        attachmentData.value = Tuple2(null, true);
        attachmentData.close();
      }
    });
  }

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
      width: mime(_attachmentName)!.startsWith("image") ? ImageSizeGetter.getSize(FileInput(_attachment)).width : null,
      height:
          mime(_attachmentName)!.startsWith("image") ? ImageSizeGetter.getSize(FileInput(_attachment)).height : null,
    );

    sentMessage = Message(
        guid: _attachmentGuid,
        text: "",
        dateCreated: DateTime.now(),
        hasAttachments: true,
        attachments: [messageAttachment]);

    if (_text != "") {
      messageWithText = Message(
        guid: "temp-${randomString(8)}",
        text: _text,
        dateCreated: DateTime.now(),
        hasAttachments: false,
      );
    }

    // Save the attachment to device
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName = "$appDocPath/attachments/${messageAttachment!.guid}/$_attachmentName";
    debugPrint("(Sigabrt) Before saving to device");
    File file = await new File(pathName).create(recursive: true);
    await file.writeAsBytes(Uint8List.fromList(_imageBytes));
    debugPrint("(Sigabrt) After saving to device");

    // Add the message to the chat.
    // This will save the message, attachments, and chat
    await _chat.addMessage(sentMessage!);
    NewMessageManager().addMessage(_chat, sentMessage!, outgoing: true);

    // If there is any text, save the text too
    if (messageWithText != null) {
      await _chat.addMessage(messageWithText!);
      NewMessageManager().addMessage(_chat, messageWithText!, outgoing: true);
    }

    _totalChunks = numOfChunks;
    SocketManager().addAttachmentSender(this);
    debugPrint("(Sigabrt) Before sending first chunk");
    sendChunkRecursive(0, _totalChunks, messageWithText == null ? "temp-${randomString(8)}" : messageWithText!.guid);
  }
}
