import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChatEvent extends StatelessWidget {
  ChatEvent({
    Key? key,
    required this.part,
    required this.message,
  }) : super(key: key);

  final MessagePart part;
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Text(
          part.isUnsent
              ? (message.isFromMe! ? "You unsent a message. Others may still see the message on devices where the software hasn't been updated" : "${message.handle?.displayName ?? "Unknown"} unsent a message")
              : message.groupEventText,
          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.outline),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}