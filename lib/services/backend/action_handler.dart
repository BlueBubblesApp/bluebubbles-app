import 'dart:async';

import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';

ActionHandler ah = Get.isRegistered<ActionHandler>() ? Get.find<ActionHandler>() : Get.put(ActionHandler());

class ActionHandler extends GetxService {
  final RxList<Tuple2<String, RxDouble>> attachmentProgress = <Tuple2<String, RxDouble>>[].obs;
  final List<String> outOfOrderTempGuids = [];
  CancelToken? latestCancelToken;
  
  Future<List<Message>> prepMessage(Chat c, Message m, Message? selected, String? r, {bool clearNotificationsIfFromMe = true}) async {
    if ((m.text?.isEmpty ?? true) && (m.subject?.isEmpty ?? true) && r == null) return [];

    final List<Message> messages = <Message>[];

    if (!(await ss.isMinBigSur) && r == null) {
      // Split URL messages on OS X to prevent message matching glitches
      String mainText = m.text!;
      String? secondaryText;
      final match = parseLinks(m.text!.replaceAll("\n", " ")).firstOrNull;
      if (match != null) {
        if (match.start == 0) {
          mainText = m.text!.substring(0, match.end).trimRight();
          secondaryText = m.text!.substring(match.end).trimLeft();
        } else if (match.end == m.text!.length) {
          mainText = m.text!.substring(0, match.start).trimRight();
          secondaryText = m.text!.substring(match.start).trimLeft();
        }
      }

      messages.add(m..text = mainText);
      if (!isNullOrEmpty(secondaryText)!) {
        messages.add(Message(
          text: secondaryText,
          threadOriginatorGuid: m.threadOriginatorGuid,
          threadOriginatorPart: "${m.threadOriginatorPart ?? 0}:0:0",
          expressiveSendStyleId: m.expressiveSendStyleId,
          dateCreated: DateTime.now(),
          hasAttachments: false,
          isFromMe: true,
          handleId: 0,
        ));
      }

      for (Message message in messages) {
        message.generateTempGuid();
        await c.addMessage(message, clearNotificationsIfFromMe: clearNotificationsIfFromMe);
      }
    } else {
      m.generateTempGuid();
      await c.addMessage(m, clearNotificationsIfFromMe: clearNotificationsIfFromMe);
      messages.add(m);
    }
    return messages;
  }

  Future<void> sendMessage(Chat c, Message m, Message? selected, String? r) async {
    final completer = Completer<void>();
    if (r == null) {
      http.sendMessage(
        c.guid,
        m.guid!,
        m.text!,
        subject: m.subject,
        method: (ss.settings.enablePrivateAPI.value
            && ss.settings.privateAPISend.value)
            || (m.subject?.isNotEmpty ?? false)
            || m.threadOriginatorGuid != null
            || m.expressiveSendStyleId != null
            ? "private-api" : "apple-script",
        selectedMessageGuid: m.threadOriginatorGuid,
        effectId: m.expressiveSendStyleId,
        partIndex: int.tryParse(m.threadOriginatorPart?.split(":").firstOrNull ?? ""),
      ).then((response) async {
        final newMessage = Message.fromMap(response.data['data']);
        try {
          await Message.replaceMessage(m.guid, newMessage);
          Logger.info("Message match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
        } catch (_) {
          Logger.info("Message match failed for ${newMessage.guid} - already handled?", tag: "MessageStatus");
        }
        completer.complete();
      }).catchError((error) async {
        Logger.error('Failed to send message! Error: ${error.toString()}');

        final tempGuid = m.guid;
        m = handleSendError(error, m);

        if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
          await notif.createFailedToSend(c);
        }
        await Message.replaceMessage(tempGuid, m);
        completer.completeError(error);
      });
    } else {
      http.sendTapback(c.guid, selected!.text ?? "", selected.guid!, r, partIndex: m.associatedMessagePart).then((response) async {
        final newMessage = Message.fromMap(response.data['data']);
        try {
          await Message.replaceMessage(m.guid, newMessage);
          Logger.info("Reaction match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
        } catch (_) {
          Logger.info("Reaction match failed for ${newMessage.guid} - already handled?", tag: "MessageStatus");
        }
        completer.complete();
      }).catchError((error) async {
        Logger.error('Failed to send message! Error: ${error.toString()}');

        final tempGuid = m.guid;
        m = handleSendError(error, m);

        if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
          await notif.createFailedToSend(c);
        }
        await Message.replaceMessage(tempGuid, m);
        completer.completeError(error);
      });
    }

    return completer.future;
  }

  Future<void> sendMultipart(Chat c, Message m, Message? selected, String? r) async {
    final completer = Completer<void>();
    http.sendMultipart(
      c.guid,
      m.guid!,
      m.attributedBody.first.runs.map((e) => {
        "text": m.attributedBody.first.string.substring(e.range.first, e.range.first + e.range.last),
        "mention": e.attributes!.mention,
        "partIndex": e.attributes!.messagePart,
      }).toList(),
      subject: m.subject,
      selectedMessageGuid: m.threadOriginatorGuid,
      effectId: m.expressiveSendStyleId,
      partIndex: int.tryParse(m.threadOriginatorPart?.split(":").firstOrNull ?? ""),
    ).then((response) async {
      final newMessage = Message.fromMap(response.data['data']);
      try {
        await Message.replaceMessage(m.guid, newMessage);
        Logger.info("Message match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
      } catch (_) {
        Logger.info("Message match failed for ${newMessage.guid} - already handled?", tag: "MessageStatus");
      }
      completer.complete();
    }).catchError((error) async {
      Logger.error('Failed to send message! Error: ${error.toString()}');

      final tempGuid = m.guid;
      m = handleSendError(error, m);

      if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
        await notif.createFailedToSend(c);
      }
      await Message.replaceMessage(tempGuid, m);
      completer.completeError(error);
    });

    return completer.future;
  }
  
  Future<void> prepAttachment(Chat c, Message m) async {
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
  }

  Future<void> sendAttachment(Chat c, Message m, bool isAudioMessage) async {
    if (m.attachments.isEmpty || m.attachments.firstOrNull?.bytes == null) return;
    final attachment = m.attachments.first!;
    final progress = attachmentProgress.firstWhere((e) => e.item1 == attachment.guid);
    final completer = Completer<void>();
    latestCancelToken = CancelToken();
    http.sendAttachment(
      c.guid,
      attachment.guid!,
      PlatformFile(name: attachment.transferName!, bytes: attachment.bytes, path: attachment.path, size: attachment.totalBytes ?? 0),
      onSendProgress: (count, total) => progress.item2.value = count / attachment.bytes!.length,
      method: (ss.settings.enablePrivateAPI.value
          && ss.settings.privateAPIAttachmentSend.value)
          || (m.subject?.isNotEmpty ?? false)
          || m.threadOriginatorGuid != null
          || m.expressiveSendStyleId != null
          ? "private-api" : "apple-script",
      selectedMessageGuid: m.threadOriginatorGuid,
      effectId: m.expressiveSendStyleId,
      partIndex: int.tryParse(m.threadOriginatorPart?.split(":").firstOrNull ?? ""),
      isAudioMessage: isAudioMessage,
      cancelToken: latestCancelToken,
    ).then((response) async {
      latestCancelToken = null;
      final newMessage = Message.fromMap(response.data['data']);

      for (Attachment? a in newMessage.attachments) {
        if (a == null) continue;
        Attachment.replaceAttachment(m.guid, a);
      }
      try {
        await Message.replaceMessage(m.guid, newMessage);
        Logger.info("Attachment match: [${newMessage.text}] - ${newMessage.guid} - ${m.guid}", tag: "MessageStatus");
      } catch (_) {
        Logger.info("Attachment match failed for ${newMessage.guid} - already handled?", tag: "MessageStatus");
      }
      attachmentProgress.removeWhere((e) => e.item1 == m.guid || e.item2 >= 1);

      completer.complete();
    }).catchError((error) async {
      latestCancelToken = null;
      Logger.error('Failed to send message! Error: ${error.toString()}');

      final tempGuid = m.guid;
      m = handleSendError(error, m);

      if (!ls.isAlive || !(cm.getChatController(c.guid)?.isAlive ?? false)) {
        await notif.createFailedToSend(c);
      }
      await Message.replaceMessage(tempGuid, m);
      attachmentProgress.removeWhere((e) => e.item1 == m.guid || e.item2 >= 1);
      completer.completeError(error);
    });

    return completer.future;
  }

  Future<void> handleNewMessage(Chat c, Message m, String? tempGuid, {bool checkExisting = true}) async {
    // sanity check
    if (checkExisting) {
      final existing = Message.findOne(guid: tempGuid ?? m.guid);
      if (existing != null) {
        return await handleUpdatedMessage(c, m, tempGuid, checkExisting: false);
      }
    }
    // should have been handled by the sanity check
    if (tempGuid != null) return;
    Logger.info("New message: [${m.text}] - for chat [${c.guid}]", tag: "ActionHandler");
    // Gets the chat from the db or server (if new)
    c = m.isParticipantEvent ? await handleNewOrUpdatedChat(c) : kIsWeb ? c : (Chat.findOne(guid: c.guid) ?? await handleNewOrUpdatedChat(c));
    // Get the message handle
    m.handle = c.handles.firstWhereOrNull((e) => e.originalROWID == m.handleId) ?? Handle.findOne(originalROWID: m.handleId);
    // Display notification if needed and save everything to DB
    if (!ls.isAlive) {
      await MessageHelper.handleNotification(m, c);
    }
    await c.addMessage(m);
  }

  Future<void> handleUpdatedMessage(Chat c, Message m, String? tempGuid, {bool checkExisting = true}) async {
    // sanity check
    if (checkExisting) {
      final existing = Message.findOne(guid: tempGuid ?? m.guid);
      if (existing == null) {
        return await handleNewMessage(c, m, tempGuid, checkExisting: false);
      }
    }
    Logger.info("Updated message: [${m.text}] - for chat [${c.guid}]", tag: "ActionHandler");
    // update any attachments
    for (Attachment? a in m.attachments) {
      if (a == null) continue;
      Attachment.replaceAttachment(tempGuid ?? m.guid, a);
    }
    // update the message in the DB
    await Message.replaceMessage(tempGuid ?? m.guid, m);
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
