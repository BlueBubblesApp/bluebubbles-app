import 'dart:async';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/indicator.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_peek_view.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> with AutomaticKeepAliveClientMixin {
  // Typing indicator
  bool showTypingIndicator = false;
  RxBool shouldHighlight = false.obs;
  RxBool shouldPartialHighlight = false.obs;
  RxBool hoverHighlight = false.obs;

  Offset? longPressPosition;

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
    MessageManager().stream.listen((NewMessageEvent event) async {
      // Make sure we have the required data to qualify for this tile
      if (event.chatGuid != widget.chat.guid) return;
      if (!event.event.containsKey("message")) return;
      // Make sure the message is a group event
      Message message = event.event["message"];
      if (!message.isGroupEvent()) return;

      // If it's a group event, let's fetch the new information and save it
      try {
        await ChatManager().fetchChat(widget.chat.guid);
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

  void onTapUp() {
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

  Widget buildSlider(Widget child) {
    if (kIsWeb || kIsDesktop) {
      return MouseRegion(
        onEnter: (event) => hoverHighlight.value = true,
        onExit: (event) => hoverHighlight.value = false,
        cursor: SystemMouseCursors.click,
        child: child,
      );
    }
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
    return Obx(() {
      final hideInfo = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
      final generateNames =
          SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;
      TextStyle style = (SettingsManager().settings.skin.value == Skins.Material ? context.theme.textTheme.bodyMedium : context.theme.textTheme.bodyLarge)!.copyWith(
          fontWeight: SettingsManager().settings.skin.value == Skins.Material &&
              (widget.chat.hasUnreadMessage ?? false)
              ? FontWeight.bold
              : shouldHighlight.value
              ? FontWeight.w600
              : SettingsManager().settings.skin.value == Skins.iOS
              ? FontWeight.w500 : null,
          color: shouldHighlight.value
              ? SettingsManager().settings.skin.value == Skins.iOS
              ? context.theme.colorScheme.onBubble(context, widget.chat.isIMessage)
              : null
              : null)
          .apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1.1 : 1.0);
      widget.chat.getTitle();
      String title = widget.chat.title ?? "Fake Person";
      if (generateNames) {
        title = widget.chat.fakeNames.length == 1 ? widget.chat.fakeNames[0] : "Group Chat";
      } else if (hideInfo) {
        style = style.copyWith(color: Colors.transparent);
      }
      return RichText(
          text: TextSpan(
            children: MessageHelper.buildEmojiText(
              title,
              style,
            ),
          ),
          overflow: TextOverflow.ellipsis);
    });
  }

  Widget buildSubtitle() {
    return Obx(
      () {
        String latestText = widget.chat.latestMessageGetter != null
            ? MessageHelper.getNotificationText(widget.chat.latestMessageGetter!)
            : widget.chat.latestMessageText ?? "";
        final hideContent =
            SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideMessageContent.value;
        final generateContent = SettingsManager().settings.redactedMode.value &&
            SettingsManager().settings.generateFakeMessageContent.value;

        TextStyle style = context.theme.textTheme.bodySmall!.copyWith(
              fontWeight: SettingsManager().settings.skin.value == Skins.Material &&
                  (widget.chat.hasUnreadMessage ?? false)
                  ? FontWeight.w600
                  : null,
              color: SettingsManager().settings.skin.value == Skins.Material &&
                  (widget.chat.hasUnreadMessage ?? false)
                  ? context.textTheme.bodyMedium!.color : shouldHighlight.value
                  ? SettingsManager().settings.skin.value == Skins.iOS
                      ? context.theme.colorScheme.onBubble(context, widget.chat.isIMessage).withOpacity(0.85)
                      : null
                  : context.theme.colorScheme.outline,
              height: 1.5
            ).apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1.05 : 1.0);

        if (generateContent) {
          latestText = widget.chat.fakeLatestMessageText ?? "";
        } else if (hideContent) {
          style = style.copyWith(color: Colors.transparent);
        }

        return RichText(
          text: TextSpan(
              children: MessageHelper.buildEmojiText(
            latestText,
            style,
          )),
          overflow: TextOverflow.ellipsis,
          maxLines: SettingsManager().settings.skin.value == Skins.Material ? 3 : 2,
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
          double height = Theme.of(context).textTheme.labelLarge!.fontSize! * 1.25;
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
                        onTap: onTapUp,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: context.theme.colorScheme.primary,
                        ),
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Icon(
                            Icons.check,
                            color: context.theme.colorScheme.onPrimary,
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
    return Obx(() => !SettingsManager().settings.statusIndicatorsOnChats.value || kIsWeb || markers == null
        ? Text(buildDate(widget.chat.latestMessageDate ?? widget.chat.latestMessageGetter?.dateCreated),
            textAlign: TextAlign.right,
            style: context.theme.textTheme.bodySmall!.copyWith(
                  color: SettingsManager().settings.skin.value == Skins.Material &&
                      (widget.chat.hasUnreadMessage ?? false)
                      ? Theme.of(context).textTheme.bodyMedium!.color : shouldHighlight.value
                      ? SettingsManager().settings.skin.value == Skins.iOS
                          ? context.theme.colorScheme.outline
                          : null
                      : context.theme.colorScheme.outline,
                  fontWeight: SettingsManager().settings.skin.value == Skins.Material &&
                      (widget.chat.hasUnreadMessage ?? false)
                      ? FontWeight.w600
                      : shouldHighlight.value ? FontWeight.w500 : null,
                ).apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1 : 1.1),
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
                  style: context.theme.textTheme.bodySmall!.copyWith(
                        color: (message?.error ?? 0) > 0
                            ? Colors.red
                            : SettingsManager().settings.skin.value == Skins.Material &&
                            (widget.chat.hasUnreadMessage ?? false)
                            ? Theme.of(context).textTheme.bodyMedium!.color : shouldHighlight.value
                                ? SettingsManager().settings.skin.value == Skins.iOS
                                    ? context.theme.colorScheme.outline
                                    : null
                                : context.theme.colorScheme.outline,
                        fontWeight: SettingsManager().settings.skin.value == Skins.Material &&
                            (widget.chat.hasUnreadMessage ?? false)
                            ? FontWeight.w600
                            : shouldHighlight.value ? FontWeight.w500 : null,
                      ).apply(fontSizeFactor: SettingsManager().settings.skin.value == Skins.Material ? 1 : 1.1),
                  overflow: TextOverflow.clip);
            }),
          ));
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
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: parent.shouldPartialHighlight.value
                  ? context.theme.colorScheme.properSurface.lightenOrDarken(10)
                  : parent.shouldHighlight.value
                      ? context.theme.colorScheme.bubble(context, parent.widget.chat.isIMessage)
                      : parent.hoverHighlight.value
                          ? context.theme.colorScheme.properSurface
                          : null,
              borderRadius: BorderRadius.circular(
                  parent.shouldHighlight.value || parent.shouldPartialHighlight.value || parent.hoverHighlight.value
                      ? 8
                      : 0),
            ),
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
                  parent.onTapUp();
                },
                onLongPress: () async {
                  if (kIsDesktop || kIsWeb) return;
                  await peekChat(context, parent.widget.chat, parent.longPressPosition ?? Offset.zero);
                },
                child: Listener(
                  onPointerDown: (event) {
                    parent.longPressPosition = event.position;
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
                                        color: context.theme.colorScheme.background.lightenOrDarken(15),
                                        width: 0.5,
                                      ),
                                    )
                                  : null,
                            ),
                            child: ListTile(
                              mouseCursor: MouseCursor.defer,
                              enableFeedback: true,
                              dense: SettingsManager().settings.denseChatTiles.value,
                              contentPadding: EdgeInsets.only(left: 0),
                              minVerticalPadding: 10,
                              title: parent.buildTitle(),
                              subtitle: parent.widget.subtitle ?? parent.buildSubtitle(),
                              leading: parent.buildLeading(),
                              trailing: Container(
                                padding: EdgeInsets.only(right: 8, top: 10),
                                height: double.infinity,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      padding: EdgeInsets.only(right: 7),
                                      child: parent._buildDate(),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          SettingsManager().settings.skin.value == Skins.iOS
                                              ? CupertinoIcons.forward
                                              : Icons.arrow_forward,
                                          color: parent.shouldHighlight.value
                                              ? context.theme.colorScheme.onBubble(context, parent.widget.chat.isIMessage)
                                              : context.theme.colorScheme.outline,
                                          size: 15,
                                        ),
                                        parent.widget.chat.muteType == "mute"
                                            ? Padding(
                                              padding: const EdgeInsets.only(top: 5.0),
                                              child: Icon(
                                                CupertinoIcons.bell_slash_fill,
                                                color: parent.shouldHighlight.value
                                                    ? context.theme.colorScheme.onBubble(context, parent.widget.chat.isIMessage)
                                                    : context.theme.colorScheme.outline,
                                                size: 12,
                                              )
                                            )
                                            : Container()
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 5.0),
                        child: (parent.widget.chat.muteType != "mute" && parent.widget.chat.hasUnreadMessage!)
                            ? Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(35),
                                  color: context.theme.colorScheme.primary,
                                ),
                                width: 10,
                                height: 10,
                              )
                            : Container(),
                      ),
                    ],
                  ),
                ),
              ),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) => parent.hoverHighlight.value = true,
      onExit: (event) => parent.hoverHighlight.value = false,
      child: Obx(
        () {
          bool shouldPartialHighlight = parent.shouldPartialHighlight.value;
          bool shouldHighlight = parent.shouldHighlight.value;
          bool hoverHighlight = parent.hoverHighlight.value;
          return Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.only(left: 10),
              child: AnimatedContainer(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                  color: parent.selected
                      ? context.theme.colorScheme.primaryContainer.withOpacity(0.5)
                      : shouldPartialHighlight
                          ? context.theme.colorScheme.properSurface
                          : shouldHighlight
                              ? context.theme.colorScheme.primaryContainer
                              : hoverHighlight
                                  ? context.theme.colorScheme.properSurface
                                  : null,
                ),
                duration: Duration(milliseconds: 100),
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
                    mouseCursor: MouseCursor.defer,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
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
                                    color: context.theme.colorScheme.background.lightenOrDarken(15),
                                    width: 0.5,
                                  ),
                                )
                              : null,
                        ),
                        child: ListTile(
                          mouseCursor: MouseCursor.defer,
                          dense: SettingsManager().settings.denseChatTiles.value,
                          title: parent.buildTitle(),
                          subtitle: parent.widget.subtitle ?? parent.buildSubtitle(),
                          minVerticalPadding: 10,
                          contentPadding: EdgeInsets.only(left: 6, right: 16),
                          leading: parent.buildLeading(),
                          trailing: Container(
                            padding: EdgeInsets.only(right: 3),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.only(right: 2, left: 2),
                                        child: parent._buildDate(),
                                      ),
                                      if (parent.widget.chat.muteType != "mute" && parent.widget.chat.hasUnreadMessage!)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8.0),
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(20),
                                              color: context.theme.colorScheme.primary
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 5),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (parent.widget.chat.isPinned!)
                                        Icon(Icons.push_pin_outlined,
                                            size: 15, color: context.theme.colorScheme.outline),
                                      SizedBox(width: 5),
                                      if (parent.widget.chat.muteType == "mute")
                                        Icon(
                                          Icons.notifications_off_outlined,
                                          color: parent.widget.chat.hasUnreadMessage!
                                              ? context.theme.colorScheme.primary
                                              : context.theme.colorScheme.outline,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) => parent.hoverHighlight.value = true,
        onExit: (event) => parent.hoverHighlight.value = false,
      child: Obx(
        () {
          bool shouldPartialHighlight = parent.shouldPartialHighlight.value;
          bool shouldHighlight = parent.shouldHighlight.value;
          bool hoverHighlight = parent.hoverHighlight.value;
          return Material(
            color: Colors.transparent,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 100),
              decoration: BoxDecoration(
                color: parent.selected
                    ? context.theme.primaryColor.withAlpha(120)
                    : shouldPartialHighlight
                    ? context.theme.primaryColor.withAlpha(100)
                    : shouldHighlight
                    ? context.theme.backgroundColor.lightenOrDarken(10)
                    : hoverHighlight
                    ? context.theme.backgroundColor.withAlpha(100)
                    : null),
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
                  mouseCursor: MouseCursor.defer,
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
                                  color: context.theme.colorScheme.background.lightenOrDarken(15),
                                  width: 0.5,
                                ),
                              )
                            : null,
                      ),
                      child: ListTile(
                        mouseCursor: MouseCursor.defer,
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
                                      ? context.theme.colorScheme.primary
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
                                    color: context.theme.colorScheme.onBackground,
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
            ),
          );
        },
      ),
    );
  }
}
