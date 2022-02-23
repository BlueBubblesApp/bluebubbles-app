import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/vertical_split_view.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

class SamsungConversationList extends StatefulWidget {
  SamsungConversationList({Key? key, required this.parent}) : super(key: key);

  final ConversationListState parent;

  @override
  _SamsungConversationListState createState() => _SamsungConversationListState();
}

class _SamsungConversationListState extends State<SamsungConversationList> {
  List<Chat> selected = [];
  bool openedChatAlready = false;
  final ScrollController scrollController = ScrollController();

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

  Future<void> openLastChat(BuildContext context) async {
    if (ChatBloc().chatRequest != null
        && prefs.getString('lastOpenedChat') != null
        && (!context.isPhone || context.isLandscape)
        && SettingsManager().settings.tabletMode.value
        && ChatManager().activeChat?.chat.guid != prefs.getString('lastOpenedChat')) {
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
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
        context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Obx(() => buildForDevice()),
    );
  }

  Widget _extendedTitle(Animation<double> animation) {
    return FadeTransition(
      opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: animation,
        curve: Interval(0.3, 1.0, curve: Curves.easeIn),
      )),
      child: Center(child: Obx(() {
        int unreads = ChatBloc().unreads.value;
        return Text(selected.isNotEmpty ? "${selected.length} selected" : unreads > 0 ? "$unreads unread message${unreads > 1 ? "s" : ""}" :  "Messages", textScaleFactor: 2.5);
      })),
    );
  }

  Widget _collapsedTitle(Animation<double> animation) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: animation,
        curve: Interval(0.0, 0.7, curve: Curves.easeOut),
      )),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          padding: EdgeInsets.only(left: 16),
          height: 50,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                widget.parent.getHeaderTextWidget(size: 20),
                widget.parent.getConnectionIndicatorWidget(),
                widget.parent.getSyncIndicatorWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    bool showArchived = widget.parent.widget.showArchivedChats;
    bool showUnknown = widget.parent.widget.showUnknownSenders;
    return Align(
      alignment: Alignment.bottomRight,
      child: Container(
        padding: EdgeInsets.only(right: 0),
        height: 50,
        child: Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
                  EventDispatcher().emit("update-highlight", null);
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
                  : Container(),
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Container(
                  width: 40,
                  child: widget.parent.buildSettingsButton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateExpandRatio(BoxConstraints constraints, BuildContext context) {
    var expandRatio = (constraints.maxHeight - 50)
        / (context.height / 3 - 50);

    if (expandRatio > 1.0) expandRatio = 1.0;
    if (expandRatio < 0.0) expandRatio = 0.0;

    return expandRatio;
  }

  Widget buildChatList() {
    bool showArchived = widget.parent.widget.showArchivedChats;
    bool showUnknown = widget.parent.widget.showUnknownSenders;
    return WillPopScope(
        onWillPop: () async {
          if (selected.isNotEmpty) {
            selected = [];
            setState(() {});
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() || isEqual(Theme.of(context), whiteLightTheme) ? context.theme.colorScheme.secondary : context.theme.backgroundColor,
          body: SafeArea(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  final scrollDistance = context.height / 3 - 57;

                  if (scrollController.offset > 0 && scrollController.offset < scrollDistance) {
                    final double snapOffset =
                    scrollController.offset / scrollDistance > 0.5 ? scrollDistance : 0;

                    Future.microtask(() => scrollController.animateTo(snapOffset,
                        duration: Duration(milliseconds: 200), curve: Curves.linear));
                  }
                  return false;
                },
                child: CustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() || isEqual(Theme.of(context), whiteLightTheme) ? context.theme.colorScheme.secondary : context.theme.backgroundColor,
                      pinned: true,
                      stretch: true,
                      expandedHeight: context.height / 3,
                      elevation: 0,
                      flexibleSpace: LayoutBuilder(
                        builder: (context, constraints) {
                          final expandRatio = _calculateExpandRatio(constraints, context);
                          final animation = AlwaysStoppedAnimation(expandRatio);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              _extendedTitle(animation),
                              _collapsedTitle(animation),
                              _actions(),
                            ],
                          );
                        },
                      ),
                    ),
                    if (hasPinnedChat())
                      SliverList(
                          delegate: SliverChildListDelegate([
                            SingleChildScrollView(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Obx(() {
                                  Color headerColor;
                                  Color tileColor;
                                  if ((Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
                                      SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
                                    headerColor = Theme.of(context).colorScheme.secondary;
                                    tileColor = Theme.of(context).backgroundColor;
                                  } else {
                                    headerColor = Theme.of(context).backgroundColor;
                                    tileColor = Theme.of(context).colorScheme.secondary;
                                  }
                                  if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
                                    tileColor = headerColor;
                                  }
                                    return Container(
                                      color: tileColor,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, index) {
                                          final chat = ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).bigPinHelper(true)[index];
                                          return buildChatItem(chat);
                                        },
                                        itemCount: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).bigPinHelper(true).length,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          ])),
                    if (hasPinnedChat())
                      SliverToBoxAdapter(child: SizedBox(height: 15)),
                    SliverList(
                        delegate: SliverChildListDelegate([
                          SingleChildScrollView(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Obx(
                                    () {
                                  Color headerColor;
                                  Color tileColor;
                                  if ((Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
                                      SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
                                    headerColor = Theme.of(context).colorScheme.secondary;
                                    tileColor = Theme.of(context).backgroundColor;
                                  } else {
                                    headerColor = Theme.of(context).backgroundColor;
                                    tileColor = Theme.of(context).colorScheme.secondary;
                                  }
                                  if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme)) {
                                    tileColor = headerColor;
                                  }
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
                                  return Container(
                                    color: tileColor,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemBuilder: (context, index) {
                                        final chat = ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).bigPinHelper(false)[index];
                                        return buildChatItem(chat);
                                      },
                                      itemCount: ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).bigPinHelper(false).length,
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                        ])),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: AnimatedSize(
            duration: Duration(milliseconds: 200),
            child: selected.isEmpty ? null : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (([0, selected.length])
                    .contains(selected.where((element) => element.hasUnreadMessage!).length))
                  GestureDetector(
                    onTap: () {
                      for (Chat element in selected) {
                        element.toggleHasUnread(!element.hasUnreadMessage!);
                      }

                      selected = [];
                      if (mounted) setState(() {});
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
                      for (Chat element in selected) {
                        element.toggleMute(element.muteType != "mute");
                      }

                      selected = [];
                      if (mounted) setState(() {});
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
                      for (Chat element in selected) {
                        element.togglePin(!element.isPinned!);
                      }

                      selected = [];
                      if (mounted) setState(() {});
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
                if (selected[0].isArchived!)
                  GestureDetector(
                    onTap: () {
                      for (Chat element in selected) {
                        ChatBloc().deleteChat(element);
                        Chat.deleteChat(element);
                      }

                      selected = [];
                      if (mounted) setState(() {});
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
          ),
          floatingActionButton: selected.isEmpty && !SettingsManager().settings.moveChatCreatorToHeader.value
              ? widget.parent.buildFloatingActionButton()
              : null,
        ),
      );
  }

  Widget buildForLandscape(BuildContext context, Widget chatList) {
    return VerticalSplitView(
      initialRatio: 0.4,
      minRatio: kIsDesktop || kIsWeb ? 0.2 : 0.33,
      maxRatio: 0.5,
      allowResize: true,
      left: LayoutBuilder(
          builder: (context, constraints) {
            CustomNavigator.maxWidthLeft = constraints.maxWidth;
            return WillPopScope(
              onWillPop: () async {
                Get.until((route) {
                  bool id2result = false;
                  // check if we should pop the left side first
                  Get.until((route) {
                    if (route.settings.name != "initial") {
                      Get.back(id: 2);
                      id2result = true;
                    }
                    return true;
                  }, id: 2);
                  if (!id2result) {
                    if (route.settings.name == "initial") {
                      SystemNavigator.pop();
                    } else {
                      Get.back(id: 1);
                    }
                  }
                  return true;
                }, id: 1);
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
    bool showAltLayout = SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape) && context.width > 600;
    Widget chatList = buildChatList();
    if (showAltLayout && !widget.parent.widget.showUnknownSenders && !widget.parent.widget.showArchivedChats) {
      return buildForLandscape(context, chatList);
    } else if (!widget.parent.widget.showArchivedChats && !widget.parent.widget.showUnknownSenders) {
      return TitleBarWrapper(child: chatList);
    }

    return chatList;
  }

  Widget buildChatItem(Chat chat) {
    bool showArchived = widget.parent.widget.showArchivedChats;
    return Obx(() {
      if (SettingsManager().settings.swipableConversationTiles.value) {
        return Dismissible(
            background:
            (kIsDesktop || kIsWeb) ? null : Obx(() => slideRightBackground(chat)),
            secondaryBackground:
            (kIsDesktop || kIsWeb) ? null : Obx(() => slideLeftBackground(chat)),
            // Each Dismissible must contain a Key. Keys allow Flutter to
            // uniquely identify widgets.
            key: UniqueKey(),
            // Provide a function that tells the app
            // what to do after an item has been swiped away.
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                if (SettingsManager().settings.materialLeftAction.value == MaterialSwipeAction.pin) {
                  chat.togglePin(!chat.isPinned!);
                  EventDispatcher().emit("refresh", null);
                  if (mounted) setState(() {});
                } else if (SettingsManager().settings.materialLeftAction.value ==
                    MaterialSwipeAction.alerts) {
                  chat.toggleMute(
                      chat.muteType != "mute");
                  if (mounted) setState(() {});
                } else if (SettingsManager().settings.materialLeftAction.value ==
                    MaterialSwipeAction.delete) {
                  ChatBloc().deleteChat(chat);
                  Chat.deleteChat(chat);
                } else if (SettingsManager().settings.materialLeftAction.value ==
                    MaterialSwipeAction.mark_read) {
                  ChatBloc().toggleChatUnread(chat,
                      !chat.hasUnreadMessage!);
                } else {
                  if (chat.isArchived!) {
                    ChatBloc().unArchiveChat(chat);
                  } else {
                    ChatBloc().archiveChat(chat);
                  }
                }
              } else {
                if (SettingsManager().settings.materialRightAction.value == MaterialSwipeAction.pin) {
                  chat.togglePin(!chat.isPinned!);
                  EventDispatcher().emit("refresh", null);
                  if (mounted) setState(() {});
                } else if (SettingsManager().settings.materialRightAction.value ==
                    MaterialSwipeAction.alerts) {
                  chat.toggleMute(
                      chat.muteType != "mute");
                  if (mounted) setState(() {});
                } else if (SettingsManager().settings.materialRightAction.value ==
                    MaterialSwipeAction.delete) {
                  ChatBloc().deleteChat(chat);
                  Chat.deleteChat(chat);
                } else if (SettingsManager().settings.materialRightAction.value ==
                    MaterialSwipeAction.mark_read) {
                  ChatBloc().toggleChatUnread(chat,
                      !chat.hasUnreadMessage!);
                } else {
                  if (chat.isArchived!) {
                    ChatBloc().unArchiveChat(chat);
                  } else {
                    ChatBloc().archiveChat(chat);
                  }
                }
              }
            },
            child: (!showArchived && chat.isArchived!)
                ? Container()
                : (showArchived && !chat.isArchived!)
                ? Container()
                : ConversationTile(
              key: UniqueKey(),
              chat: chat,
              inSelectMode: selected.isNotEmpty,
              selected: selected,
              onSelect: (bool selected) {
                if (selected) {
                  this.selected.add(chat);
                  setState(() {});
                } else {
                  this.selected.removeWhere((element) =>
                  element.guid ==
                      chat.guid);
                  setState(() {});
                }
              },
            ));
      } else {
        return ConversationTile(
          key: UniqueKey(),
          chat: chat,
          inSelectMode: selected.isNotEmpty,
          selected: selected,
          onSelect: (bool selected) {
            if (selected) {
              this.selected.add(chat);
              setState(() {});
            } else {
              this.selected.removeWhere((element) =>
              element.guid == chat.guid);
              setState(() {});
            }
          },
        );
      }
    });
  }
}