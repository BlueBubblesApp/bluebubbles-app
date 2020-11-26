import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
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
  }

  void setNewChatTitle() async {
    String tmpTitle = await getFullChatTitle(widget.chat);
    if (tmpTitle != widget.chat.title) {
      if (this.mounted) {
        setState(() {
          widget.chat.title = tmpTitle;
        });
      }
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      !widget.parentProps.chat.isMuted
                          ? Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(35),
                                color: widget.parentProps.chat.hasUnreadMessage
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.8)
                                    : Colors.transparent,
                              ),
                              width: 15,
                              height: 15,
                            )
                          : SvgPicture.asset(
                              "assets/icon/moon.svg",
                              color: widget.parentProps.chat.hasUnreadMessage
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.8)
                                  : Theme.of(context).textTheme.subtitle1.color,
                              width: 15,
                              height: 15,
                            ),
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
