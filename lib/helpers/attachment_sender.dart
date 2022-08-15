import 'dart:async';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:get/get.dart' hide Response;
import 'package:mime_type/mime_type.dart';
import 'package:tuple/tuple.dart';

class AttachmentSender {
  final Rx<Tuple2<num?, bool>> attachmentData = Rx<Tuple2<num?, bool>>(Tuple2(null, false));

  Chat chat;
  PlatformFile attachment;
  String text;
  String? effectId;
  String? subject;
  String? selectedMessageGuid;
  final String _attachmentGuid = "temp-${randomString(8)}";
  late Uint8List _attachmentBytes;
  late String _attachmentName;
  late Attachment messageAttachment;
  late Message sentMessage;
  Message? messageWithText;

  String? get guid => _attachmentGuid;

  AttachmentSender(
    this.attachment,
    this.chat,
    this.text,
    this.effectId,
    this.subject,
    this.selectedMessageGuid,
  );

  Future<void> send() async {
    _attachmentName = attachment.name;
    _attachmentBytes = attachment.bytes ?? (await File(attachment.path!).readAsBytes());

    // create the attachment object and any necessary message objects
    messageAttachment = Attachment(
      guid: _attachmentGuid,
      totalBytes: _attachmentBytes.length,
      isOutgoing: true,
      isSticker: false,
      hideAttachment: false,
      uti: "public.jpg",
      transferName: _attachmentName,
      mimeType: _attachmentName == "$_attachmentGuid-CL.loc.vcf" ? "text/x-vlocation" : mime(_attachmentName),
      width: mime(_attachmentName)!.startsWith("image")
          ? (await AttachmentHelper.getImageSizing(kIsWeb ? attachment.name : attachment.path ?? attachment.name, bytes: attachment.bytes)).width.toInt()
          : null,
      height: mime(_attachmentName)!.startsWith("image")
          ? (await AttachmentHelper.getImageSizing(kIsWeb ? attachment.name : attachment.path ?? attachment.name, bytes: attachment.bytes)).height.toInt()
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

    if (text.isNotEmpty) {
      messageWithText = Message(
        guid: "temp-${randomString(8)}",
        text: text,
        dateCreated: DateTime.now(),
        hasAttachments: false,
        isFromMe: true,
        handleId: 0,
        expressiveSendStyleId: effectId,
        threadOriginatorGuid: selectedMessageGuid,
        subject: subject,
      );
    }

    // Save the attachment to device
    File? file;
    if (!kIsWeb) {
      String appDocPath = SettingsManager().appDocDir.path;
      String pathName = "$appDocPath/attachments/$_attachmentGuid/$_attachmentName";
      file = await File(pathName).create(recursive: true);
      file = await file.writeAsBytes(_attachmentBytes);
    }

    // Add the message to the chat.
    // This will save the message, attachments, and chat
    await chat.addMessage(sentMessage);
    MessageManager().addMessage(chat, sentMessage, outgoing: true);

    // If there is any text, save the text too
    if (messageWithText != null) {
      await chat.addMessage(messageWithText!);
      MessageManager().addMessage(chat, messageWithText!, outgoing: true);
    }

    // add this sender to our list of active senders
    SocketManager().addAttachmentSender(this);

    onSuccess(Response response) async {
      String? tempGuid = _attachmentGuid;

      // get the message from the response and update it in DB and the UI
      Message newMessage = Message.fromMap(response.data['data']);
      await Message.replaceMessage(tempGuid, newMessage, chat: chat);

      // do the same for attachments
      List<dynamic> attachments = response.data['data']['attachments'] ?? [];
      newMessage.attachments = [];

      for (var attachmentItem in attachments) {
        Attachment file = Attachment.fromMap(attachmentItem);
        try {
          Attachment.replaceAttachment(tempGuid, file);
        } catch (ex) {
          Logger.warn("Attachment's Old GUID doesn't exist. Skipping");
        }
        newMessage.attachments.add(file);
      }

      Logger.info("Message match: [${response.data['data']["text"]}] - ${response.data['data']["guid"]} - $tempGuid", tag: "MessageStatus");
      MessageManager().updateMessage(chat, tempGuid, newMessage);
      SocketManager().finishSender(_attachmentGuid);

      if (messageWithText != null) {
        ActionHandler.sendMessageHelper(chat, messageWithText!);
      }
    }

    onError(dynamic error, String tempGuid, Message message) async {
      Logger.error("Failed to send attachment");

      // If there is an error, replace the temp value with an error
      if (error is Response) {
        message.guid = message.guid!.replaceAll("temp", "error-${error.data['error']['message']}");
        message.error = error.statusCode == 400
            ? MessageError.BAD_REQUEST.code : MessageError.SERVER_ERROR.code;
      } else if (error is DioError) {
        // If there is an error, replace the temp value with an error
        String _error;
        if (error.type == DioErrorType.connectTimeout) {
          _error = "Connect timeout occured! Check your connection.";
        } else if (error.type == DioErrorType.sendTimeout) {
          _error = "Send timeout occured!";
        } else if (error.type == DioErrorType.receiveTimeout) {
          _error = "Receive data timeout occured! Check server logs for more info.";
        } else {
          _error = error.error.toString();
        }
        message.guid = message.guid!.replaceAll("temp", "error-$_error");
        message.error = error.response?.statusCode ?? MessageError.BAD_REQUEST.code;
      } else {
        message.guid = message.guid!
            .replaceAll("temp", "error-${error.toString()}");
        message.error = MessageError.BAD_REQUEST.code;
      }

      // send a notification to the user
      ChatController? currChat = ChatManager().activeChat;
      if (!LifeCycleManager().isAlive || currChat?.chat.guid != chat.guid) {
        NotificationManager().createFailedToSendMessage();
      }

      await Message.replaceMessage(tempGuid, message);
      MessageManager().updateMessage(chat, tempGuid, message);
    }

    // on web, we can't send from a file so send from bytes instead
    if (!kIsWeb) {
      api.sendAttachment(chat.guid, _attachmentGuid, file!,
          onSendProgress: (count, total) => attachmentData.value = Tuple2(count / _attachmentBytes.length, false)
      ).then(onSuccess).catchError((err) async {
        await onError.call(err, _attachmentGuid, sentMessage);
        if (messageWithText != null) {
          await onError.call(err, _attachmentGuid, messageWithText!);
        }
        SocketManager().finishSender(_attachmentGuid);
        attachmentData.value = Tuple2(null, true);
        attachmentData.close();
      });
    } else {
      api.sendAttachmentBytes(chat.guid, _attachmentGuid, _attachmentBytes, _attachmentName,
          onSendProgress: (count, total) => attachmentData.value = Tuple2(count / _attachmentBytes.length, false)
      ).then(onSuccess).catchError((err) async {
        await onError.call(err, _attachmentGuid, sentMessage);
        if (messageWithText != null) {
          await onError.call(err, _attachmentGuid, messageWithText!);
        }
        SocketManager().finishSender(_attachmentGuid);
        attachmentData.value = Tuple2(null, true);
        attachmentData.close();
      });
    }
  }
}
