import 'dart:async';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/indicator.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class ConversationTile extends StatefulWidget {
  final Chat chat;
  final List<PlatformFile> existingAttachments;
  final String? existingText;
  final Function(bool)? onSelect;
  final bool inSelectMode;
  final List<Chat> selected;
  final Widget? subtitle;

  ConversationTile({
    Key? key,
    required this.chat,
    this.existingAttachments = const [],
    this.existingText,
    this.onSelect,
    this.inSelectMode = false,
    this.selected = const [],
    this.subtitle,
  }) : super(key: key);

  @override
  _ConversationTileState createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> with AutomaticKeepAliveClientMixin {
  // Typing indicator
  bool showTypingIndicator = false;
  RxBool shouldHighlight = false.obs;
  RxBool shouldPartialHighlight = false.obs;

  bool get selected {
    if (widget.selected.isEmpty) return false;
    return widget.selected.where((element) => widget.chat.guid == element.guid).isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    if (kIsDesktop || kIsWeb) {
      shouldHighlight.value = ChatManager().activeChat?.chat.guid == widget.chat.guid;
    }

    // Listen for changes in the group
    NewMessageManager().stream.listen((NewMessageEvent event) async {
      // Make sure we have the required data to qualify for this tile
      if (event.chatGuid != widget.chat.guid) return;
      if (!event.event.containsKey("message")) return;
      // Make sure the message is a group event
      Message message = event.event["message"];
      if (!message.isGroupEvent()) return;

      // If it's a group event, let's fetch the new information and save it
      try {
        await fetchChatSingleton(widget.chat.guid);
      } catch (ex) {
        Logger.error(ex.toString());
      }

      setNewChatData(forceUpdate: true);
    });

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'update-highlight' && mounted) {
        if ((kIsDesktop || kIsWeb) && event['data'] == widget.chat.guid) {
          shouldHighlight.value = true;
        } else if (shouldHighlight.value = true) {
          shouldHighlight.value = false;
        }
      }
    });
  }

  void update() {
    setState(() {});
  }

  void setNewChatData({forceUpdate = false}) {
    // Save the current participant list and get the latest
    List<Handle> ogParticipants = widget.chat.participants;
    widget.chat.getParticipants();

    // Save the current title and generate the new one
    String? ogTitle = widget.chat.title;
    widget.chat.getTitle();

    // If the original data is different, update the state
    if (ogTitle != widget.chat.title || ogParticipants.length != widget.chat.participants.length || forceUpdate) {
      if (mounted) setState(() {});
    }
  }

  void onTapUp(details) {
    if (widget.inSelectMode && widget.onSelect != null) {
      onSelect();
    } else {
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
  }

  void onTapUpBypass() {
    onTapUp(TapUpDetails(kind: PointerDeviceKind.touch));
  }

  Widget buildSlider(Widget child) {
    if (kIsWeb || kIsDesktop) return child;
    return Obx(() => Slidable(
          startActionPane: ActionPane(
            motion: StretchMotion(),
            extentRatio: 0.2,
            children: [
              if (SettingsManager().settings.iosShowPin.value)
                SlidableAction(
                  label: widget.chat.isPinned! ? 'Unpin' : 'Pin',
                  backgroundColor: Colors.yellow[800]!,
                  foregroundColor: Colors.white,
                  icon: widget.chat.isPinned! ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
                  onPressed: (context) {
                    widget.chat.togglePin(!widget.chat.isPinned!);
                    EventDispatcher().emit("refresh", null);
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
          endActionPane: ActionPane(
            motion: StretchMotion(),
            extentRatio: 0.9,
            children: [
              if (!widget.chat.isArchived! && SettingsManager().settings.iosShowAlert.value)
                SlidableAction(
                  label: widget.chat.muteType == "mute" ? 'Unmute' : 'Mute',
                  backgroundColor: Colors.purple[700]!,
                  flex: 2,
                  icon: widget.chat.muteType == "mute" ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
                  onPressed: (context) {
                    widget.chat.toggleMute(widget.chat.muteType != "mute");
                    if (mounted) setState(() {});
                  },
                ),
              if (SettingsManager().settings.iosShowDelete.value)
                SlidableAction(
                  label: "Delete",
                  backgroundColor: Colors.red,
                  flex: 2,
                  icon: CupertinoIcons.trash,
                  onPressed: (context) {
                    ChatBloc().deleteChat(widget.chat);
                    Chat.deleteChat(widget.chat);
                  },
                ),
              if (SettingsManager().settings.iosShowMarkRead.value)
                SlidableAction(
                  label: widget.chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
                  backgroundColor: Colors.blue,
                  flex: 3,
                  icon: widget.chat.hasUnreadMessage!
                      ? CupertinoIcons.person_crop_circle_badge_checkmark
                      : CupertinoIcons.person_crop_circle_badge_exclam,
                  onPressed: (context) {
                    ChatBloc().toggleChatUnread(widget.chat, !widget.chat.hasUnreadMessage!);
                  },
                ),
              if (SettingsManager().settings.iosShowArchive.value)
                SlidableAction(
                  label: widget.chat.isArchived! ? 'UnArchive' : 'Archive',
                  backgroundColor: widget.chat.isArchived! ? Colors.blue : Colors.red,
                  flex: 2,
                  icon: widget.chat.isArchived! ? CupertinoIcons.tray_arrow_up : CupertinoIcons.tray_arrow_down,
                  onPressed: (context) {
                    if (widget.chat.isArchived!) {
                      ChatBloc().unArchiveChat(widget.chat);
                    } else {
                      ChatBloc().archiveChat(widget.chat);
                    }
                  },
                ),
            ],
          ),
          child: child,
        ));
  }

  Future<String?> getOrUpdateChatTitle() async {
    if (widget.chat.title != null) {
      return widget.chat.title;
    } else {
      return widget.chat.getTitle();
    }
  }

  Widget buildTitle() {
    final hideInfo = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateNames =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    TextStyle? style = Theme.of(context).textTheme.bodyText1;

    return Obx(() {
      widget.chat.getTitle();
      String title = widget.chat.title ?? "Fake Person";
      if (generateNames) {
        title = widget.chat.fakeNames.length == 1 ? widget.chat.fakeNames[0] : "Group Chat";
      } else if (hideInfo) {
        style = style?.copyWith(color: Colors.transparent);
      }
      return RichText(
          text: TextSpan(
            children: MessageHelper.buildEmojiText(
              title,
              style!
                  .copyWith(
                      fontWeight: SettingsManager().settings.skin.value == Skins.Material &&
                              (widget.chat.hasUnreadMessage ?? false)
                          ? FontWeight.bold
                          : shouldHighlight.value
                              ? FontWeight.w600
                              : null,
                      color: shouldHighlight.value
                          ? SettingsManager().settings.skin.value == Skins.iOS
                              ? Colors.white
                              : null
                          : null)
                  .apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1.1 : 1.0),
            ),
          ),
          overflow: TextOverflow.ellipsis);
    });
  }

  Widget buildSubtitle() {
    return Obx(
      () {
        String latestText = widget.chat.latestMessage != null
            ? MessageHelper.getNotificationText(widget.chat.latestMessage!)
            : widget.chat.latestMessageText ?? "";
        final hideContent =
            SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideMessageContent.value;
        final generateContent = SettingsManager().settings.redactedMode.value &&
            SettingsManager().settings.generateFakeMessageContent.value;

        TextStyle style = Theme.of(context).textTheme.subtitle1!.apply().copyWith(
              fontWeight: shouldHighlight.value ? FontWeight.w500 : null,
              color: shouldHighlight.value
                  ? SettingsManager().settings.skin.value == Skins.iOS
                      ? Colors.white.withOpacity(0.75)
                      : null
                  : context.textTheme.subtitle1!.color!.withOpacity(0.85),
            );

        if (generateContent) {
          latestText = widget.chat.fakeLatestMessageText ?? "";
        } else if (hideContent) {
          style = style.copyWith(color: Colors.transparent);
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: RichText(
            text: TextSpan(
                children: MessageHelper.buildEmojiText(
              latestText,
              style
                  .copyWith(
                    fontWeight: SettingsManager().settings.skin.value == Skins.Material &&
                            (widget.chat.hasUnreadMessage ?? false)
                        ? FontWeight.w600
                        : null,
                    color: SettingsManager().settings.skin.value == Skins.Material &&
                            (widget.chat.hasUnreadMessage ?? false)
                        ? Theme.of(context).textTheme.bodyText1!.color
                        : null,
                  )
                  .apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 0.95 : 1.0),
            )),
            overflow: TextOverflow.ellipsis,
            maxLines: SettingsManager().settings.skin.value == Skins.Material ? 3 : 2,
          ),
        );
      },
    );
  }

  Widget buildLeading() {
    return StreamBuilder<Map<String, dynamic>>(
        stream: ChatManager().getChatController(widget.chat)?.stream as Stream<Map<String, dynamic>>?,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.active &&
              snapshot.hasData &&
              snapshot.data["type"] == ChatControllerEvent.TypingStatus) {
            showTypingIndicator = snapshot.data["data"];
          }
          double height = Theme.of(context).textTheme.subtitle1!.fontSize! * 1.25;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: 2, right: 2),
                child: !selected
                    ? ContactAvatarGroupWidget(
                        chat: widget.chat,
                        size: 40,
                        editable: false,
                        onTap: onTapUpBypass,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Theme.of(context).primaryColor,
                        ),
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Icon(
                            Icons.check,
                            color: Theme.of(context).textTheme.bodyText1!.color,
                            size: 20,
                          ),
                        ),
                      ),
              ),
              if (showTypingIndicator)
                Positioned(
                  top: 30,
                  left: 20,
                  height: height,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    child: TypingIndicator(
                      chatList: true,
                      visible: true,
                    ),
                  ),
                ),
            ],
          );
        });
  }

  Widget _buildDate() {
    MessageMarkers? markers = ChatManager().getChatController(widget.chat)?.messageMarkers;
    return kIsWeb || markers == null
        ? Text(buildDate(widget.chat.latestMessageDate),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.subtitle2!.copyWith(
                  color: shouldHighlight.value
                      ? SettingsManager().settings.skin.value == Skins.iOS
                          ? Colors.white.withOpacity(0.75)
                          : null
                      : context.textTheme.subtitle1!.color!.withOpacity(0.85),
                ),
            overflow: TextOverflow.clip)
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 100.0),
            child: Obx(() {
              Message? message = widget.chat.latestMessageGetter;
              Indicator show = shouldShow(message, markers.myLastMessage.value, markers.lastReadMessage.value,
                  markers.lastDeliveredMessage.value);
              return Text(
                  (message?.error ?? 0) > 0
                      ? "Error"
                      : ((show == Indicator.READ
                          ? "Read\n${buildDate(message?.dateRead)}"
                          : show == Indicator.DELIVERED
                              ? "Delivered\n${buildDate(message?.dateDelivered)}"
                              : show == Indicator.SENT
                                  ? "Sent\n${buildDate(message?.dateCreated)}"
                                  : buildDate(message?.dateCreated))),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.subtitle2!.copyWith(
                        color: (message?.error ?? 0) > 0
                            ? Colors.red
                            : shouldHighlight.value
                                ? SettingsManager().settings.skin.value == Skins.iOS
                                    ? Colors.white.withOpacity(0.75)
                                    : null
                                : context.textTheme.subtitle1!.color!.withOpacity(0.85),
                      ),
                  overflow: TextOverflow.clip);
            }),
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

  void onSelect() {
    if (widget.onSelect != null) {
      widget.onSelect!(!selected);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ThemeSwitcher(
      iOSSkin: _Cupertino(
        parent: this,
        parentProps: widget,
      ),
      materialSkin: _Material(
        parent: this,
        parentProps: widget,
      ),
      samsungSkin: _Samsung(
        parent: this,
        parentProps: widget,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _Cupertino extends StatelessWidget {
  _Cupertino({Key? key, required this.parent, required this.parentProps}) : super(key: key);
  final _ConversationTileState parent;
  final ConversationTile parentProps;

  @override
  Widget build(BuildContext context) {
    return parent.buildSlider(
      Obx(
        () => Material(
          color: parent.shouldPartialHighlight.value
              ? context.theme.primaryColor.withAlpha(100)
              : parent.shouldHighlight.value
                  ? context.theme.primaryColor
                  : context.theme.backgroundColor,
          borderRadius:
              BorderRadius.circular(parent.shouldHighlight.value || parent.shouldPartialHighlight.value ? 8 : 0),
          child: GestureDetector(
            onTapUp: (details) {
              parent.onTapUp(details);
            },
            onSecondaryTapUp: (details) async {
              if (kIsWeb) {
                (await html.document.onContextMenu.first).preventDefault();
              }
              parent.shouldPartialHighlight.value = true;
              await showConversationTileMenu(
                context,
                parent,
                parent.widget.chat,
                details.globalPosition,
                context.textTheme,
              );
              parent.shouldPartialHighlight.value = false;
            },
            onLongPress: () async {
              HapticFeedback.mediumImpact();
              await ChatBloc().toggleChatUnread(parent.widget.chat, !parent.widget.chat.hasUnreadMessage!);
              if (parent.mounted) parent.update();
            },
            child: Stack(
              alignment: Alignment.centerLeft,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Obx(
                    () => Container(
                      decoration: BoxDecoration(
                        border: (!SettingsManager().settings.hideDividers.value)
                            ? Border(
                                bottom: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 0.5,
                                ),
                              )
                            : null,
                      ),
                      child: ListTile(
                        dense: SettingsManager().settings.denseChatTiles.value,
                        contentPadding: EdgeInsets.only(left: 0),
                        minVerticalPadding: 10,
                        title: parent.buildTitle(),
                        subtitle: parent.widget.subtitle ?? parent.buildSubtitle(),
                        leading: parent.buildLeading(),
                        trailing: Container(
                          padding: EdgeInsets.only(right: 8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                Container(
                                  padding: EdgeInsets.only(right: 3),
                                  child: parent._buildDate(),
                                ),
                                Icon(
                                  SettingsManager().settings.skin.value == Skins.iOS
                                      ? CupertinoIcons.forward
                                      : Icons.arrow_forward,
                                  color:
                                      parent.shouldHighlight.value ? Colors.white : context.textTheme.subtitle1!.color!,
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: Container(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Stack(
                          alignment: AlignmentDirectional.centerStart,
                          children: [
                            (parent.widget.chat.muteType != "mute" && parent.widget.chat.hasUnreadMessage!)
                                ? Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(35),
                                      color: Theme.of(context).primaryColor.withOpacity(0.8),
                                    ),
                                    width: 10,
                                    height: 10,
                                  )
                                : Container(),
                            parent.widget.chat.isPinned!
                                ? Icon(
                                    CupertinoIcons.pin,
                                    size: 10,
                                    color: Colors
                                        .yellow[AdaptiveTheme.of(context).mode == AdaptiveThemeMode.dark ? 100 : 700],
                                  )
                                : Container(),
                          ],
                        ),
                        parent.widget.chat.muteType == "mute"
                            ? SvgPicture.asset(
                                "assets/icon/moon.svg",
                                color: parent.shouldHighlight.value ? Colors.white : parentProps.chat.hasUnreadMessage!
                                    ? Theme.of(context).primaryColor.withOpacity(0.8)
                                    : Theme.of(context).textTheme.subtitle1!.color,
                                width: 10,
                                height: 10,
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
      ),
    );
  }
}

class _Material extends StatelessWidget {
  const _Material({Key? key, required this.parent, required this.parentProps}) : super(key: key);
  final _ConversationTileState parent;
  final ConversationTile parentProps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        5,
        3,
        0,
        3,
      ),
      child: Obx(
        () {
          bool shouldPartialHighlight = parent.shouldPartialHighlight.value;
          bool shouldHighlight = parent.shouldHighlight.value;
          return Material(
            clipBehavior: Clip.hardEdge,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            color: parent.selected
                ? context.theme.backgroundColor.lightenOrDarken(20)
                : shouldPartialHighlight
                    ? context.theme.primaryColor.withAlpha(100)
                    : shouldHighlight
                        ? context.theme.colorScheme.secondary
                        : context.theme.backgroundColor,
            child: GestureDetector(
              onSecondaryTapUp: (details) async {
                if (kIsWeb) {
                  (await html.document.onContextMenu.first).preventDefault();
                }
                parent.shouldPartialHighlight.value = true;
                await showConversationTileMenu(
                  context,
                  parent,
                  parent.widget.chat,
                  details.globalPosition,
                  context.textTheme,
                );
                parent.shouldPartialHighlight.value = false;
              },
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
                child: Obx(
                  () => Padding(
                    padding: EdgeInsets.only(left: kIsDesktop ? 5 : 0),
                    child: Container(
                      decoration: BoxDecoration(
                        border: (!SettingsManager().settings.hideDividers.value)
                            ? Border(
                                top: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                  width: 0.5,
                                ),
                              )
                            : null,
                      ),
                      child: ListTile(
                        dense: SettingsManager().settings.denseChatTiles.value,
                        title: parent.buildTitle(),
                        subtitle: parent.widget.subtitle ?? parent.buildSubtitle(),
                        minVerticalPadding: 10,
                        leading: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            parent.buildLeading(),
                            if (parent.widget.chat.muteType != "mute")
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: parent.widget.chat.hasUnreadMessage!
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                ),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: EdgeInsets.only(right: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  padding: EdgeInsets.only(right: 2, left: 2),
                                  child: parent._buildDate(),
                                ),
                                SizedBox(height: 5),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (parent.widget.chat.isPinned!)
                                      Icon(Icons.push_pin,
                                          size: 15, color: Theme.of(context).textTheme.subtitle1!.color),
                                    SizedBox(width: 5),
                                    if (parent.widget.chat.muteType == "mute")
                                      Icon(
                                        Icons.notifications_off,
                                        color: parent.widget.chat.hasUnreadMessage!
                                            ? Theme.of(context).primaryColor.withOpacity(0.8)
                                            : Theme.of(context).textTheme.subtitle1!.color,
                                        size: 15,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Samsung extends StatelessWidget {
  const _Samsung({Key? key, required this.parent, required this.parentProps}) : super(key: key);
  final _ConversationTileState parent;
  final ConversationTile parentProps;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        bool shouldPartialHighlight = parent.shouldPartialHighlight.value;
        bool shouldHighlight = parent.shouldHighlight.value;
        return Material(
          color: parent.selected
              ? context.theme.primaryColor.withAlpha(120)
              : shouldPartialHighlight
                  ? context.theme.primaryColor.withAlpha(100)
                  : shouldHighlight
                      ? context.theme.backgroundColor.lightenOrDarken(10)
                      : Colors.transparent,
          child: GestureDetector(
            onSecondaryTapUp: (details) async {
              if (kIsWeb) {
                (await html.document.onContextMenu.first).preventDefault();
              }
              parent.shouldPartialHighlight.value = true;
              await showConversationTileMenu(
                context,
                parent,
                parent.widget.chat,
                details.globalPosition,
                context.textTheme,
              );
              parent.shouldPartialHighlight.value = false;
            },
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
              child: Obx(
                () => Container(
                  decoration: BoxDecoration(
                    border: (!SettingsManager().settings.hideDividers.value)
                        ? Border(
                            top: BorderSide(
                              color: Color(0xff2F2F2F),
                              width: 0.5,
                            ),
                          )
                        : null,
                  ),
                  child: ListTile(
                    dense: SettingsManager().settings.denseChatTiles.value,
                    title: parent.buildTitle(),
                    subtitle: parent.widget.subtitle ?? parent.buildSubtitle(),
                    minVerticalPadding: 10,
                    leading: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        parent.buildLeading(),
                        if (parent.widget.chat.muteType != "mute")
                          Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: parent.widget.chat.hasUnreadMessage!
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: EdgeInsets.only(right: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            if (parent.widget.chat.isPinned!) Icon(Icons.star, size: 15, color: Colors.yellow),
                            if (parent.widget.chat.muteType == "mute")
                              Icon(
                                Icons.notifications_off,
                                color: Theme.of(context).textTheme.subtitle1!.color,
                                size: 15,
                              ),
                            Container(
                              padding: EdgeInsets.only(right: 2, left: 2),
                              child: parent._buildDate(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
