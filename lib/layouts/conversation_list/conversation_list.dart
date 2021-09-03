import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_list/cupertino_conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ConversationList extends StatefulWidget {
  ConversationList({Key? key, required this.showArchivedChats, required this.showUnknownSenders}) : super(key: key);

  final bool showArchivedChats;
  final bool showUnknownSenders;

  @override
  ConversationListState createState() => ConversationListState();
}

class ConversationListState extends State<ConversationList> {
  Color? currentHeaderColor;
  bool hasPinnedChats = false;

  // ignore: close_sinks
  StreamController<Color?> headerColorStream = StreamController<Color?>.broadcast();

  late ScrollController scrollController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (this.mounted) {
      theme = Colors.transparent;
    }

    SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((e) {
      Logger.error("Error caught while hiding keyboard: ${e.toString()}");
    });
  }

  @override
  void dispose() {
    super.dispose();

    // Remove the scroll listener from the state
    scrollController.removeListener(scrollListener);
  }

  @override
  void initState() {
    super.initState();
    if (!widget.showUnknownSenders) {
      ChatBloc().refreshChats();
    }
    scrollController = ScrollController()..addListener(scrollListener);

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh' && this.mounted) {
        setState(() {});
      }
    });
  }

  Color? get theme => currentHeaderColor;

  set theme(Color? color) {
    if (currentHeaderColor == color) return;
    currentHeaderColor = color;
    if (!headerColorStream.isClosed) headerColorStream.sink.add(currentHeaderColor);
  }

  void scrollListener() {
    !_isAppBarExpanded ? theme = Colors.transparent : theme = context.theme.accentColor.withOpacity(0.5);
  }

  bool get _isAppBarExpanded {
    return scrollController.hasClients && scrollController.offset > (125 - kToolbarHeight);
  }

  List<Widget> getHeaderTextWidgets({double? size}) {
    TextStyle? style = context.textTheme.headline1;
    if (size != null) style = style!.copyWith(fontSize: size);

    return [Text(widget.showArchivedChats ? "Archive" : widget.showUnknownSenders ? "Unknown Senders" : "Messages", style: style), Container(width: 10)];
  }

  Widget getSyncIndicatorWidget() {
    return Obx(() {
      if (!SettingsManager().settings.showSyncIndicator.value) return SizedBox.shrink();
      if (!SetupBloc().isSyncing.value) return Container();
      return buildProgressIndicator(context, size: 10);
    });
  }

  void openNewChatCreator({List<File>? existing}) async {
    bool shouldShowSnackbar = (await SettingsManager().getMacOSVersion())! >= 11;
    CustomNavigator.pushAndRemoveUntil(
      context,
      ConversationView(
        isCreator: true,
        showSnackbar: shouldShowSnackbar,
        existingAttachments: existing ?? [],
      ),
      (route) => route.isFirst,
    );
  }

  void sortChats() {
    ChatBloc().chats.sort((a, b) {
      if (a.pinIndex.value != null && b.pinIndex.value != null) return a.pinIndex.value!.compareTo(b.pinIndex.value!);
      if (b.pinIndex.value != null) return 1;
      if (a.pinIndex.value != null) return -1;
      if (!a.isPinned! && b.isPinned!) return 1;
      if (a.isPinned! && !b.isPinned!) return -1;
      if (a.latestMessageDate == null && b.latestMessageDate == null) return 0;
      if (a.latestMessageDate == null) return 1;
      if (b.latestMessageDate == null) return -1;
      return -a.latestMessageDate!.compareTo(b.latestMessageDate!);
    });
  }

  Widget buildSettingsButton() => !widget.showArchivedChats && !widget.showUnknownSenders
      ? PopupMenuButton(
          color: context.theme.accentColor,
          onSelected: (dynamic value) {
            if (value == 0) {
              ChatBloc().markAllAsRead();
            } else if (value == 1) {
              CustomNavigator.pushLeft(
                context,
                ConversationList(
                  showArchivedChats: true,
                  showUnknownSenders: false,
                )
              );
            } else if (value == 2) {
              Navigator.of(context).push(
                ThemeSwitcher.buildPageRoute(
                  builder: (BuildContext context) {
                    return SettingsPanel();
                  },
                ),
              );
            } else if (value == 3) {
              CustomNavigator.pushLeft(
                context,
                ConversationList(
                  showArchivedChats: false,
                  showUnknownSenders: true,
                )
              );
            }
          },
          itemBuilder: (context) {
            return <PopupMenuItem>[
              PopupMenuItem(
                value: 0,
                child: Text(
                  'Mark all as read',
                  style: context.textTheme.bodyText1,
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Text(
                  'Archived',
                  style: context.textTheme.bodyText1,
                ),
              ),
              if (SettingsManager().settings.filterUnknownSenders.value)
                PopupMenuItem(
                  value: 3,
                  child: Text(
                    'Unknown Senders',
                    style: context.textTheme.bodyText1,
                  ),
                ),
              PopupMenuItem(
                value: 2,
                child: Text(
                  'Settings',
                  style: context.textTheme.bodyText1,
                ),
              ),
            ];
          },
          child: ThemeSwitcher(
            iOSSkin: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: context.theme.accentColor,
              ),
              child: Icon(
                Icons.more_horiz,
                color: context.theme.primaryColor,
                size: 15,
              ),
            ),
            materialSkin: Icon(
              Icons.more_vert,
              color: context.textTheme.bodyText1!.color,
              size: 25,
            ),
            samsungSkin: Icon(
              Icons.more_vert,
              color: context.textTheme.bodyText1!.color,
              size: 25,
            ),
          ),
        )
      : Container();

  Column buildFloatingActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (SettingsManager().settings.cameraFAB.value)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 45,
              maxHeight: 45,
            ),
            child: FloatingActionButton(
              child: Icon(
                  SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.camera : Icons.photo_camera,
                size: 20,
              ),
              onPressed: () async {
                String appDocPath = SettingsManager().appDocDir.path;
                String ext = ".png";
                File file = new File("$appDocPath/attachments/" + randomString(16) + ext);
                await file.create(recursive: true);

                // Take the picture after opening the camera
                await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": "camera"});

                // If we don't get data back, return outta here
                if (!file.existsSync()) return;
                if (file.statSync().size == 0) {
                  file.deleteSync();
                  return;
                }

                openNewChatCreator(existing: [file]);
              },
              heroTag: null,
            ),
          ),
        if (SettingsManager().settings.cameraFAB.value)
          SizedBox(
            height: 10,
          ),
        FloatingActionButton(
            backgroundColor: context.theme.primaryColor,
            child: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.pencil : Icons.message, color: Colors.white, size: 25),
            onPressed: openNewChatCreator),
      ],
    );
  }

  List<Widget> getConnectionIndicatorWidgets() {
    if (!SettingsManager().settings.showConnectionIndicator.value) return [];

    return [Obx(() => getIndicatorIcon(SocketManager().state.value, size: 12)), Container(width: 10.0)];
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      iOSSkin: CupertinoConversationList(parent: this),
      materialSkin: _Material(parent: this),
      samsungSkin: _Samsung(parent: this),
    );
  }
}

class _Material extends StatefulWidget {
  _Material({Key? key, required this.parent}) : super(key: key);

  final ConversationListState parent;

  @override
  __MaterialState createState() => __MaterialState();
}

class __MaterialState extends State<_Material> {
  List<Chat> selected = [];

  bool hasPinnedChat() {
    for (var i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders).length; i++) {
      if (ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders)[i].isPinned!) {
        widget.parent.hasPinnedChats = true;
        return true;
      } else {
        return false;
      }
    }
    return false;
  }

  bool hasNormalChats() {
    int counter = 0;
    for (var i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders).length; i++) {
      if (ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders)[i].isPinned!) {
        counter++;
      } else {}
    }
    if (counter == ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders).length) {
      return false;
    } else {
      return true;
    }
  }

  Widget slideLeftBackground(Chat chat) {
    return Container(
      color: SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
              ? Colors.purple
              : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                  ? Colors.red
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? Icons.notifications_active : Icons.notifications_off)
                      : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? ' Show Alerts' : ' Hide Alerts')
                      : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                          ? " Delete"
                          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        alignment: Alignment.centerRight,
      ),
    );
  }

  Widget slideRightBackground(Chat chat) {
    return Container(
      color: SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
              ? Colors.purple
              : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                  ? Colors.red
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 20,
            ),
            Icon(
              SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? Icons.notifications_active : Icons.notifications_off)
                      : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? ' Show Alerts' : ' Hide Alerts')
                      : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                          ? " Delete"
                          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    hasPinnedChat();
    bool showArchived = widget.parent.widget.showArchivedChats;
    bool showUnknown = widget.parent.widget.showUnknownSenders;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.theme.backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Obx(
        () => WillPopScope(
          onWillPop: () async {
            if (selected.isNotEmpty) {
              selected = [];
              setState(() {});
              return false;
            }
            return true;
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 500),
                child: selected.isEmpty
                    ? AppBar(
                        iconTheme: IconThemeData(color: context.theme.primaryColor),
                        brightness: ThemeData.estimateBrightnessForColor(context.theme.backgroundColor),
                        bottom: PreferredSize(
                          child: Container(
                            color: context.theme.dividerColor,
                            height: 0,
                          ),
                          preferredSize: Size.fromHeight(0.5),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ...widget.parent.getHeaderTextWidgets(size: 20),
                            ...widget.parent.getConnectionIndicatorWidgets(),
                            widget.parent.getSyncIndicatorWidget(),
                          ],
                        ),
                        actions: [
                          (!showArchived && !showUnknown)
                              ? GestureDetector(
                                  onTap: () async {
                                    CustomNavigator.pushLeft(
                                      context,
                                      SearchView(),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.search,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container(),
                          (SettingsManager().settings.moveChatCreatorToHeader.value && !showArchived && !showUnknown)
                              ? GestureDetector(
                                  onTap: () {
                                    CustomNavigator.pushAndRemoveUntil(
                                      context,
                                      ConversationView(
                                        isCreator: true,
                                      ),
                                      (route) => route.isFirst,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.create,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container(),
                          (SettingsManager().settings.moveChatCreatorToHeader.value
                              && SettingsManager().settings.cameraFAB.value
                              && !showArchived && !showUnknown)
                              ? GestureDetector(
                                onTap: () async {
                                  String appDocPath = SettingsManager().appDocDir.path;
                                  String ext = ".png";
                                  File file = new File("$appDocPath/attachments/" + randomString(16) + ext);
                                  await file.create(recursive: true);

                                  // Take the picture after opening the camera
                                  await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": "camera"});

                                  // If we don't get data back, return outta here
                                  if (!file.existsSync()) return;
                                  if (file.statSync().size == 0) {
                                    file.deleteSync();
                                    return;
                                  }

                                  widget.parent.openNewChatCreator(existing: [file]);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.photo_camera,
                                    color: context.textTheme.bodyText1!.color,
                                  ),
                                ),
                              )
                              : Container(),
                          Padding(
                            padding: EdgeInsets.only(right: 20),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 15.5),
                              child: Container(
                                width: 40,
                                child: widget.parent.buildSettingsButton(),
                              ),
                            ),
                          ),
                        ],
                        backgroundColor: context.theme.backgroundColor,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (([0, selected.length])
                                    .contains(selected.where((element) => element.hasUnreadMessage!).length))
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) async {
                                        await element.toggleHasUnread(!element.hasUnreadMessage!);
                                      });
                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        selected[0].hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                                if (([0, selected.length])
                                    .contains(selected.where((element) => element.muteType == "mute").length))
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) async {
                                        await element.toggleMute(element.muteType != "mute");
                                      });
                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        selected[0].muteType == "mute"
                                            ? Icons.notifications_active
                                            : Icons.notifications_off,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                                if (([0, selected.length])
                                    .contains(selected.where((element) => element.isPinned!).length))
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) {
                                        element.togglePin(!element.isPinned!);
                                      });
                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        selected[0].isPinned! ? Icons.star_outline : Icons.star,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: () {
                                    selected.forEach((element) {
                                      if (element.isArchived!) {
                                        ChatBloc().unArchiveChat(element);
                                      } else {
                                        ChatBloc().archiveChat(element);
                                      }
                                    });
                                    selected = [];
                                    if (this.mounted) setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      showArchived ? Icons.unarchive : Icons.archive,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                ),
                                if (selected[0].isArchived!)
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) {
                                        ChatBloc().deleteChat(element);
                                        Chat.deleteChat(element);
                                      });
                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.delete_forever,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            backgroundColor: context.theme.backgroundColor,
            body: Obx(
              () {
                if (!ChatBloc().hasChats.value) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Loading chats...",
                              style: Theme.of(context).textTheme.subtitle1,
                            ),
                          ),
                          buildProgressIndicator(context, size: 15),
                        ],
                      ),
                    ),
                  );
                }
                if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).isEmpty) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Text(
                        "You have no archived chats :(",
                        style: context.textTheme.subtitle1,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  physics: ThemeSwitcher.getScrollPhysics(),
                  itemBuilder: (context, index) {
                    return Obx(() {
                      if (SettingsManager().settings.swipableConversationTiles.value) {
                        return Dismissible(
                            background:
                                Obx(() => slideRightBackground(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index])),
                            secondaryBackground:
                                Obx(() => slideLeftBackground(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index])),
                            // Each Dismissible must contain a Key. Keys allow Flutter to
                            // uniquely identify widgets.
                            key: UniqueKey(),
                            // Provide a function that tells the app
                            // what to do after an item has been swiped away.
                            onDismissed: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                if (SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin) {
                                  await ChatBloc()
                                      .chats
                                      .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                      .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                  EventDispatcher().emit("refresh", null);
                                  if (this.mounted) setState(() {});
                                } else if (SettingsManager().settings.materialLeftAction.value ==
                                    MaterialSwipeAction.alerts) {
                                  await ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                      ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                  if (this.mounted) setState(() {});
                                } else if (SettingsManager().settings.materialLeftAction.value ==
                                    MaterialSwipeAction.delete) {
                                  ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                  Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                } else if (SettingsManager().settings.materialLeftAction.value ==
                                    MaterialSwipeAction.mark_read) {
                                  ChatBloc().toggleChatUnread(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                      !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].hasUnreadMessage!);
                                } else {
                                  if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                    ChatBloc().unArchiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                  } else {
                                    ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                  }
                                }
                              } else {
                                if (SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin) {
                                  await ChatBloc()
                                      .chats
                                      .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                      .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                  EventDispatcher().emit("refresh", null);
                                  if (this.mounted) setState(() {});
                                } else if (SettingsManager().settings.materialRightAction.value ==
                                    MaterialSwipeAction.alerts) {
                                  await ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                      ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                  if (this.mounted) setState(() {});
                                } else if (SettingsManager().settings.materialRightAction.value ==
                                    MaterialSwipeAction.delete) {
                                  ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                  Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                } else if (SettingsManager().settings.materialRightAction.value ==
                                    MaterialSwipeAction.mark_read) {
                                  ChatBloc().toggleChatUnread(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                      !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].hasUnreadMessage!);
                                } else {
                                  if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                    ChatBloc().unArchiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                  } else {
                                    ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                  }
                                }
                              }
                            },
                            child: (!showArchived && ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                ? Container()
                                : (showArchived && !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                    ? Container()
                                    : ConversationTile(
                                        key: UniqueKey(),
                                        chat: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                        inSelectMode: selected.isNotEmpty,
                                        selected: selected,
                                        onSelect: (bool selected) {
                                          if (selected) {
                                            this.selected.add(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                            setState(() {});
                                          } else {
                                            this.selected.removeWhere((element) =>
                                                element.guid ==
                                                ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].guid);
                                            setState(() {});
                                          }
                                        },
                                      ));
                      } else {
                        return ConversationTile(
                          key: UniqueKey(),
                          chat: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                          inSelectMode: selected.isNotEmpty,
                          selected: selected,
                          onSelect: (bool selected) {
                            if (selected) {
                              this.selected.add(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                              setState(() {});
                            } else {
                              this.selected.removeWhere((element) =>
                                  element.guid == ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].guid);
                              setState(() {});
                            }
                          },
                        );
                      }
                    });
                  },
                  itemCount: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).length,
                );
              },
            ),
            floatingActionButton: selected.isEmpty && !SettingsManager().settings.moveChatCreatorToHeader.value
                ? widget.parent.buildFloatingActionButton()
                : null,
          ),
        ),
      ),
    );
  }
}

class _Samsung extends StatefulWidget {
  _Samsung({Key? key, required this.parent}) : super(key: key);

  final ConversationListState parent;

  @override
  _SamsungState createState() => _SamsungState();
}

class _SamsungState extends State<_Samsung> {
  List<Chat> selected = [];

  bool hasPinnedChat() {
    for (var i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders).length; i++) {
      if (ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders)[i].isPinned!) {
        widget.parent.hasPinnedChats = true;
        return true;
      } else {
        return false;
      }
    }
    return false;
  }

  bool hasNormalChats() {
    int counter = 0;
    for (var i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders).length; i++) {
      if (ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders)[i].isPinned!) {
        counter++;
      } else {}
    }
    if (counter == ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders).length) {
      return false;
    } else {
      return true;
    }
  }

  Widget slideLeftBackground(Chat chat) {
    return Container(
      color: SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
              ? Colors.purple
              : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                  ? Colors.red
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
                  ? (chat.muteType == "mute" ? Icons.star_outline : Icons.star)
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? Icons.notifications_active : Icons.notifications_off)
                      : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? ' Show Alerts' : ' Hide Alerts')
                      : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.delete
                          ? " Delete"
                          : SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        alignment: Alignment.centerRight,
      ),
    );
  }

  Widget slideRightBackground(Chat chat) {
    return Container(
      color: SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
          ? Colors.yellow[800]
          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
              ? Colors.purple
              : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                  ? Colors.red
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                      ? Colors.blue
                      : Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 20,
            ),
            Icon(
              SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? Icons.star_outline : Icons.star)
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? Icons.notifications_active : Icons.notifications_off)
                      : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                          ? Icons.delete_forever
                          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? Icons.mark_chat_read : Icons.mark_chat_unread)
                              : (chat.isArchived! ? Icons.unarchive : Icons.archive),
              color: Colors.white,
            ),
            Text(
              SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin
                  ? (chat.isPinned! ? " Unpin" : " Pin")
                  : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.alerts
                      ? (chat.muteType == "mute" ? ' Show Alerts' : ' Hide Alerts')
                      : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.delete
                          ? " Delete"
                          : SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.mark_read
                              ? (chat.hasUnreadMessage! ? ' Mark Read' : ' Mark Unread')
                              : (chat.isArchived! ? ' UnArchive' : ' Archive'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showArchived = widget.parent.widget.showArchivedChats;
    bool showUnknown = widget.parent.widget.showUnknownSenders;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.theme.backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Obx(
        () => WillPopScope(
          onWillPop: () async {
            if (selected.isNotEmpty) {
              selected = [];
              setState(() {});
              return false;
            }
            return true;
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 500),
                child: selected.isEmpty
                    ? AppBar(
                        shadowColor: Colors.transparent,
                        iconTheme: IconThemeData(color: context.theme.primaryColor),
                        brightness: ThemeData.estimateBrightnessForColor(context.theme.backgroundColor),
                        bottom: PreferredSize(
                          child: Container(
                            color: context.theme.dividerColor,
                            height: 0,
                          ),
                          preferredSize: Size.fromHeight(0.5),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            ...widget.parent.getHeaderTextWidgets(size: 20),
                            ...widget.parent.getConnectionIndicatorWidgets(),
                            widget.parent.getSyncIndicatorWidget(),
                          ],
                        ),
                        actions: [
                          (!showArchived && !showUnknown)
                              ? GestureDetector(
                                  onTap: () async {
                                    CustomNavigator.push(
                                      context,
                                      SearchView()
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.search,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container(),
                          (SettingsManager().settings.moveChatCreatorToHeader.value && !showArchived && !showUnknown
                              ? GestureDetector(
                                  onTap: () {
                                    CustomNavigator.pushAndRemoveUntil(
                                      context,
                                      ConversationView(
                                        isCreator: true,
                                      ),
                                      (route) => route.isFirst,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.create,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container()),
                          (SettingsManager().settings.moveChatCreatorToHeader.value
                              && SettingsManager().settings.cameraFAB.value
                              && !showArchived && !showUnknown
                              ? GestureDetector(
                                  onTap: () async {
                                    String appDocPath = SettingsManager().appDocDir.path;
                                    String ext = ".png";
                                    File file = new File("$appDocPath/attachments/" + randomString(16) + ext);
                                    await file.create(recursive: true);

                                    // Take the picture after opening the camera
                                    await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": "camera"});

                                    // If we don't get data back, return outta here
                                    if (!file.existsSync()) return;
                                    if (file.statSync().size == 0) {
                                      file.deleteSync();
                                      return;
                                    }

                                    widget.parent.openNewChatCreator(existing: [file]);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.photo_camera,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                )
                              : Container()),
                          Padding(
                            padding: EdgeInsets.only(right: 20),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 15.5),
                              child: Container(
                                width: 40,
                                child: widget.parent.buildSettingsButton(),
                              ),
                            ),
                          ),
                        ],
                        backgroundColor: context.theme.backgroundColor,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (selected.length <= 1)
                                  GestureDetector(
                                    onTap: () {
                                      selected.forEach((element) async {
                                        await element.toggleMute(element.muteType != "mute");
                                      });

                                      selected = [];
                                      if (this.mounted) setState(() {});
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Icon(
                                        Icons.notifications_off,
                                        color: context.textTheme.bodyText1!.color,
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onTap: () {
                                    selected.forEach((element) {
                                      if (element.isArchived!) {
                                        ChatBloc().unArchiveChat(element);
                                      } else {
                                        ChatBloc().archiveChat(element);
                                      }
                                    });
                                    selected = [];
                                    if (this.mounted) setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      showArchived ? Icons.unarchive : Icons.archive,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    selected.forEach((element) async {
                                      await element.togglePin(!element.isPinned!);
                                    });

                                    selected = [];
                                    if (this.mounted) setState(() {});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.star,
                                      color: context.textTheme.bodyText1!.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            backgroundColor: context.theme.backgroundColor,
            body: Obx(() {
              if (!ChatBloc().hasChats.value) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Loading chats...",
                            style: Theme.of(context).textTheme.subtitle1,
                          ),
                        ),
                        buildProgressIndicator(context, size: 15),
                      ],
                    ),
                  ),
                );
              }
              if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).isEmpty) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text(
                      "You have no archived chats :(",
                      style: context.textTheme.subtitle1,
                    ),
                  ),
                );
              }

              bool hasPinned = hasPinnedChat();
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (hasPinned)
                      Container(
                        height: 20.0,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.transparent,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                      ),
                    if (hasPinned)
                      Container(
                        padding: EdgeInsets.all(6.0),
                        decoration: new BoxDecoration(
                          color: context.theme.accentColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return Obx(() {
                              if (SettingsManager().settings.swipableConversationTiles.value) {
                                return Dismissible(
                                  background: Obx(
                                      () => slideRightBackground(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index])),
                                  secondaryBackground: Obx(
                                      () => slideLeftBackground(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index])),
                                  // Each Dismissible must contain a Key. Keys allow Flutter to
                                  // uniquely identify widgets.
                                  key: UniqueKey(),
                                  // Provide a function that tells the app
                                  // what to do after an item has been swiped away.
                                  onDismissed: (direction) async {
                                    if (direction == DismissDirection.endToStart) {
                                      if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.pin) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                            .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                        EventDispatcher().emit("refresh", null);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        await ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                            !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                          ChatBloc()
                                              .unArchiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        }
                                      }
                                    } else {
                                      if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.pin) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                            .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                        EventDispatcher().emit("refresh", null);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        await ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                            !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                          ChatBloc()
                                              .unArchiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        }
                                      }
                                    }
                                  },
                                  child: (!showArchived &&
                                          ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                      ? Container()
                                      : (showArchived &&
                                              !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                          ? Container()
                                          : ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!
                                              ? ConversationTile(
                                                  key: UniqueKey(),
                                                  chat: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                                  inSelectMode: selected.isNotEmpty,
                                                  selected: selected,
                                                  onSelect: (bool selected) {
                                                    if (selected) {
                                                      this
                                                          .selected
                                                          .add(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                                    } else {
                                                      this.selected.removeWhere((element) =>
                                                          element.guid ==
                                                          ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].guid);
                                                    }

                                                    if (this.mounted) setState(() {});
                                                  },
                                                )
                                              : Container(),
                                );
                              } else {
                                if (!showArchived && ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                  return Container();
                                if (showArchived && !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                  return Container();
                                if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!) {
                                  return ConversationTile(
                                    key: UniqueKey(),
                                    chat: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                    inSelectMode: selected.isNotEmpty,
                                    selected: selected,
                                    onSelect: (bool selected) {
                                      if (selected) {
                                        this.selected.add(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        if (this.mounted) setState(() {});
                                      } else {
                                        this.selected.removeWhere((element) =>
                                            element.guid == ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].guid);
                                        if (this.mounted) setState(() {});
                                      }
                                    },
                                  );
                                }
                                return Container();
                              }
                            });
                          },
                          itemCount: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).length,
                        ),
                      ),
                    if (hasNormalChats())
                      Container(
                        height: 20.0,
                        decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.transparent,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(20))),
                      ),
                    if (hasNormalChats())
                      Container(
                        padding: const EdgeInsets.all(6.0),
                        decoration: new BoxDecoration(
                            color: context.theme.accentColor,
                            borderRadius: new BorderRadius.only(
                              topLeft: const Radius.circular(20.0),
                              topRight: const Radius.circular(20.0),
                              bottomLeft: const Radius.circular(20.0),
                              bottomRight: const Radius.circular(20.0),
                            )),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            return Obx(() {
                              if (SettingsManager().settings.swipableConversationTiles.value) {
                                return Dismissible(
                                  background: Obx(
                                      () => slideRightBackground(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index])),
                                  secondaryBackground: Obx(
                                      () => slideLeftBackground(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index])),
                                  // Each Dismissible must contain a Key. Keys allow Flutter to
                                  // uniquely identify widgets.
                                  key: UniqueKey(),
                                  // Provide a function that tells the app
                                  // what to do after an item has been swiped away.
                                  onDismissed: (direction) async {
                                    if (direction == DismissDirection.endToStart) {
                                      if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.pin) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                            .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                        EventDispatcher().emit("refresh", null);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        await ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                            !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                          ChatBloc()
                                              .unArchiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        }
                                      }
                                    } else {
                                      if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.pin) {
                                        await ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                            .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                        EventDispatcher().emit("refresh", null);
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        await ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                        if (this.mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        Chat.deleteChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                            !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                          ChatBloc()
                                              .unArchiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                        }
                                      }
                                    }
                                  },
                                  child: (!showArchived &&
                                          ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                      ? Container()
                                      : (showArchived &&
                                              !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                          ? Container()
                                          : (!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!)
                                              ? ConversationTile(
                                                  key: UniqueKey(),
                                                  chat: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                                  inSelectMode: selected.isNotEmpty,
                                                  selected: selected,
                                                  onSelect: (bool selected) {
                                                    if (selected) {
                                                      this
                                                          .selected
                                                          .add(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                                    } else {
                                                      this.selected.removeWhere((element) =>
                                                          element.guid ==
                                                          ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].guid);
                                                    }

                                                    if (this.mounted) setState(() {});
                                                  },
                                                )
                                              : Container(),
                                );
                              } else {
                                if (!showArchived && ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                  return Container();
                                if (showArchived && !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!)
                                  return Container();
                                if (!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!) {
                                  return ConversationTile(
                                    key: UniqueKey(),
                                    chat: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                    inSelectMode: selected.isNotEmpty,
                                    selected: selected,
                                    onSelect: (bool selected) {
                                      if (selected) {
                                        this.selected.add(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                      } else {
                                        this.selected.removeWhere((element) =>
                                            element.guid == ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].guid);
                                      }

                                      if (this.mounted) setState(() {});
                                    },
                                  );
                                }
                                return Container();
                              }
                            });
                          },
                          itemCount: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).length,
                        ),
                      )
                  ],
                ),
              );
            }),
            floatingActionButton: selected.isEmpty && !SettingsManager().settings.moveChatCreatorToHeader.value
                ? widget.parent.buildFloatingActionButton()
                : null,
          ),
        ),
      ),
    );
  }
}
