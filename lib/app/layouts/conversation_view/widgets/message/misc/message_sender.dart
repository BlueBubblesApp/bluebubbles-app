import 'package:bluebubbles/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MessageSender extends StatelessWidget {
  const MessageSender({Key? key, required this.message, required this.olderMessage}) : super(key: key);

  final Message message;
  final Message? olderMessage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25).add(const EdgeInsets.only(bottom: 3)),
      child: Text(
        message.handle?.displayName ?? "",
        style: context.theme.textTheme.labelMedium!.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.normal),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
