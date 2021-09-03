import 'dart:async';
import 'dart:io';

import 'package:assorted_layout_widgets/assorted_layout_widgets.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_tile_text_bubble.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

class PinnedConversationTile extends StatefulWidget {
  final Chat chat;
  final List<File> existingAttachments;
  final String? existingText;

  PinnedConversationTile({
    Key? key,
    required this.chat,
    this.existingAttachments = const [],
    this.existingText,
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
  RxBool showTypingIndicator = false.obs;

  void loadBrightness() {
    Color now = context.theme.backgroundColor;
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
      try {
        await fetchChatSingleton(widget.chat.guid!);
      } catch (ex) {
        Logger.error(ex.toString());
      }

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
    CustomNavigator.pushAndRemoveUntil(
      context,
      ConversationView(
        chat: widget.chat,
        existingAttachments: widget.existingAttachments,
        existingText: widget.existingText,
      ),
      (route) => route.isFirst,
    );
  }

  void onTapUpBypass() {
    this.onTapUp(TapUpDetails(kind: PointerDeviceKind.touch));
  }

  Widget buildSubtitle() {
    final hideInfo = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateNames =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    TextStyle? style = context.textTheme.subtitle1!.apply(fontSizeFactor: 0.85);
    String? title = widget.chat.title != null ? widget.chat.title : "";

    if (generateNames)
      title = widget.chat.fakeParticipants.length == 1 ? widget.chat.fakeParticipants[0] : "Group Chat";
    else if (hideInfo) style = style.copyWith(color: Colors.transparent);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (widget.chat.muteType != "mute" && (widget.chat.hasUnreadMessage ?? false))
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: context.theme.primaryColor.withOpacity(0.8),
              ),
              margin: EdgeInsets.only(right: 3)),
        if (widget.chat.muteType == "mute")
          Container(
            margin: EdgeInsets.only(right: 3),
            child: SvgPicture.asset(
              "assets/icon/moon.svg",
              color: widget.chat.hasUnreadMessage!
                  ? context.theme.primaryColor.withOpacity(0.8)
                  : context.textTheme.subtitle1!.color,
              width: 8,
              height: 8,
            ),
          ),
        Flexible(
          child: TextOneLine(
            title!,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void onTap() {
    CustomNavigator.pushAndRemoveUntil(
      context,
      ConversationView(
        chat: widget.chat,
        existingAttachments: widget.existingAttachments,
        existingText: widget.existingText,
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    late Offset _tapPosition;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        _tapPosition = details.globalPosition;
      },
      onTap: onTapUpBypass,
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
                          widget.chat.isPinned! ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text(
                        widget.chat.isPinned! ? "Unpin" : "Pin",
                        style: context.textTheme.bodyText1!,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuItem(
              padding: EdgeInsets.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await widget.chat.toggleMute(widget.chat.muteType != "mute");
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
                          widget.chat.muteType == "mute" ? Icons.notifications_active : Icons.notifications_off,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text(widget.chat.muteType == "mute" ? 'Show Alerts' : 'Hide Alerts',
                          style: context.textTheme.bodyText1!),
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
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          widget.chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text(widget.chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
                          style: context.textTheme.bodyText1!),
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
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          widget.chat.isArchived! ? CupertinoIcons.tray_arrow_up : CupertinoIcons.tray_arrow_down,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text(widget.chat.isArchived! ? 'Unarchive' : 'Archive', style: context.textTheme.bodyText1!),
                    ],
                  ),
                ),
              ),
            ),
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
                  padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.delete_forever,
                          color: context.textTheme.bodyText1!.color,
                        ),
                      ),
                      Text('Delete', style: context.textTheme.bodyText1!),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 10,
          right: 10,
          bottom: 10,
        ),
        child: Obx(
          () {
            int colCount = SettingsManager().settings.pinColumnsPortrait.value;
            if (context.mediaQuery.orientation != Orientation.portrait) {
              colCount = (colCount / context.mediaQuerySize.height * context.mediaQuerySize.width).floor();
            }
            int spaceBetween = (colCount - 1) * 20;
            int spaceAround = 20;

            // Great math right here
            double maxWidth = ((context.mediaQuerySize.width - spaceBetween - spaceAround) / colCount).floorToDouble();
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  Column(
                    children: [
                      ContactAvatarGroupWidget(
                        chat: widget.chat,
                        size: (context.mediaQueryShortestSide - 150) / 3,
                        editable: false,
                        onTap: this.onTapUpBypass,
                      ),
                      Container(
                        padding: EdgeInsets.only(
                          top: 10,
                          left: 10,
                          right: 10,
                        ),
                        child: buildSubtitle(),
                      ),
                    ],
                  ),
                  StreamBuilder<Map<String, dynamic>>(
                    stream: CurrentChat.getCurrentChat(widget.chat)?.stream as Stream<Map<String, dynamic>>?,
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      if (snapshot.connectionState == ConnectionState.active &&
                          snapshot.hasData &&
                          snapshot.data["type"] == CurrentChatEvent.TypingStatus) {
                        showTypingIndicator.value = snapshot.data["data"];
                      }
                      if (showTypingIndicator.value) {
                        return Positioned(
                          top: -11,
                          right: -13,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 32),
                            child: FittedBox(
                              child: TypingIndicator(
                                visible: true,
                              ),
                            ),
                          ),
                        );
                      }
                      return Container();
                    },
                  ),
                  FutureBuilder<Message>(
                    future: widget.chat.latestMessage,
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      if (!(widget.chat.hasUnreadMessage ?? false)) return Container();
                      if (showTypingIndicator.value) return Container();
                      if (!snapshot.hasData) return Container();
                      Message message = snapshot.data;
                      if ([null, ""].contains(message.associatedMessageGuid) || (message.isFromMe ?? false)) {
                        return Container();
                      }
                      return Positioned(
                        top: -12,
                        right: -8,
                        child: ReactionsWidget(
                          associatedMessages: [message],
                          bigPin: true,
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 20,
                    width: maxWidth,
                    child: PinnedTileTextBubble(
                      chat: widget.chat,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
