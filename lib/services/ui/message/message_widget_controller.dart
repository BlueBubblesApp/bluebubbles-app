import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/message_properties.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/timestamp/delivered_indicator.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
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

class MessageWidgetController extends StatefulController with SingleGetTickerProviderMixin {
  final RxBool showEdits = false.obs;

  late List<MessagePart> parts;
  Message message;
  String? oldMessageGuid;
  String? newMessageGuid;
  ConversationViewController? cvController;
  late final String tag;
  late final StreamSubscription<Query<Message>> sub;

  static const maxBubbleSizeFactor = 0.6;

  MessageWidgetController(this.message) {
    tag = message.guid!;
  }

  Message? get newMessage => newMessageGuid == null ? null : ms(cvController!.chat.guid).struct.getMessage(newMessageGuid!);
  Message? get oldMessage => oldMessageGuid == null ? null : ms(cvController!.chat.guid).struct.getMessage(oldMessageGuid!);

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb) {
      final messageQuery = messageBox.query(Message_.id.equals(message.id!)).watch();
      sub = messageQuery.listen((Query<Message> query) {
        final _message = messageBox.get(message.id!);
        if (_message != null) {
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

  void updateMessage(Message newItem) {
    final oldGuid = message.guid;
    if (newItem.guid != oldGuid && oldGuid!.contains("temp")) {
      message = Message.merge(newItem, message);
      ms(message.chat.target!.guid).updateMessage(message, oldGuid: oldGuid);
      updateWidgetFunctions[MessageHolder]?.call(null);
    } else if (newItem.dateDelivered != message.dateDelivered || newItem.dateRead != message.dateRead) {
      message = Message.merge(newItem, message);
      ms(message.chat.target!.guid).updateMessage(message);
      updateWidgetFunctions[DeliveredIndicator]?.call(null);
    } else if (newItem.dateEdited != message.dateEdited || newItem.error != message.error) {
      message = Message.merge(newItem, message);
      ms(message.chat.target!.guid).updateMessage(message);
      updateWidgetFunctions[MessageHolder]?.call(null);
    }
  }


  void updateThreadOriginator(Message newItem) {
    updateWidgetFunctions[MessageProperties]?.call(null);
  }

  void updateAssociatedMessage(Message newItem) {
    if (message.associatedMessages.firstWhereOrNull((e) => e.guid == newItem.guid) == null) {
      message.associatedMessages.add(newItem);
    }
    updateWidgetFunctions[MessageHolder]?.call(null);
  }
}