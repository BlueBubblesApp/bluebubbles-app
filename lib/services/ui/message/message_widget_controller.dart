import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_properties.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/delivered_indicator.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

MessageWidgetController mwc(Message message) => Get.isRegistered<MessageWidgetController>(tag: message.guid)
    ? Get.find<MessageWidgetController>(tag: message.guid) : Get.put(MessageWidgetController(message), tag: message.guid);

MessageWidgetController? getActiveMwc(String guid) => Get.isRegistered<MessageWidgetController>(tag: guid)
    ? Get.find<MessageWidgetController>(tag: guid) : null;

class MessageWidgetController extends StatefulController with GetSingleTickerProviderStateMixin {
  final RxBool showEdits = false.obs;
  final Rxn<DateTime> audioWasKept = Rxn<DateTime>(null);

  List<MessagePart> parts = [];
  Message message;
  String? oldMessageGuid;
  String? newMessageGuid;
  ConversationViewController? cvController;
  late final String tag;
  late final StreamSubscription sub;
  bool built = false;

  static const maxBubbleSizeFactor = 0.75;

  MessageWidgetController(this.message) {
    tag = message.guid!;
  }

  Message? get newMessage => newMessageGuid == null ? null : ms(cvController!.chat.guid).struct.getMessage(newMessageGuid!);
  Message? get oldMessage => oldMessageGuid == null ? null : ms(cvController!.chat.guid).struct.getMessage(oldMessageGuid!);

  @override
  void onInit() {
    super.onInit();
    buildMessageParts();
    if (!kIsWeb && message.id != null) {
      final messageQuery = messageBox.query(Message_.id.equals(message.id!)).watch();
      sub = messageQuery.listen((Query<Message> query) async {
        if (message.id == null) return;
        final _message = await runAsync(() {
          return messageBox.get(message.id!);
        });
        if (_message != null) {
          if (_message.hasAttachments) {
            _message.attachments = List<Attachment>.from(_message.dbAttachments);
          }
          _message.associatedMessages = message.associatedMessages;
          _message.handle = _message.getHandle();
          updateMessage(_message);
        }
      });
    } else if (kIsWeb) {
      sub = WebListeners.messageUpdate.listen((tuple) {
        final _message = tuple.item1;
        final tempGuid = tuple.item2;
        if (_message.guid == message.guid || tempGuid == message.guid) {
          updateMessage(_message);
        }
      });
    }
  }

  @override
  void onClose() {
    sub.cancel();
    super.onClose();
  }

  void close() {
    Get.delete<MessageWidgetController>(tag: tag);
  }

  void buildMessageParts() {
    // go through the attributed body
    if (message.attributedBody.firstOrNull?.runs.isNotEmpty ?? false) {
      parts = attributedBodyToMessagePart(message.attributedBody.first);
    }
    // add edits
    if (message.messageSummaryInfo.firstOrNull?.editedParts.isNotEmpty ?? false) {
      for (int part in message.messageSummaryInfo.first.editedParts) {
        final edits = message.messageSummaryInfo.first.editedContent[part.toString()] ?? [];
        final existingPart = parts.firstWhereOrNull((element) => element.part == part);
        if (existingPart != null) {
          existingPart.edits.addAll(edits
              .where((e) => e.text?.values.isNotEmpty ?? false)
              .map((e) => attributedBodyToMessagePart(e.text!.values.first).firstOrNull)
              .where((e) => e != null).map((e) => e!).toList());
          if (existingPart.edits.isNotEmpty) {
            existingPart.edits.removeLast();
          }
        }
      }
    }
    // add unsends
    if (message.messageSummaryInfo.firstOrNull?.retractedParts.isNotEmpty ?? false) {
      for (int part in message.messageSummaryInfo.first.retractedParts) {
        final existing = parts.indexWhere((e) => e.part == part);
        if (existing >= 0) {
          parts.removeAt(existing);
        }
        parts.add(MessagePart(
          part: part,
          isUnsent: true,
        ));
      }
    }
    if (parts.isEmpty) {
      if (!message.hasApplePayloadData && !message.isLegacyUrlPreview && !message.isInteractive && !message.isGroupEvent) {
        parts.addAll(message.attachments.mapIndexed((index, e) => MessagePart(
          attachments: [e!],
          part: index,
        )));
      }
      if (message.fullText.isNotEmpty || message.isGroupEvent) {
        parts.add(MessagePart(
          subject: message.subject,
          text: message.text,
          part: parts.length,
        ));
      }
    }
    parts.sort((a, b) => a.part.compareTo(b.part));
  }

  List<MessagePart> attributedBodyToMessagePart(AttributedBody body) {
    final mainString = body.string;
    final list = <MessagePart>[];
    body.runs.sort((a, b) => a.range.first.compareTo(b.range.first));
    body.runs.forEachIndexed((i, e) {
      if (e.attributes?.messagePart == null) return;
      final existingPart = list.firstWhereOrNull((element) => element.part == e.attributes!.messagePart!);
      if (existingPart != null) {
        final newText = mainString.substring(e.range.first, e.range.first + e.range.last);
        existingPart.text = (existingPart.text ?? "") + newText;
        if (e.hasMention) {
          existingPart.mentions.add(Mention(
            mentionedAddress: e.attributes?.mention,
            range: [existingPart.text!.indexOf(newText), existingPart.text!.indexOf(newText) + e.range.last],
          ));
          existingPart.mentions.sort((a, b) => a.range.first.compareTo(b.range.first));
        }
      } else {
        list.add(MessagePart(
          subject: i == 0 ? message.subject : null,
          text: e.isAttachment ? null : mainString.substring(e.range.first, e.range.first + e.range.last),
          attachments: e.isAttachment ? [
            ms(cvController?.chat.guid ?? cm.activeChat!.chat.guid).struct.getAttachment(e.attributes!.attachmentGuid!) ?? Attachment.findOne(e.attributes!.attachmentGuid!)
          ].where((e) => e != null).map((e) => e!).toList() : [],
          mentions: !e.hasMention ? [] : [Mention(
            mentionedAddress: e.attributes?.mention,
            range: [0, e.range.last],
          )],
          part: e.attributes!.messagePart!,
        ));
      }
    });
    return list;
  }

  void updateMessage(Message newItem) {
    final chat = message.chat.target?.guid ?? cvController?.chat.guid ?? cm.activeChat!.chat.guid;
    final oldGuid = message.guid;
    if (newItem.guid != oldGuid && oldGuid!.contains("temp")) {
      message = Message.merge(newItem, message);
      ms(chat).updateMessage(message, oldGuid: oldGuid);
      updateWidgets<MessageHolder>(null);
      if (message.isFromMe! && message.attachments.isNotEmpty) {
        updateWidgets<AttachmentHolder>(null);
      }
    } else if (newItem.dateDelivered != message.dateDelivered || newItem.dateRead != message.dateRead || newItem.didNotifyRecipient != message.didNotifyRecipient) {
      final edited = newItem.dateEdited != message.dateEdited;
      message = Message.merge(newItem, message);
      ms(chat).updateMessage(message);
      // update the latest 2 messages in case their indicators need to go away
      final messages = ms(chat).struct.messages
          .where((e) => e.isFromMe! && (e.dateDelivered != null || e.dateRead != null))
          .toList()..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
      for (Message m in messages.take(2)) {
        getActiveMwc(m.guid!)?.updateWidgets<DeliveredIndicator>(null);
      }
      if (edited) {
        parts.clear();
        buildMessageParts();
        updateWidgets<MessageHolder>(null);
      }
      updateWidgets<DeliveredIndicator>(null);
    } else if (newItem.dateEdited != message.dateEdited || newItem.error != message.error) {
      message = Message.merge(newItem, message);
      parts.clear();
      buildMessageParts();
      ms(chat).updateMessage(message);
      updateWidgets<MessageHolder>(null);
    }
  }

  void updateThreadOriginator(Message newItem) {
    updateWidgets<MessageProperties>(null);
  }

  void updateAssociatedMessage(Message newItem, {bool updateHolder = true}) {
    final index = message.associatedMessages.indexWhere((e) => e.id == newItem.id);
    if (index >= 0) {
      message.associatedMessages[index] = newItem;
    } else {
      message.associatedMessages.add(newItem);
    }
    if (updateHolder) {
      updateWidgets<MessageHolder>(null);
    }
  }

  void removeAssociatedMessage(Message toRemove) {
    message.associatedMessages.removeWhere((e) => e.id == toRemove.id);
    updateWidgets<MessageHolder>(null);
  }
}