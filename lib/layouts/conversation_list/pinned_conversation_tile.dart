import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/helpers/indicator.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_tile_text_bubble.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/platform_file.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class PinnedConversationTile extends StatefulWidget {
  final Chat chat;
  final List<PlatformFile> existingAttachments;
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

class _PinnedConversationTileState extends State<PinnedConversationTile> {
  // Typing indicator
  RxBool showTypingIndicator = false.obs;

  @override
  void initState() {
    super.initState();
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

      setNewChatData(forceUpdate: true);
    });
  }

  void setNewChatData({forceUpdate = false}) async {
    // Save the current participant list and get the latest
    List<Handle> ogParticipants = widget.chat.participants;
    await widget.chat.getParticipants();

    // Save the current title and generate the new one
    String? ogTitle = widget.chat.title;
    await widget.chat.getTitle();

    // If the original data is different, update the state
    if (ogTitle != widget.chat.title || ogParticipants.length != widget.chat.participants.length || forceUpdate) {
      if (mounted) setState(() {});
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
    onTapUp(TapUpDetails(kind: PointerDeviceKind.touch));
  }

  Widget buildSubtitle() {
    final hideInfo = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateNames =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    TextStyle? style = context.textTheme.subtitle1!.apply(fontSizeFactor: 0.85);
    if (widget.chat.title == null) widget.chat.getTitle();
    String title = widget.chat.title ?? "Fake Person";

    if (generateNames) {
      title = (widget.chat.fakeParticipants.length == 1 ? widget.chat.fakeParticipants[0] : "Group Chat")!;
    } else if (hideInfo) {
      style = style.copyWith(color: Colors.transparent);
    }

    return Text(
      title,
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

    late Offset _tapPosition;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) {
        _tapPosition = details.globalPosition;
      },
      onTap: onTapUpBypass,
      onLongPress: () {
        showConversationTileMenu(
          context,
          this,
          widget.chat,
          _tapPosition,
          context.textTheme,
        );
      },
      onSecondaryTapUp: (details) async {
        if (kIsWeb) {
          (await html.document.onContextMenu.first).preventDefault();
        }
        showConversationTileMenu(
          context,
          this,
          widget.chat,
          details.globalPosition,
          context.textTheme,
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
                                onTap: onTapUpBypass,
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
                          return Obx(() {
                            MessageMarkers? markers =
                                CurrentChat.getCurrentChat(widget.chat)?.messageMarkers.markers.value ?? null.obs.value;
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
                            if (shouldShow(widget.chat.latestMessage, markers?.myLastMessage, markers?.lastReadMessage,
                                    markers?.lastDeliveredMessage) !=
                                Indicator.NONE) {
                              return Positioned(
                                left: sqrt(maxWidth) - maxWidth * 0.05 * sqrt(2),
                                top: maxWidth - maxWidth * 0.13 * 2,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: <Widget>[
                                    Container(
                                      width: maxWidth * 0.27,
                                      height: maxWidth * 0.27,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Theme.of(context).backgroundColor, width: 1),
                                        borderRadius: BorderRadius.circular(30),
                                        color: (widget.chat.hasUnreadMessage ?? false)
                                            ? alphaWithoutAlpha
                                            : context.textTheme.subtitle1!.color,
                                      ),
                                    ),
                                    Transform.rotate(
                                      angle: shouldShow(widget.chat.latestMessage, markers?.myLastMessage,
                                                  markers?.lastReadMessage, markers?.lastDeliveredMessage) !=
                                              Indicator.SENT
                                          ? pi / 2
                                          : 0,
                                      child: Icon(
                                        shouldShow(widget.chat.latestMessage, markers?.myLastMessage,
                                                    markers?.lastReadMessage, markers?.lastDeliveredMessage) ==
                                                Indicator.DELIVERED
                                            ? CupertinoIcons.location_north_fill
                                            : shouldShow(widget.chat.latestMessage, markers?.myLastMessage,
                                                        markers?.lastReadMessage, markers?.lastDeliveredMessage) ==
                                                    Indicator.READ
                                                ? CupertinoIcons.location_north
                                                : CupertinoIcons.location_fill,
                                        color: Colors.white,
                                        size: maxWidth * 0.14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Container();
                          });
                        },
                      ),
                      FutureBuilder<Message>(
                        future: widget.chat.latestMessageFuture,
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
}
