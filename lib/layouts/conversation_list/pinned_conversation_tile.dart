import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_tile_text_bubble.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  @override
  void initState() {
    super.initState();
    fetchParticipants();
  }

  Future<void> fetchParticipants() async {
    // If our chat does not have any participants, get them
    if (isNullOrEmpty(widget.chat.participants)!) {
      await widget.chat.getParticipants();
      if (!isNullOrEmpty(widget.chat.participants)! && this.mounted) {
        setState(() {});
      }
    }
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

    return Text(
      title!,
      style: style,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      maxLines: 2,
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
                          widget.chat.muteType == "mute" ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
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
                          widget.chat.hasUnreadMessage!
                              ? CupertinoIcons.person_crop_circle_badge_xmark
                              : CupertinoIcons.person_crop_circle_badge_checkmark,
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
          top: 5,
          left: 15,
          right: 15,
          bottom: 5,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Obx(
              () {
                // Great math right here
                double availableWidth = constraints.maxWidth;
                int colCount = SettingsManager().settings.pinColumnsPortrait.value;
                double spaceBetween = (colCount - 1) * 30;
                double maxWidth = ((availableWidth - spaceBetween) / colCount).floorToDouble();

                Color alphaWithoutAlpha = Color.fromARGB(
                  255,
                  (context.theme.primaryColor.red * 0.8).toInt() + (context.theme.backgroundColor.red * 0.2).toInt(),
                  (context.theme.primaryColor.green * 0.8).toInt() +
                      (context.theme.backgroundColor.green * 0.2).toInt(),
                  (context.theme.primaryColor.blue * 0.8).toInt() + (context.theme.backgroundColor.blue * 0.2).toInt(),
                );
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
                          Stack(
                            children: <Widget>[
                              ContactAvatarGroupWidget(
                                chat: widget.chat,
                                size: maxWidth,
                                editable: false,
                                onTap: this.onTapUpBypass,
                              ),
                              if (widget.chat.muteType != "mute" && (widget.chat.hasUnreadMessage ?? false))
                                Positioned(
                                  left: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                  top: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                  child: Container(
                                    width: maxWidth * 0.2,
                                    height: maxWidth * 0.2,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(maxWidth * 0.1),
                                      color: alphaWithoutAlpha,
                                    ),
                                    margin: EdgeInsets.only(right: 3),
                                  ),
                                ),
                              if (widget.chat.muteType == "mute")
                                Positioned(
                                  left: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                  top: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: <Widget>[
                                      Container(
                                        width: maxWidth * 0.2,
                                        height: maxWidth * 0.2,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(maxWidth * 0.1),
                                          color: (widget.chat.hasUnreadMessage ?? false)
                                              ? alphaWithoutAlpha
                                              : context.textTheme.subtitle1!.color,
                                        ),
                                      ),
                                      Icon(
                                        CupertinoIcons.bell_slash_fill,
                                        size: maxWidth * 0.14,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.only(
                              top: maxWidth * 0.075,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: context.textTheme.subtitle1!.fontSize! * 2),
                              child: buildSubtitle(),
                            ),
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
                              top: -sqrt(maxWidth / 2),
                              right: -sqrt(maxWidth / 2) - maxWidth * 0.25,
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
                            top: -sqrt(maxWidth / 2),
                            right: -sqrt(maxWidth / 2) - maxWidth * 0.15,
                            child: ReactionsWidget(
                              associatedMessages: [message],
                              bigPin: true,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: context.textTheme.subtitle1!.fontSize! * 2 + maxWidth * 0.05,
                        width: maxWidth,
                        child: PinnedTileTextBubble(
                          chat: widget.chat,
                          size: maxWidth,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
