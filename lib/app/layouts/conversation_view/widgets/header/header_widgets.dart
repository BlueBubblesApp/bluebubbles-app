import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/app/layouts/chat_creator/new_chat_creator.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:universal_io/io.dart';

class ManualMark extends StatefulWidget {
  const ManualMark({super.key, required this.controller});

  final ConversationViewController controller;

  @override
  State<StatefulWidget> createState() => ManualMarkState();
}

class ManualMarkState extends State<ManualMark> with ThemeHelpers {
  bool marking = false;
  Message? _latestIncoming;
  StreamSubscription<Query<Message>>? _sub;

  Chat get chat => widget.controller.chat;

  bool get _isRead => _latestIncoming == null || _latestIncoming!.dateRead != null;

  @override
  void initState() {
    super.initState();
    _watchLatestIncoming();
  }

  @override
  void didUpdateWidget(covariant ManualMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.chat.id != widget.controller.chat.id) {
      _watchLatestIncoming();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _watchLatestIncoming() {
    _sub?.cancel();
    final query = Database.messages.query(Message_.dateDeleted
        .isNull()
        .and(Message_.dateCreated.notNull())
        .and(Message_.isFromMe.equals(false))
        .and(Message_.associatedMessageGuid.isNull()))
      ..link(Message_.chat, Chat_.id.equals(chat.id!))
      ..order(Message_.dateCreated, flags: Order.descending);
    _sub = query.watch(triggerImmediately: true).listen((q) {
      final latest = q.findFirst();
      if (mounted) setState(() => _latestIncoming = latest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final manualMark = SettingsSvc.settings.enablePrivateAPI.value &&
        SettingsSvc.settings.privateManualMarkAsRead.value &&
        !(chat.autoSendReadReceipts ?? false);
    return Obx(() {
      if (!manualMark && !widget.controller.inSelectMode.value) return const SizedBox.shrink();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              widget.controller.inSelectMode.value
                  ? (iOS ? CupertinoIcons.trash : Icons.delete_outlined)
                  : marking
                      ? (iOS ? CupertinoIcons.arrow_2_circlepath : Icons.sync)
                      : _isRead
                          ? (iOS ? CupertinoIcons.app : Icons.mark_chat_read_outlined)
                          : (iOS ? CupertinoIcons.app_badge : Icons.mark_chat_unread_outlined),
              color: !iOS
                  ? context.theme.colorScheme.onSurface
                  : (!_isRead && !marking || widget.controller.inSelectMode.value)
                      ? context.theme.colorScheme.primary
                      : context.theme.colorScheme.outline,
            ),
            tooltip: widget.controller.inSelectMode.value
                ? "Delete"
                : marking
                    ? null
                    : _isRead
                        ? "Mark Unread"
                        : "Mark Read",
            onPressed: () async {
              if (widget.controller.inSelectMode.value) {
                for (Message m in widget.controller.selected) {
                  await MessagesSvc(chat.guid).softDeleteMessage(m);
                }
                widget.controller.inSelectMode.value = false;
                widget.controller.selected.clear();
                return;
              }
              if (marking) return;
              setState(() {
                marking = true;
              });
              final wasRead = _isRead;
              try {
                await (wasRead ? HttpSvc.chat.markUnread(chat.guid) : HttpSvc.chat.markRead(chat.guid));
                _latestIncoming
                  ?..dateRead = wasRead ? null : DateTime.now()
                  ..save();
                await ChatsSvc.setChatHasUnread(chat, wasRead, force: true, privateMark: false);
              } catch (e) {
                final detail = e is Response ? e.data?["error"]?["message"]?.toString() : null;
                showSnackbar("Error", "Failed to mark ${wasRead ? "unread" : "read"}: ${detail ?? e}");
              } finally {
                if (mounted) setState(() => marking = false);
              }
            },
          ),
          if (widget.controller.inSelectMode.value)
            IconButton(
              icon: Icon(
                iOS ? CupertinoIcons.arrow_right : Icons.forward_outlined,
                color: !iOS ? context.theme.colorScheme.onSurface : context.theme.colorScheme.primary,
              ),
              onPressed: () async {
                List<PlatformFile> attachments = [];
                String text = "";
                widget.controller.selected.sort((a, b) => Message.sort(a, b, descending: false));
                for (Message m in widget.controller.selected) {
                  final _attachments = m.dbAttachments
                      .where((e) => AttachmentsSvc.getContent(e, autoDownload: false) is PlatformFile)
                      .map((e) => AttachmentsSvc.getContent(e, autoDownload: false) as PlatformFile);
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
                NavigationSvc.pushAndRemoveUntil(
                  context,
                  NewChatCreator(
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

class ConnectionIndicator extends StatefulWidget {
  const ConnectionIndicator({super.key});

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator> {
  bool _isVisible = false;
  bool _hasHadConnectionFailure = false;
  SocketState _displayState = SocketState.connected;
  Timer? _hideTimer;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    // Only pre-show if already mid-reconnect (e.g. widget remounted during retry cycle)
    final initial = SocketSvc.state.value;
    if (SettingsSvc.settings.finishedSetup.value &&
        (initial == SocketState.reconnecting || initial == SocketState.error)) {
      _isVisible = true;
      _displayState = initial;
      _hasHadConnectionFailure = true;
    }
    _worker = ever(SocketSvc.state, _onSocketStateChanged);
  }

  void _onSocketStateChanged(SocketState state) {
    if (!mounted) return;
    if (!SettingsSvc.settings.finishedSetup.value) return;
    if (state == SocketState.reconnecting) {
      _hasHadConnectionFailure = true;
      _hideTimer?.cancel();
      setState(() {
        _displayState = SocketState.reconnecting;
        _isVisible = true;
      });
    } else if (state == SocketState.error) {
      _hasHadConnectionFailure = true;
      _hideTimer?.cancel();
      setState(() {
        _displayState = SocketState.error;
        _isVisible = true;
      });
    } else if (state == SocketState.connected && _hasHadConnectionFailure) {
      _hideTimer?.cancel();
      setState(() {
        _displayState = SocketState.connected;
        _isVisible = true;
      });
      _hideTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isVisible = false;
            _hasHadConnectionFailure = false;
          });
        }
      });
    }
    // connecting and disconnected: no indicator change
  }

  @override
  void dispose() {
    _worker?.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).viewPadding.top;
    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isVisible ? 4.0 : 0.0,
        color: getIndicatorColor(_displayState),
      ),
    );
  }
}

/// A send-progress [LinearProgressIndicator] shared by both header skins.
///
/// Reads [Chat.sendProgress] from [ChatStateScope] so it never needs a
/// [Chat] constructor parameter.  Place it in a [Positioned] at the bottom
/// of the header stack.
class HeaderProgressIndicator extends StatelessWidget {
  const HeaderProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = ChatStateScope.chatOf(context);
    return Obx(() => TweenAnimationBuilder<double>(
          duration: chat.sendProgress.value == 0
              ? Duration.zero
              : chat.sendProgress.value == 1
                  ? const Duration(milliseconds: 250)
                  : const Duration(seconds: 10),
          curve: chat.sendProgress.value == 1 ? Curves.easeInOut : Curves.easeOutExpo,
          tween: Tween<double>(
            begin: 0,
            end: chat.sendProgress.value,
          ),
          builder: (context, value, _) => AnimatedOpacity(
            opacity: value == 1 ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.transparent,
              minHeight: 3,
            ),
          ),
        ));
  }
}
