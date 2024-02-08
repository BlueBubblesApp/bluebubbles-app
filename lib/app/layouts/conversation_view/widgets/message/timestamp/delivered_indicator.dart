import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeliveredIndicator extends CustomStateful<MessageWidgetController> {
  DeliveredIndicator({
    super.key,
    required super.parentController,
    required this.forceShow,
  });

  final bool forceShow;

  @override
  CustomState createState() => _DeliveredIndicatorState();
}

class _DeliveredIndicatorState extends CustomState<DeliveredIndicator, void, MessageWidgetController> {
  Message get message => controller.message;
  bool get showAvatar => (controller.cvController?.chat ?? cm.activeChat!.chat).isGroup;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  bool get shouldShow {
    if (controller.audioWasKept.value != null) return true;
    if (widget.forceShow || message.guid!.contains("temp")) return true;
    if ((!message.isFromMe! && iOS) || (controller.parts.lastOrNull?.isUnsent ?? false)) return false;
    final messages = ms(controller.cvController?.chat.guid ?? cm.activeChat!.chat.guid).struct.messages
        .where((e) => (!iOS ? !e.isFromMe! : false) || (e.isFromMe! && (e.dateDelivered != null || e.dateRead != null)))
        .toList()..sort(Message.sort);
    final index = messages.indexWhere((e) => e.guid == message.guid);
    if (index == 0) return true;
    if (index == 1 && message.isFromMe!) {
      final newer = messages.first;
      if (message.dateRead != null) {
        return newer.dateRead == null;
      }
      if (message.dateDelivered != null) {
        return newer.dateDelivered == null;
      }
    }
    if (index > 1 && message.isFromMe!) {
      return messages.firstWhereOrNull((e) => e.dateRead != null)?.guid == message.guid;
    }
    return false;
  }

  String getText() {
    String text = "";
    if (controller.audioWasKept.value != null) {
      text = "Kept ${buildDate(controller.audioWasKept.value!)}";
    } else if (!(message.isFromMe ?? false)) {
      text = "Received ${buildDate(message.dateCreated)}";
    } else if (message.dateRead != null) {
      text = "Read ${buildDate(message.dateRead)}";
    } else if (message.dateDelivered != null) {
      text = "Delivered${message.wasDeliveredQuietly && !message.didNotifyRecipient ? " Quietly" : ""}${ss.settings.showDeliveryTimestamps.value || !iOS || widget.forceShow ? " ${buildDate(message.dateDelivered)}" : ""}";
    } else if (message.guid!.contains("temp") && !(controller.cvController?.chat ?? cm.activeChat!.chat).isGroup && !iOS) {
      text = "Sending...";
    } else if (widget.forceShow) {
      text = "Sent ${buildDate(message.dateCreated)}";
    }

    return text;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 250),
      child: Obx(() => shouldShow && getText().isNotEmpty ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15).add(EdgeInsets.only(
          top: 3,
          left: showAvatar || ss.settings.alwaysShowAvatars.value ? 35 : 0)
        ),
        child: Text(
          getText(),
          style: context.theme.textTheme.labelSmall!.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.normal),
        ),
      ) : const SizedBox.shrink()),
    );
  }
}
