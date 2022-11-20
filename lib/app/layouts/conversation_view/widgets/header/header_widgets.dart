import 'dart:math';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ManualMark extends StatefulWidget {
  const ManualMark({required this.controller});

  final ConversationViewController controller;

  @override
  State<StatefulWidget> createState() => ManualMarkState();
}

class ManualMarkState extends OptimizedState<ManualMark> {
  bool marked = false;
  bool marking = false;

  Chat get chat => widget.controller.chat;

  @override
  Widget build(BuildContext context) {
    final manualMark = ss.settings.enablePrivateAPI.value && ss.settings.privateManualMarkAsRead.value;
    return Obx(() {
      if (!manualMark && !widget.controller.inSelectMode.value) return const SizedBox.shrink();
      return IconButton(
        icon: Icon(
          widget.controller.inSelectMode.value ? (iOS ? CupertinoIcons.trash : Icons.delete_outlined)
              : marking ? (iOS ? CupertinoIcons.arrow_2_circlepath : Icons.sync)
              : marked ? (iOS ? CupertinoIcons.app : Icons.mark_chat_read_outlined)
              : (iOS ? CupertinoIcons.app_badge : Icons.mark_chat_unread_outlined),
          color: !iOS ? context.theme.colorScheme.onBackground
              : (!marked && !marking || widget.controller.inSelectMode.value)
              ? context.theme.colorScheme.primary
              : context.theme.colorScheme.outline,
        ),
        onPressed: () async {
          if (widget.controller.inSelectMode.value) {
            for (Message m in widget.controller.selected) {
              ms(chat.guid).removeMessage(m);
              Message.softDelete(m.guid!);
            }
            widget.controller.inSelectMode.value = false;
            widget.controller.selected.clear();
            return;
          }
          if (marking) return;
          setState(() {
            marking = true;
          });
          if (!marked) {
            await http.markChatRead(chat.guid);
          } else {
            await http.markChatUnread(chat.guid);
          }
          setState(() {
            marking = false;
            marked = !marked;
          });
        },
      );
    });
  }
}

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Obx(() => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 0,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: getIndicatorColor(socket.state.value).withOpacity(0.4),
              spreadRadius: socket.state.value != SocketState.connected ? max(MediaQuery.of(context).viewPadding.top, 40) : 0,
              blurRadius: socket.state.value != SocketState.connected ? max(MediaQuery.of(context).viewPadding.top, 40) : 0,
            ),
          ],
        ),
      )),
    );
  }
}