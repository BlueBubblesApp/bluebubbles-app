import 'dart:async';

import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/network/network_error_handler.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

ActionHandler ah = Get.isRegistered<ActionHandler>() ? Get.find<ActionHandler>() : Get.put(ActionHandler());

class ActionHandler extends GetxService {
  final List<Tuple2<String, RxDouble>> attachmentProgress = [];

  Future<void> sendMessage(Chat c, Message m, Message? selected, ReactionType? r) async {
    if ((m.text?.isEmpty ?? true) && (m.subject?.isEmpty ?? true)) return;

    final List<Message> messages = <Message>[];

    if (!(await ss.isMinBigSur) && r == null) {
      // Split URL messages on OS X to prevent message matching glitches
      String mainText = m.text!;
      String? secondaryText;
      final match = parseLinks(m.text!.replaceAll("\n", " ")).firstOrNull;
      if (match != null) {
        if (match.start == 0) {
          mainText = m.text!.substring(match.start, match.end);
          secondaryText = m.text!.substring(match.end);
        } else if (match.end == m.text!.length) {
          mainText = m.text!.substring(0, match.start);
          secondaryText = m.text!.substring(match.start, match.end);
        }
      }

      messages.add(m..text = mainText);
      if (secondaryText != null) {
        messages.add(m..text = secondaryText..subject = null);
      }

      for (Message message in messages) {
        message.generateTempGuid();
        c.addMessage(message);
      }
    } else {
      m.generateTempGuid();
      c.addMessage(m);
      messages.add(m);
    }

    final completer = Completer<void>();

    if (r == null) {
      messages.forEachIndexed((index, element) {
        http.sendMessage(
            c.guid,
            element.guid!,
            element.text!,
            subject: element.subject,
            method: (ss.settings.enablePrivateAPI.value
                && ss.settings.privateAPISend.value)
                || (element.subject?.isNotEmpty ?? false)
                || element.threadOriginatorGuid != null
                || element.expressiveSendStyleId != null
                ? "private-api" : "apple-script",
            selectedMessageGuid: element.threadOriginatorGuid,
            effectId: element.expressiveSendStyleId
        ).then((response) async {
          final newMessage = Message.fromMap(response.data['data']);
          await Message.replaceMessage(element.guid, newMessage);
          Logger.info("Message match: [${newMessage.text}] - ${newMessage.guid} - ${element.guid}", tag: "MessageStatus");
          if (index == messages.length - 1) completer.complete();
        }).catchError((error) async {
          Logger.error('Failed to send message! Error: ${error.toString()}');

          final tempGuid = element.guid;
          element = handleSendError(error, element);

          if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
            await notif.createFailedToSend();
          }
          await Message.replaceMessage(tempGuid, element);
          if (index == messages.length - 1) completer.complete();
        });
      });
    } else {
      http.sendTapback(c.guid, selected!.text ?? "", selected.guid!, describeEnum(r)).then((response) async {
        final newMessage = Message.fromMap(response.data['data']);
        await Message.replaceMessage(m.guid, newMessage);
        Logger.info("Reaction match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
        completer.complete();
      }).catchError((error) async {
        Logger.error('Failed to send message! Error: ${error.toString()}');

        final tempGuid = m.guid;
        m = handleSendError(error, m);

        if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
          await notif.createFailedToSend();
        }
        await Message.replaceMessage(tempGuid, m);
        completer.complete();
      });
    }

    return completer.future;
  }

  Future<void> sendAttachment(Chat c, Message m) async {
    if (m.attachments.isEmpty || m.attachments.firstOrNull?.bytes == null) return;
    final attachment = m.attachments.first!;
    final progress = Tuple2(attachment.guid!, 0.0.obs);
    attachmentProgress.add(progress);

    // Save the attachment to storage and DB
    if (!kIsWeb) {
      String pathName = "${fs.appDocDir.path}/attachments/${attachment.guid}/${attachment.transferName}";
      final file = await File(pathName).create(recursive: true);
      await file.writeAsBytes(attachment.bytes!);
    }
    await c.addMessage(m);

    final completer = Completer<void>();
    http.sendAttachmentBytes(c.guid, attachment.guid!, attachment.bytes!, attachment.transferName!,
        onSendProgress: (count, total) => progress.item2.value = count / attachment.bytes!.length
    ).then((response) async {
      final newMessage = Message.fromMap(response.data['data']);

      for (Attachment? a in newMessage.attachments) {
        if (a == null) continue;
        Attachment.replaceAttachment(m.guid, a);
      }
      await Message.replaceMessage(m.guid, newMessage);
      attachmentProgress.removeWhere((e) => e.item1 == m.guid);

      Logger.info("Attachment match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
      completer.complete();
    }).catchError((error) async {
      Logger.error('Failed to send message! Error: ${error.toString()}');

      final tempGuid = m.guid;
      m = handleSendError(error, m);

      if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
        await notif.createFailedToSend();
      }
      await Message.replaceMessage(tempGuid, m);
      attachmentProgress.removeWhere((e) => e.item1 == m.guid);
      completer.complete();
    });

    return completer.future;
  }

  Future<Chat?> createChat(List<String> addresses, String text) async {
    Logger.info("Starting chat to $addresses");

    Message message = Message(
      text: text.trim(),
      dateCreated: DateTime.now(),
      isFromMe: true,
      handleId: 0,
    );
    message.generateTempGuid();

    final response = await http.createChat(addresses, text.trim()).catchError((err) {
      message = handleSendError(err, message);
      showSnackbar("Error", "Failed to create chat! Error code: ${message.error}");
    });

    if (message.error != 0) {
      return null;
    }

    message = Message.fromMap(response.data['data']['messages'].first);
    final chat = Chat.fromMap(response.data['data']);

    // Save the chat and message
    chat.save();
    chat.addMessage(message);
    return chat;
  }

  Future<void> handleNewMessage(Chat c, Message m) async {
    // sanity check
    final existing = Message.findOne(guid: m.guid);
    if (existing != null) {
      return await handleUpdatedMessage(c, m);
    }
    Logger.info("New message: [${m.text}] - for chat [${c.guid}]", tag: "ActionHandler");
    // Gets the chat from the db or server (if new)
    c = MessageHelper.isParticipantEvent(m) ? await handleNewOrUpdatedChat(c) : (Chat.findOne(guid: c.guid) ?? await handleNewOrUpdatedChat(c));
    // Get the message handle
    final handle = c.handles.firstWhereOrNull((e) => e.originalROWID == m.handleId);
    if (handle != null) {
      m.handleId = handle.id;
      m.handle = handle;
    }
    // Display notification if needed and save everything to DB
    if (!ls.isAlive) {
      await MessageHelper.handleNotification(m, c);
    }
    await c.addMessage(m);
    for (Attachment? a in m.attachments) {
      if (a == null) continue;

      a.save(m);
      if ((await as.canAutoDownload()) && a.mimeType != null) {
        Get.put(AttachmentDownloadController(attachment: a), tag: a.guid);
      }
    }
  }

  Future<void> handleUpdatedMessage(Chat c, Message m) async {
    // sanity check
    final existing = Message.findOne(guid: m.guid);
    if (existing == null) {
      return await handleNewMessage(c, m);
    }
    Logger.info("Updated message: [${m.text}] - for chat [${c.guid}]", tag: "ActionHandler");
    // update the message in the DB
    await Message.replaceMessage(m.guid, m);
  }

  Future<Chat> handleNewOrUpdatedChat(Chat partialData) async {
    // fetch all contacts for matching new handles if in background
    if (!ls.isUiThread) {
      await cs.init();
    }
    // get and return the chat from server
    return await cm.fetchChat(partialData.guid) ?? partialData;
  }
}
