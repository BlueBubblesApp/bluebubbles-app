import 'package:bluebubbles/repository/models/platform_file.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/widgets/vertical_split_view.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class SamsungConversationList extends StatefulWidget {
  SamsungConversationList({Key? key, required this.parent}) : super(key: key);

  final ConversationListState parent;

  @override
  _SamsungState createState() => _SamsungState();
}

class _SamsungState extends State<SamsungConversationList> {
  List<Chat> selected = [];
  bool openedChatAlready = false;

  bool hasPinnedChat() {
    for (int i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders).length; i++) {
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
    for (int i = 0; i < ChatBloc().chats.archivedHelper(widget.parent.widget.showArchivedChats).unknownSendersHelper(widget.parent.widget.showUnknownSenders).length; i++) {
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

  Future<void> openLastChat(BuildContext context) async {
    if (ChatBloc().chatRequest != null
        && prefs.getString('lastOpenedChat') != null
        && (!context.isPhone || context.isLandscape)
        && SettingsManager().settings.tabletMode.value
        && CurrentChat.activeChat?.chat.guid != prefs.getString('lastOpenedChat')) {
      await ChatBloc().chatRequest!.future;
      CustomNavigator.pushAndRemoveUntil(
        context,
        ConversationView(
            chat: ChatBloc().chats.firstWhere((e) => e.guid == prefs.getString('lastOpenedChat'))
        ),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!openedChatAlready) {
      Future.delayed(Duration.zero, () => openLastChat(context));
      openedChatAlready = true;
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.theme.backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
        context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Obx(() => buildForDevice()),
    );
  }

  Widget buildChatList() {
    bool showArchived = widget.parent.widget.showArchivedChats;
    bool showUnknown = widget.parent.widget.showUnknownSenders;
    return Obx(
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
                      bool camera = await Permission.camera.isGranted;
                      if (!camera) {
                        bool granted = (await Permission.camera.request()) == PermissionStatus.granted;
                        if (!granted) {
                          showSnackbar(
                              "Error",
                              "Camera was denied"
                          );
                          return;
                        }
                      }

                      String appDocPath = SettingsManager().appDocDir.path;
                      String ext = ".png";
                      File file = File("$appDocPath/attachments/" + randomString(16) + ext);
                      await file.create(recursive: true);

                      // Take the picture after opening the camera
                      await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": "camera"});

                      // If we don't get data back, return outta here
                      if (!file.existsSync()) return;
                      if (file.statSync().size == 0) {
                        file.deleteSync();
                        return;
                      }

                      widget.parent.openNewChatCreator(existing: [PlatformFile(
                        name: file.path.split("/").last,
                        path: file.path,
                        bytes: file.readAsBytesSync(),
                        size: file.lengthSync(),
                      )]);
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
                              for (Chat element in selected) {
                                element.toggleMute(element.muteType != "mute");
                              }

                              selected = [];
                              if (mounted) setState(() {});
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
                            for (Chat element in selected) {
                              if (element.isArchived!) {
                                ChatBloc().unArchiveChat(element);
                              } else {
                                ChatBloc().archiveChat(element);
                              }
                            }
                            selected = [];
                            if (mounted) setState(() {});
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
                            for (Chat element in selected) {
                              element.togglePin(!element.isPinned!);
                            }

                            selected = [];
                            if (mounted) setState(() {});
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
            if (!ChatBloc().loadedChatBatch.value) {
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
            if (ChatBloc().loadedChatBatch.value && ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).isEmpty) {
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
                      decoration: BoxDecoration(
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
                                background: (kIsDesktop || kIsWeb) ? Container() : Obx(
                                        () => slideRightBackground(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index])),
                                secondaryBackground: (kIsDesktop || kIsWeb) ? Container() : Obx(
                                        () => slideLeftBackground(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index])),
                                // Each Dismissible must contain a Key. Keys allow Flutter to
                                // uniquely identify widgets.
                                key: UniqueKey(),
                                // Provide a function that tells the app
                                // what to do after an item has been swiped away.
                                onDismissed: (direction) {
                                  if (direction == DismissDirection.endToStart) {
                                    if (SettingsManager().settings.materialLeftAction.value ==
                                        MaterialSwipeAction.pin) {
                                      ChatBloc()
                                          .chats
                                          .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                          .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                      EventDispatcher().emit("refresh", null);
                                      if (mounted) setState(() {});
                                    } else if (SettingsManager().settings.materialLeftAction.value ==
                                        MaterialSwipeAction.alerts) {
                                      ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                          ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                      if (mounted) setState(() {});
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
                                      ChatBloc()
                                          .chats
                                          .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                          .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                      EventDispatcher().emit("refresh", null);
                                      if (mounted) setState(() {});
                                    } else if (SettingsManager().settings.materialRightAction.value ==
                                        MaterialSwipeAction.alerts) {
                                      ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                          ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                      if (mounted) setState(() {});
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

                                    if (mounted) setState(() {});
                                  },
                                )
                                    : Container(),
                              );
                            } else {
                              if (!showArchived && ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                return Container();
                              }
                              if (showArchived && !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                return Container();
                              }
                              if (ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!) {
                                return ConversationTile(
                                  key: UniqueKey(),
                                  chat: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index],
                                  inSelectMode: selected.isNotEmpty,
                                  selected: selected,
                                  onSelect: (bool selected) {
                                    if (selected) {
                                      this.selected.add(ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]);
                                      if (mounted) setState(() {});
                                    } else {
                                      this.selected.removeWhere((element) =>
                                      element.guid == ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].guid);
                                      if (mounted) setState(() {});
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
                      decoration: BoxDecoration(
                          color: context.theme.accentColor,
                          borderRadius: BorderRadius.only(
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
                                onDismissed: (direction) {
                                  if (direction == DismissDirection.endToStart) {
                                    if (SettingsManager().settings.materialLeftAction.value ==
                                        MaterialSwipeAction.pin) {
                                      ChatBloc()
                                          .chats
                                          .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                          .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                      EventDispatcher().emit("refresh", null);
                                      if (mounted) setState(() {});
                                    } else if (SettingsManager().settings.materialLeftAction.value ==
                                        MaterialSwipeAction.alerts) {
                                      ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                          ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                      if (mounted) setState(() {});
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
                                      ChatBloc()
                                          .chats
                                          .archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index]
                                          .togglePin(!ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isPinned!);
                                      EventDispatcher().emit("refresh", null);
                                      if (mounted) setState(() {});
                                    } else if (SettingsManager().settings.materialRightAction.value ==
                                        MaterialSwipeAction.alerts) {
                                      ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].toggleMute(
                                          ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].muteType != "mute");
                                      if (mounted) setState(() {});
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

                                    if (mounted) setState(() {});
                                  },
                                )
                                    : Container(),
                              );
                            } else {
                              if (!showArchived && ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                return Container();
                              }
                              if (showArchived && !ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown)[index].isArchived!) {
                                return Container();
                              }
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

                                    if (mounted) setState(() {});
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
    );
  }

  Widget buildForLandscape(BuildContext context, Widget chatList) {
    return VerticalSplitView(
      dividerWidth: 10.0,
      initialRatio: 0.4,
      minRatio: 0.33,
      maxRatio: 0.5,
      allowResize: true,
      left: LayoutBuilder(
          builder: (context, constraints) {
            CustomNavigator.maxWidthLeft = constraints.maxWidth;
            return WillPopScope(
              onWillPop: () async {
                Get.back(id: 1);
                return false;
              },
              child: Navigator(
                key: Get.nestedKey(1),
                onPopPage: (route, _) {
                  return false;
                },
                pages: [CupertinoPage(name: "initial", child: chatList)],
              ),
            );
          }
      ),
      right: LayoutBuilder(
          builder: (context, constraints) {
            CustomNavigator.maxWidthRight = constraints.maxWidth;
            return WillPopScope(
              onWillPop: () async {
                Get.back(id: 2);
                return false;
              },
              child: Navigator(
                key: Get.nestedKey(2),
                onPopPage: (route, _) {
                  return false;
                },
                pages: [CupertinoPage(name: "initial", child: Scaffold(
                  backgroundColor: context.theme.backgroundColor,
                  extendBodyBehindAppBar: true,
                  body: Center(
                    child: Container(
                        child: Text("Select a chat from the list", style: Theme.of(Get.context!).textTheme.subtitle1!.copyWith(fontSize: 18))
                    ),
                  ),
                ))],
              ),
            );
          }
      ),
    );
  }

  Widget buildForDevice() {
    bool showAltLayout = SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape);
    Widget chatList = buildChatList();
    if (showAltLayout && !widget.parent.widget.showUnknownSenders && !widget.parent.widget.showArchivedChats) {
      return buildForLandscape(context, chatList);
    }

    return chatList;
  }
}