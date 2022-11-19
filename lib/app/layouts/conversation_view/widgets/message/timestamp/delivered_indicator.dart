import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeliveredIndicator extends CustomStateful<MessageWidgetController> {
  DeliveredIndicator({
    Key? key,
    required super.parentController,
    required this.forceShow,
  }) : super(key: key);

  final bool forceShow;

  @override
  _DeliveredIndicatorState createState() => _DeliveredIndicatorState();
}

class _DeliveredIndicatorState extends CustomState<DeliveredIndicator, void, MessageWidgetController> {
  Message get message => controller.message;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  bool get shouldShow {
    if (widget.forceShow) return true;
    if (!message.isFromMe!) return false;
    final messages = ms(message.chat.target!.guid).struct.messages
        .where((e) => e.isFromMe! && (e.dateDelivered != null || e.dateRead != null))
        .toList()..sort((a, b) => b.dateCreated!.compareTo(a.dateCreated!));
    final index = messages.indexWhere((e) => e.guid == message.guid);
    if (index == 0) return true;
    if (index == 1) {
      final newer = messages.first;
      if (message.dateRead != null) {
        return newer.dateRead == null;
      }
      if (message.dateDelivered != null) {
        return newer.dateDelivered == null;
      }
    }
    return false;
  }

  String getText() {
    String text = "Sent";
    if (!(message.isFromMe ?? false)) {
      text = "Received ${buildDate(message.dateCreated)}";
    } else if (message.dateRead != null) {
      text = "Read ${buildDate(message.dateRead)}";
    } else if (message.dateDelivered != null) {
      text = "Delivered${ss.settings.showDeliveryTimestamps.value ? " ${buildDate(message.dateDelivered)}" : ""}";
    } else if (ss.settings.showDeliveryTimestamps.value && message.dateCreated != null) {
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
      child: shouldShow ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15).add(const EdgeInsets.only(top: 3)),
        child: Text(
          getText(),
          style: context.theme.textTheme.labelSmall!.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.normal),
        ),
      ) : const SizedBox.shrink(),
    );
  }
}
