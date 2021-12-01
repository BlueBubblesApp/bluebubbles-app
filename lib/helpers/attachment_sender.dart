import 'dart:async';
import 'dart:convert';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:get/get.dart';
import 'package:mime_type/mime_type.dart';
import 'package:tuple/tuple.dart';

class AttachmentSender {
  final Rx<Tuple2<num?, bool>> attachmentData = Rx<Tuple2<num?, bool>>(Tuple2(null, false));

  int _totalChunks = 0;
  int _chunkSize = 500;
  late Chat _chat;

  // String _tempGuid;

  late PlatformFile _attachment;
  late String _attachmentGuid;
  late Uint8List _imageBytes;
  late String _text;
  String? _attachmentName;
  Attachment? messageAttachment;
  late Message sentMessage;
  Message? messageWithText;
  double progress = 0.0;

  String? get guid => _attachmentGuid;

  AttachmentSender(
    PlatformFile attachment,
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
  //     Logger.instance.log("restarting chunking");
  //     sendChunkRecursive(_guid, _currentchunk, _totalchunks, _currentbytes,
  //         _chunksize * 1024, _cb);
  // }

  sendChunkRecursive(int index, int total, String? tempGuid) {
    // if (index < ) {
    Map<String, dynamic> params = {};
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
    Logger.info(chunk.length.toString() + "/" + _imageBytes.length.toString());
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
        Logger.error("Failed to sendattachment");

        String? tempGuid = sentMessage.guid;
        sentMessage.guid = sentMessage.guid!.replaceAll("temp", "error-${response['error']['message']}");
        sentMessage.error =
            response['status'] == 400 ? MessageError.BAD_REQUEST.code : MessageError.SERVER_ERROR.code;

        sentMessage = await Message.replaceMessage(tempGuid, sentMessage);
        NewMessageManager().updateMessage(_chat, tempGuid!, sentMessage);
        if (messageWithText != null) {
          tempGuid = messageWithText!.guid;
          messageWithText!.guid = messageWithText!.guid!.replaceAll("temp", "error-${response['error']['message']}");
          messageWithText!.error =
              response['status'] == 400 ? MessageError.BAD_REQUEST.code : MessageError.SERVER_ERROR.code;

          await Message.replaceMessage(tempGuid, messageWithText!);
          NewMessageManager().updateMessage(_chat, tempGuid!, messageWithText!);
        }
        SocketManager().finishSender(_attachmentGuid);
        attachmentData.value = Tuple2(null, true);
        attachmentData.close();
      }
    });
  }

  Future<void> send() async {
    _attachmentName = _attachment.name;
    _imageBytes = _attachment.bytes ?? (await File(_attachment.path!).readAsBytes());

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
      width: mime(_attachmentName)!.startsWith("image")
          ? (await AttachmentHelper.getImageSizing(kIsWeb ? _attachment.name : _attachment.path ?? _attachment.name, bytes: _attachment.bytes)).width.toInt()
          : null,
      height: mime(_attachmentName)!.startsWith("image")
          ? (await AttachmentHelper.getImageSizing(kIsWeb ? _attachment.name : _attachment.path ?? _attachment.name, bytes: _attachment.bytes)).height.toInt()
          : null,
    );

    sentMessage = Message(
        guid: _attachmentGuid,
        text: "",
        dateCreated: DateTime.now(),
        hasAttachments: true,
        attachments: [messageAttachment],
        isFromMe: true,
        handleId: 0,
    );

    if (_text != "") {
      messageWithText = Message(
        guid: "temp-${randomString(8)}",
        text: _text,
        dateCreated: DateTime.now(),
        hasAttachments: false,
        isFromMe: true,
        handleId: 0,
      );
    }

    // Save the attachment to device
    if (!kIsWeb) {
      String appDocPath = SettingsManager().appDocDir.path;
      String pathName = "$appDocPath/attachments/${messageAttachment!.guid}/$_attachmentName";
      File file = await File(pathName).create(recursive: true);
      await file.writeAsBytes(_imageBytes);
    }

    // Add the message to the chat.
    // This will save the message, attachments, and chat
    await _chat.addMessage(sentMessage);
    NewMessageManager().addMessage(_chat, sentMessage, outgoing: true);

    // If there is any text, save the text too
    if (messageWithText != null) {
      await _chat.addMessage(messageWithText!);
      NewMessageManager().addMessage(_chat, messageWithText!, outgoing: true);
    }

    _totalChunks = numOfChunks;
    SocketManager().addAttachmentSender(this);
    sendChunkRecursive(0, _totalChunks, messageWithText == null ? "temp-${randomString(8)}" : messageWithText!.guid);
  }
}
