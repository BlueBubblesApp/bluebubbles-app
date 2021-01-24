import 'dart:async';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../conversation_view/conversation_view.dart';
import '../../repository/models/chat.dart';

import '../../helpers/utils.dart';

class PinnedConversationTile extends StatefulWidget {
  final Chat chat;
  final bool onTapGoToChat;
  final Function onTapCallback;
  final List<File> existingAttachments;
  final String existingText;

  PinnedConversationTile({
    Key key,
    this.chat,
    this.onTapGoToChat,
    this.existingAttachments,
    this.existingText,
    this.onTapCallback,
  }) : super(key: key);

  @override
  _PinnedConversationTileState createState() => _PinnedConversationTileState();
}

class _PinnedConversationTileState extends State<PinnedConversationTile>
    with AutomaticKeepAliveClientMixin {
  bool isPressed = false;
  bool hideDividers = false;
  bool isFetching = false;
  bool denseTiles = false;
  var _tapPosition;

  @override
  void initState() {
    super.initState();
    fetchParticipants();

    hideDividers = SettingsManager().settings.hideDividers;
    denseTiles = SettingsManager().settings.denseChatTiles;
    SettingsManager().stream.listen((Settings newSettings) {
      if (newSettings.hideDividers != hideDividers && this.mounted) {
        setState(() {
          hideDividers = newSettings.hideDividers;
        });
      }

      if (newSettings.denseChatTiles != denseTiles && this.mounted) {
        setState(() {
          denseTiles = newSettings.denseChatTiles;
        });
      }
    });

    // Listen for changes in the group
    NewMessageManager().stream.listen((NewMessageEvent event) async {
      // Make sure we have the required data to qualify for this tile
      if (event.chatGuid != widget.chat.guid) return;
      if (!event.event.containsKey("message")) return;

      // Make sure the message is a group event
      Message message = event.event["message"];
      if (!message.isGroupEvent()) return;

      // If it's a group event, let's fetch the new information and save it
      await fetchChatSingleton(widget.chat.guid);
      this.setNewChatData(forceUpdate: true);
    });
  }

  void setNewChatData({forceUpdate: false}) async {
    // Save the current participant list and get the latest
    List<Handle> ogParticipants = widget.chat.participants;
    await widget.chat.getParticipants();

    // Save the current title and generate the new one
    String ogTitle = widget.chat.title;
    await widget.chat.getTitle();

    // If the original data is different, update the state
    if (ogTitle != widget.chat.title ||
        ogParticipants.length != widget.chat.participants.length ||
        forceUpdate) {
      if (this.mounted) setState(() {});
    }
  }

  Future<void> fetchParticipants() async {
    if (isFetching) return;
    isFetching = true;

    // If our chat does not have any participants, get them
    if (isNullOrEmpty(widget.chat.participants)) {
      await widget.chat.getParticipants();
      if (!isNullOrEmpty(widget.chat.participants) && this.mounted) {
        setState(() {});
      }
    }

    isFetching = false;
  }

  void onTapUp(details) {
    if (widget.onTapGoToChat != null && widget.onTapGoToChat) {
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
      widget.onTapCallback();
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

    Future.delayed(Duration(milliseconds: 200), () {
      if (this.mounted)
        setState(() {
          isPressed = false;
        });
    });
  }

  void onTapUpBypass() {
    this.onTapUp(TapUpDetails(kind: PointerDeviceKind.touch));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Material(
        color: Theme.of(context).backgroundColor,
        child: GestureDetector(
            onTapDown: (details) {
              if (!this.mounted) return;

              setState(() {
                isPressed = true;
                _tapPosition = details.globalPosition;
              });
            },
            onTapUp: this.onTapUp,
            onTapCancel: () {
              if (!this.mounted) return;

              setState(() {
                isPressed = false;
              });
            },
            onLongPress: () async {
              HapticFeedback.mediumImpact();
              final RenderBox overlay =
                  Overlay.of(context).context.findRenderObject();
              showMenu(
                context: context,
                position: RelativeRect.fromRect(
                    _tapPosition &
                        const Size(40, 40), // smaller rect, the touch area
                    Offset.zero & overlay.size // Bigger rect, the entire screen
                    ),
                // onSelected: () => {},

                items: <PopupMenuEntry<int>>[
                  PopupMenuItem(
                    value: 0,
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.star),
                        Text("Un-Pin"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 1,
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.only(right: 4),
                          child: SvgPicture.asset(
                            "assets/icon/moon.svg",
                            color: Theme.of(context).textTheme.subtitle1.color,
                            width: Theme.of(context)
                                .textTheme
                                .bodyText2
                                .apply(fontSizeFactor: 0.75)
                                .fontSize,
                            height: Theme.of(context)
                                .textTheme
                                .bodyText2
                                .apply(fontSizeFactor: 0.75)
                                .fontSize,
                          ),
                        ),
                        Text(widget.chat.isMuted
                            ? 'Show Alerts'
                            : 'Hide Alerts'),
                      ],
                    ),
                  ),
                  // PopupMenuItem(
                  //   value: 2,
                  //   child: Row(
                  //     children: <Widget>[
                  //       Icon(Icons.delete),
                  //       Text("Delete"),
                  //     ],
                  //   ),
                  // )
                ],
              ).then<void>((int option) {
                if (option == 0) {
                  widget.chat.unpin();
                  EventDispatcher().emit("refresh", null);
                  if (this.mounted) setState(() {});
                } else if (option == 1) {
                  widget.chat.isMuted = !widget.chat.isMuted;
                  widget.chat.save(updateLocalVals: true);
                  EventDispatcher().emit("refresh", null);
                  if (this.mounted) setState(() {});
                }
              });
            },
            child: Column(children: [
              ContactAvatarGroupWidget(
                participants: widget.chat.participants,
                chat: widget.chat,
                width: 100,
                height: 100,
                editable: false,
                onTap: this.onTapUpBypass,
              ),
              Container(
                  padding: EdgeInsets.only(top: 10),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        (widget.chat.isMuted)
                            ? Container(
                                padding: EdgeInsets.only(right: 4),
                                child: SvgPicture.asset(
                                  "assets/icon/moon.svg",
                                  color: Theme.of(context)
                                      .textTheme
                                      .subtitle1
                                      .color,
                                  width: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .apply(fontSizeFactor: 0.75)
                                      .fontSize,
                                  height: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .apply(fontSizeFactor: 0.75)
                                      .fontSize,
                                ),
                              )
                            : Container(),
                        Text(widget.chat.title != null ? widget.chat.title : "",
                            style: Theme.of(context).textTheme.bodyText2.apply(
                                  fontSizeFactor: 0.75,
                                  color: Theme.of(context)
                                      .textTheme
                                      .subtitle1
                                      .color
                                      .withOpacity(
                                        0.85,
                                      ),
                                ))
                      ]))
            ])));
  }

  @override
  bool get wantKeepAlive => true;
}
