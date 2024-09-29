import 'dart:math';
import 'dart:typed_data';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class ManualMark extends StatefulWidget {
  const ManualMark({required this.controller});

  final ConversationViewController controller;

  @override
  State<StatefulWidget> createState() => ManualMarkState();
}

class ManualMarkState extends OptimizedState<ManualMark> {
  bool marked = false;
  bool marking = false;

  @override
  Widget build(BuildContext context) {
    final chat = widget.controller.chat;
    final manualMark = ss.settings.enablePrivateAPI.value && ss.settings.privateManualMarkAsRead.value && !(chat.autoSendReadReceipts ?? false);
    return Obx(() {
      if (!manualMark && !widget.controller.inSelectMode.value) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
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
            tooltip: widget.controller.inSelectMode.value ? "Delete"
              : marking ? null
              : marked ? "Mark Unread"
              : "Mark Read",
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
          ),
          if (widget.controller.inSelectMode.value)
            IconButton(
              icon: Icon(
                iOS ? CupertinoIcons.arrow_right : Icons.forward_outlined,
                color: !iOS ? context.theme.colorScheme.onBackground : context.theme.colorScheme.primary,
              ),
              onPressed: () async {
                List<PlatformFile> attachments = [];
                String text = "";
                widget.controller.selected.sort((a, b) => Message.sort(a, b, descending: false));
                for (Message m in widget.controller.selected) {
                  final _attachments = m.attachments
                      .where((e) => as.getContent(e!, autoDownload: false) is PlatformFile)
                      .map((e) => as.getContent(e!, autoDownload: false) as PlatformFile);
                  for (PlatformFile a in _attachments) {
                    Uint8List? bytes = a.bytes;
                    bytes ??= await File(a.path!).readAsBytes();
                    attachments.add(PlatformFile(
                      name: a.name,
                      path: a.path,
                      size: bytes.length,
                      bytes: bytes,
                    ));
                  }
                  if (!isNullOrEmpty(m.text)) {
                    if (text.isEmpty) {
                      text = m.text!;
                    } else {
                      text = "$text\n\n${m.text}";
                    }
                  }
                }
                widget.controller.inSelectMode.value = false;
                widget.controller.selected.clear();
                ns.pushAndRemoveUntil(
                  context,
                  ChatCreator(
                    initialText: text,
                    initialAttachments: attachments,
                  ),
                  (route) => route.isFirst,
                );
              },
            ),
        ],
      );
    });
  }
}

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator();

  bool get noniOS => ss.settings.skin.value != Skins.iOS;

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
              spreadRadius: socket.state.value != SocketState.connected && (ls.isAlive || kIsDesktop)
                  ? max(MediaQuery.of(context).viewPadding.top, 40).clamp(0, noniOS ? 30 : double.infinity).toDouble()
                  : 0,
              blurRadius: max(MediaQuery.of(context).viewPadding.top, 40).clamp(0, noniOS ? 30 : double.infinity).toDouble(),
            ),
          ],
        ),
      )),
    );
  }
}