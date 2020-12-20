import 'dart:async';
import 'dart:io';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../conversation_view/conversation_view.dart';
import '../../repository/models/chat.dart';

import '../../helpers/utils.dart';

class ConversationTile extends StatefulWidget {
  final Chat chat;
  final bool onTapGoToChat;
  final Function onTapCallback;
  final List<File> existingAttachments;
  final String existingText;
  final Function(bool) onSelect;
  final bool inSelectMode;
  final List<Chat> selected;

  ConversationTile({
    Key key,
    this.chat,
    this.onTapGoToChat,
    this.existingAttachments,
    this.existingText,
    this.onTapCallback,
    this.onSelect,
    this.inSelectMode = false,
    this.selected,
  }) : super(key: key);

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile>
    with AutomaticKeepAliveClientMixin {
  bool hideDividers = false;
  bool isFetching = false;

  bool get selected {
    if (widget.selected == null) return false;
    return widget.selected
        .where((element) => widget.chat.guid == element.guid)
        .isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    fetchParticipants();

    hideDividers = SettingsManager().settings.hideDividers;
    SettingsManager().stream.listen((Settings newSettings) {
      if (newSettings.hideDividers != hideDividers && this.mounted) {
        setState(() {
          hideDividers = newSettings.hideDividers;
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

  Widget buildSlider(Widget child) {
    return Slidable(
      actionPane: SlidableStrechActionPane(),
      actions: [
        IconSlideAction(
          caption: widget.chat.isPinned ? 'Un-pin' : 'Pin',
          color: Colors.yellow[800],
          foregroundColor: Theme.of(context).textTheme.bodyText1.color,
          icon: Icons.star,
          onTap: () async {
            if (widget.chat.isPinned) {
              await widget.chat.unpin();
            } else {
              await widget.chat.pin();
            }

            EventDispatcher().emit("refresh", null);
            if (this.mounted) setState(() {});
          },
        ),
      ],
      secondaryActions: <Widget>[
        if (!widget.chat.isArchived)
          IconSlideAction(
            caption: widget.chat.isMuted ? 'Show Alerts' : 'Hide Alerts',
            color: Colors.purple[700],
            icon: widget.chat.isMuted
                ? Icons.notifications_active
                : Icons.notifications_off,
            onTap: () async {
              widget.chat.isMuted = !widget.chat.isMuted;
              await widget.chat.save(updateLocalVals: true);
              if (this.mounted) setState(() {});
            },
          ),
        if (widget.chat.isArchived)
          IconSlideAction(
            caption: "Delete",
            color: Colors.red,
            icon: Icons.delete_forever,
            onTap: () async {
              ChatBloc().deleteChat(widget.chat);
              Chat.deleteChat(widget.chat);
            },
          ),
        if (!widget.chat.hasUnreadMessage)
          IconSlideAction(
            caption: 'Mark Unread',
            color: Colors.blue,
            icon: Icons.notifications,
            onTap: () {
              widget.chat.setUnreadStatus(true);
              ChatBloc().updateChatPosition(widget.chat);
            },
          ),
        IconSlideAction(
          caption: widget.chat.isArchived ? 'UnArchive' : 'Archive',
          color: widget.chat.isArchived ? Colors.blue : Colors.red,
          icon: widget.chat.isArchived ? Icons.replay : Icons.delete,
          onTap: () {
            if (widget.chat.isArchived) {
              ChatBloc().unArchiveChat(widget.chat);
            } else {
              ChatBloc().archiveChat(widget.chat);
            }
          },
        ),
      ],
      child: child,
    );
  }

  Widget buildTitle() => Text(
        widget.chat.title != null ? widget.chat.title : "",
        style: Theme.of(context).textTheme.bodyText1,
        maxLines: 1,
      );

  Widget buildSubtitle() => widget.chat.latestMessageText != null &&
          !(widget.chat.latestMessageText is String)
      ? widget.chat.latestMessageText
      : Text(
          widget.chat.latestMessageText != null
              ? widget.chat.latestMessageText
              : "",
          style: Theme.of(context).textTheme.subtitle1.apply(
                color: Theme.of(context).textTheme.subtitle1.color.withOpacity(
                      0.85,
                    ),
              ),
          maxLines: 1,
        );

  Widget buildLeading() {
    if (!selected) {
      return ContactAvatarGroupWidget(
        participants: widget.chat.participants,
        chat: widget.chat,
        width: 40,
        height: 40,
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Theme.of(context).primaryColor,
        ),
        width: 40,
        height: 40,
        child: Center(
          child: Icon(
            Icons.check,
            color: Theme.of(context).textTheme.bodyText1.color,
            size: 20,
          ),
        ),
      );
    }
  }

  Widget buildDate() => Text(
        widget.chat.getDateText(),
        style: Theme.of(context).textTheme.subtitle2.apply(
            color:
                Theme.of(context).textTheme.subtitle2.color.withOpacity(0.85)),
      );

  void onTap() {
    if (widget.onTapGoToChat != null && widget.onTapGoToChat) {
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
      widget.onTapCallback();
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

  void onSelect() {
    if (widget.onSelect != null) {
      widget.onSelect(!selected);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ThemeSwitcher(
      iOSSkin: _Cupertino(parent: this, parentProps: widget),
      materialSkin: _Material(
        parent: this,
        parentProps: widget,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _Cupertino extends StatefulWidget {
  _Cupertino({Key key, @required this.parent, @required this.parentProps})
      : super(key: key);
  final _ConversationTileState parent;
  final ConversationTile parentProps;

  @override
  __CupertinoState createState() => __CupertinoState();
}

class __CupertinoState extends State<_Cupertino> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return widget.parent.buildSlider(
      Material(
        color: !isPressed
            ? Theme.of(context).backgroundColor
            : Theme.of(context).backgroundColor.lightenOrDarken(30),
        child: GestureDetector(
          onTapDown: (details) {
            if (!this.mounted) return;

            setState(() {
              isPressed = true;
            });
          },
          onTapUp: (details) {
            widget.parent.onTap();
            Future.delayed(Duration(milliseconds: 200), () {
              if (this.mounted)
                setState(() {
                  isPressed = false;
                });
            });
          },
          onTapCancel: () {
            if (!this.mounted) return;

            setState(() {
              isPressed = false;
            });
          },
          onLongPress: () async {
            HapticFeedback.mediumImpact();
            await widget.parent.widget.chat
                .setUnreadStatus(!widget.parent.widget.chat.hasUnreadMessage);
            if (this.mounted) setState(() {});
          },
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(left: 30.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: (!widget.parent.hideDividers)
                        ? Border(
                            top: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 0.5,
                            ),
                          )
                        : null,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.only(left: 0),
                    title: widget.parent.buildTitle(),
                    subtitle: widget.parent.buildSubtitle(),
                    leading: widget.parent.buildLeading(),
                    trailing: Container(
                      padding: EdgeInsets.only(right: 3),
                      width: 80,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          Container(
                            padding: EdgeInsets.only(right: 2),
                            child: widget.parent.buildDate(),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).textTheme.subtitle1.color,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Container(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Stack(
                        alignment: AlignmentDirectional.centerStart,
                        children: [
                          (!widget.parent.widget.chat.isMuted &&
                                  widget.parent.widget.chat.hasUnreadMessage)
                              ? Container(
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(35),
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.8)),
                                  width: 15,
                                  height: 15,
                                )
                              : Container(),
                          (widget.parent.widget.chat.isPinned)
                              ? Icon(
                                  Icons.star,
                                  size: 15,
                                  color: Colors.yellow[
                                      AdaptiveTheme.of(context).mode ==
                                              AdaptiveThemeMode.dark
                                          ? 100
                                          : 700],
                                )
                              : Container(),
                        ],
                      ),
                      (widget.parent.widget.chat.isMuted)
                          ? SvgPicture.asset(
                              "assets/icon/moon.svg",
                              color: widget.parentProps.chat.hasUnreadMessage
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.8)
                                  : Theme.of(context).textTheme.subtitle1.color,
                              width: 15,
                              height: 15,
                            )
                          : Container()
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Material extends StatelessWidget {
  const _Material({Key key, @required this.parent, @required this.parentProps})
      : super(key: key);
  final _ConversationTileState parent;
  final ConversationTile parentProps;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: parent.selected
          ? Theme.of(context).primaryColor.withAlpha(120)
          : Theme.of(context).backgroundColor,
      child: InkWell(
        onTap: () {
          if (parent.selected) {
            parent.onSelect();
            HapticFeedback.lightImpact();
          } else if (parent.widget.inSelectMode) {
            parent.onSelect();
            HapticFeedback.lightImpact();
          } else {
            parent.onTap();
          }
        },
        onLongPress: () {
          parent.onSelect();
        },
        child: Container(
          decoration: BoxDecoration(
            border: (!parent.hideDividers)
                ? Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: ListTile(
            title: parent.buildTitle(),
            subtitle: parent.buildSubtitle(),
            leading: Stack(
              alignment: Alignment.topRight,
              children: [
                parent.buildLeading(),
                if (!parent.widget.chat.isMuted)
                  Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: parent.widget.chat.hasUnreadMessage
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                    ),
                  ),
              ],
            ),
            trailing: Container(
              padding: EdgeInsets.only(right: 3),
              width: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (parent.widget.chat.isMuted)
                    Icon(
                      Icons.notifications_off,
                      color: Theme.of(context).textTheme.subtitle1.color,
                      size: 15,
                    ),
                  Container(
                    padding: EdgeInsets.only(right: 2, left: 2),
                    child: parent.buildDate(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
