import 'dart:async';
import 'dart:io';

import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class PinnedConversationTile extends StatefulWidget {
  final Chat chat;
  final bool? onTapGoToChat;
  final Function? onTapCallback;
  final List<File> existingAttachments;
  final String? existingText;

  PinnedConversationTile({
    Key? key,
    required this.chat,
    this.onTapGoToChat,
    this.existingAttachments = const [],
    this.existingText,
    this.onTapCallback,
  }) : super(key: key);

  @override
  _PinnedConversationTileState createState() => _PinnedConversationTileState();
}

class _PinnedConversationTileState extends State<PinnedConversationTile> with AutomaticKeepAliveClientMixin {
  bool isFetching = false;
  Brightness? brightness;
  Color? previousBackgroundColor;
  bool gotBrightness = false;

  // Typing indicator
  bool showTypingIndicator = false;

  void loadBrightness() {
    Color now = Theme.of(context).backgroundColor;
    bool themeChanged = previousBackgroundColor == null || previousBackgroundColor != now;
    if (!themeChanged && gotBrightness) return;

    previousBackgroundColor = now;

    bool isDark = now.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
    if (this.mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    fetchParticipants();
    // Listen for changes in the group
    NewMessageManager().stream.listen((NewMessageEvent event) async {
      // Make sure we have the required data to qualify for this tile
      if (event.chatGuid != widget.chat.guid) return;
      if (!event.event.containsKey("message")) return;
      if (widget.chat.guid == null) return;
      // Make sure the message is a group event
      Message message = event.event["message"];
      if (!message.isGroupEvent()) return;

      // If it's a group event, let's fetch the new information and save it
      await fetchChatSingleton(widget.chat.guid!);
      this.setNewChatData(forceUpdate: true);
    });
  }

  void setNewChatData({forceUpdate: false}) async {
    // Save the current participant list and get the latest
    List<Handle> ogParticipants = widget.chat.participants;
    await widget.chat.getParticipants();

    // Save the current title and generate the new one
    String? ogTitle = widget.chat.title;
    await widget.chat.getTitle();

    // If the original data is different, update the state
    if (ogTitle != widget.chat.title || ogParticipants.length != widget.chat.participants.length || forceUpdate) {
      if (this.mounted) setState(() {});
    }
  }

  Future<void> fetchParticipants() async {
    if (isFetching) return;
    isFetching = true;

    // If our chat does not have any participants, get them
    if (isNullOrEmpty(widget.chat.participants)!) {
      await widget.chat.getParticipants();
      if (!isNullOrEmpty(widget.chat.participants)! && this.mounted) {
        setState(() {});
      }
    }

    isFetching = false;
  }

  void onTapUp(details) {
    if (widget.onTapGoToChat != null && widget.onTapGoToChat!) {
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(
          builder: (BuildContext context) {
            return ConversationView(
              chat: widget.chat,
              existingAttachments: widget.existingAttachments,
              existingText: widget.existingText,
            );
          },
        ),
        (route) => route.isFirst,
      );
    } else if (widget.onTapCallback != null) {
      widget.onTapCallback!();
    } else {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (BuildContext context) {
            return ConversationView(
              chat: widget.chat,
              existingAttachments: widget.existingAttachments,
              existingText: widget.existingText,
            );
          },
        ),
      );
    }
  }

  void onTapUpBypass() {
    this.onTapUp(TapUpDetails(kind: PointerDeviceKind.touch));
  }

  Widget buildSubtitle() {
    final hideInfo = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateNames =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    TextStyle? style = Theme.of(context).textTheme.subtitle1!.apply(fontSizeFactor: 0.75);
    String? title = widget.chat.title != null ? widget.chat.title : "";

    if (generateNames)
      title = widget.chat.fakeParticipants.length == 1 ? widget.chat.fakeParticipants[0] : "Group Chat";
    else if (hideInfo) style = style.copyWith(color: Colors.transparent);

    return TextOneLine(
      title!,
      style: style,
      overflow: TextOverflow.ellipsis,
    );
  }

  void onTap() {
    if (widget.onTapGoToChat != null && widget.onTapGoToChat!) {
      Navigator.of(context).pushAndRemoveUntil(
        ThemeSwitcher.buildPageRoute(
          builder: (BuildContext context) {
            return ConversationView(
              chat: widget.chat,
              existingAttachments: widget.existingAttachments,
              existingText: widget.existingText,
            );
          },
        ),
        (route) => route.isFirst,
      );
    } else if (widget.onTapCallback != null) {
      widget.onTapCallback!();
    } else {
      Navigator.of(context).push(
        ThemeSwitcher.buildPageRoute(
          builder: (BuildContext context) {
            return ConversationView(
              chat: widget.chat,
              existingAttachments: widget.existingAttachments,
              existingText: widget.existingText,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    late Offset _tapPosition;

    return Obx(
      () => GestureDetector(
        onLongPressStart: (details) {
          _tapPosition = details.globalPosition;
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          showMenu(
            color: Get.theme.accentColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            context: context,
            position: RelativeRect.fromLTRB(
              _tapPosition.dx,
              _tapPosition.dy,
              _tapPosition.dx,
              _tapPosition.dy,
            ),
            items: <PopupMenuEntry>[
              PopupMenuItem(
                padding: EdgeInsets.zero,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await widget.chat.togglePin(!widget.chat.isPinned!);
                    if (this.mounted) setState(() {});
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(
                            widget.chat.isPinned! ? Icons.star_outline : Icons.star,
                            color: Theme.of(context).textTheme.bodyText1!.color,
                          ),
                        ),
                        Text(
                          widget.chat.isPinned! ? "Unpin" : "Pin",
                          style: Theme.of(context).textTheme.bodyText1!,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!widget.chat.isArchived!)
                PopupMenuItem(
                  padding: EdgeInsets.zero,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await widget.chat.toggleMute(!widget.chat.isMuted!);
                      if (this.mounted) setState(() {});
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15.0),
                      child: Row(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(
                              widget.chat.isMuted! ? Icons.notifications_active : Icons.notifications_off,
                              color: Theme.of(context).textTheme.bodyText1!.color,
                            ),
                          ),
                          Text(widget.chat.isMuted! ? 'Show Alerts' : 'Hide Alerts',
                              style: Theme.of(context).textTheme.bodyText1!),
                        ],
                      ),
                    ),
                  ),
                ),
              PopupMenuItem(
                padding: EdgeInsets.zero,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.chat.toggleHasUnread(!widget.chat.hasUnreadMessage!);
                    if (this.mounted) setState(() {});
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15.0),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(
                            widget.chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread,
                            color: Theme.of(context).textTheme.bodyText1!.color,
                          ),
                        ),
                        Text(widget.chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
                            style: Theme.of(context).textTheme.bodyText1!),
                      ],
                    ),
                  ),
                ),
              ),
              PopupMenuItem(
                padding: EdgeInsets.zero,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (widget.chat.isArchived!) {
                      ChatBloc().unArchiveChat(widget.chat);
                    } else {
                      ChatBloc().archiveChat(widget.chat);
                    }
                    if (this.mounted) setState(() {});
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15.0),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: Icon(
                            widget.chat.isArchived! ? Icons.restore_from_trash_rounded : Icons.delete,
                            color: Theme.of(context).textTheme.bodyText1!.color,
                          ),
                        ),
                        Text(widget.chat.isArchived! ? 'Unarchive' : 'Archive',
                            style: Theme.of(context).textTheme.bodyText1!),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.chat.isArchived!)
                PopupMenuItem(
                  padding: EdgeInsets.zero,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      ChatBloc().deleteChat(widget.chat);
                      Chat.deleteChat(widget.chat);
                      if (this.mounted) setState(() {});
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15.0),
                      child: Row(
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(
                              Icons.delete_forever,
                              color: Theme.of(context).textTheme.bodyText1!.color,
                            ),
                          ),
                          Text('Delete', style: Theme.of(context).textTheme.bodyText1!),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: Column(
          children: [
            ContactAvatarGroupWidget(
              participants: widget.chat.participants,
              chat: widget.chat,
              width: (Get.mediaQuery.size.width - 200) / 3,
              height: (Get.mediaQuery.size.width - 200) / 3,
              editable: false,
              onTap: this.onTapUpBypass,
            ),
            Container(
              padding: EdgeInsets.only(top: 10),
              child: buildSubtitle(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
