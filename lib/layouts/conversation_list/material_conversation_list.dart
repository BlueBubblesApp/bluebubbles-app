import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/layouts/widgets/vertical_split_view.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

class MaterialConversationList extends StatefulWidget {
  MaterialConversationList({Key? key, required this.parent}) : super(key: key);

  final ConversationListState parent;

  @override
  State<MaterialConversationList> createState() => _MaterialConversationListState();
}

class _MaterialConversationListState extends State<MaterialConversationList> {
  List<Chat> selected = [];
  bool openedChatAlready = false;
  double initialPosition = 0.0;

  bool hasPinnedChat() {
    for (int i = 0;
        i <
            ChatBloc()
                .chats
                .archivedHelper(widget.parent.widget.showArchivedChats)
                .unknownSendersHelper(widget.parent.widget.showUnknownSenders)
                .length;
        i++) {
      if (ChatBloc()
          .chats
          .archivedHelper(widget.parent.widget.showArchivedChats)
          .unknownSendersHelper(widget.parent.widget.showUnknownSenders)[i]
          .isPinned!) {
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
    for (int i = 0;
        i <
            ChatBloc()
                .chats
                .archivedHelper(widget.parent.widget.showArchivedChats)
                .unknownSendersHelper(widget.parent.widget.showUnknownSenders)
                .length;
        i++) {
      if (ChatBloc()
          .chats
          .archivedHelper(widget.parent.widget.showArchivedChats)
          .unknownSendersHelper(widget.parent.widget.showUnknownSenders)[i]
          .isPinned!) {
        counter++;
      } else {}
    }
    if (counter ==
        ChatBloc()
            .chats
            .archivedHelper(widget.parent.widget.showArchivedChats)
            .unknownSendersHelper(widget.parent.widget.showUnknownSenders)
            .length) {
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
    if (ChatBloc().chatRequest != null &&
        prefs.getString('lastOpenedChat') != null &&
        (!context.isPhone || context.isLandscape) &&
        (SettingsManager().settings.tabletMode.value || kIsDesktop) &&
        ChatManager().activeChat?.chat.guid != prefs.getString('lastOpenedChat') &&
        !LifeCycleManager().isBubble) {
      await ChatBloc().chatRequest!.future;
      CustomNavigator.pushAndRemoveUntil(
        context,
        ConversationView(
            chat: kIsWeb
                ? await Chat.findOneWeb(guid: prefs.getString('lastOpenedChat'))
                : Chat.findOne(guid: prefs.getString('lastOpenedChat'))),
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
    hasPinnedChat();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Obx(() => buildForDevice()),
    );
  }

  Widget buildChatList() {
    final Rx<Color> _backgroundColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled
        ? context.theme.colorScheme.background
        : Colors.transparent)
        .obs;

    if (kIsDesktop) {
      SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
        if (mounted) {
          _backgroundColor.value =
              effect != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background;
        }
      });
    }

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
        child: Container(
          color: _backgroundColor.value,
          padding: EdgeInsets.only(top: kIsDesktop ? 30 : 0),
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(60),
              child: Container(
                color: selected.isEmpty ? Colors.transparent : _backgroundColor.value,
                child: Stack(
                  children: [
                    Container(
                      height: selected.isEmpty ? 80 : 0,
                      width: context.width,
                      color: _backgroundColor.value
                    ),
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 500),
                      child: selected.isEmpty
                          ? SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    color: context.theme.colorScheme.properSurface,
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      if (!showArchived && !showUnknown) {
                                        CustomNavigator.pushLeft(
                                          context,
                                          SearchView(),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(25),
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 5.0, top: 5.0, bottom: 5.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                (!showArchived && !showUnknown)
                                                    ? IconButton(
                                                        onPressed: () async {
                                                          CustomNavigator.pushLeft(
                                                            context,
                                                            SearchView(),
                                                          );
                                                        },
                                                        icon: Icon(
                                                          Icons.search,
                                                          color: context.theme.colorScheme.properOnSurface,
                                                        ),
                                                      )
                                                    : IconButton(
                                                        onPressed: () async {
                                                          Navigator.of(context).pop();
                                                        },
                                                        padding: EdgeInsets.zero,
                                                        icon: Icon(
                                                          Icons.arrow_back,
                                                          color: context.theme.colorScheme.properOnSurface,
                                                        ),
                                                      ),
                                                SizedBox(width: 5),
                                                Stack(
                                                  alignment: Alignment.centerLeft,
                                                  children: [
                                                    widget.parent.getSyncIndicatorWidget(),
                                                    widget.parent.getConnectionIndicatorWidget(),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          widget.parent.getHeaderTextWidget(size: 23),
                                          Expanded(
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                (SettingsManager().settings.moveChatCreatorToHeader.value &&
                                                        !showArchived &&
                                                        !showUnknown)
                                                    ? GestureDetector(
                                                        onLongPress: SettingsManager().settings.cameraFAB.value ? () async {
                                                          bool camera = await Permission.camera.isGranted;
                                                          if (!camera) {
                                                            bool granted = (await Permission.camera.request()) ==
                                                          PermissionStatus.granted;
                                                          if (!granted) {
                                                          showSnackbar("Error", "Camera was denied");
                                                          return;
                                                          }
                                                          }

                                                          String appDocPath = SettingsManager().appDocDir.path;
                                                          String ext = ".png";
                                                          File file =
                                                          File("$appDocPath/attachments/${randomString(16)}$ext");
                                                          await file.create(recursive: true);

                                                          // Take the picture after opening the camera
                                                          await MethodChannelInterface().invokeMethod(
                                                          "open-camera", {"path": file.path, "type": "camera"});

                                                          // If we don't get data back, return outta here
                                                          if (!file.existsSync()) return;
                                                          if (file.statSync().size == 0) {
                                                          file.deleteSync();
                                                          return;
                                                          }

                                                          widget.parent.openNewChatCreator(existing: [
                                                          PlatformFile(
                                                          name: file.path.split("/").last,
                                                          path: file.path,
                                                          bytes: file.readAsBytesSync(),
                                                          size: file.lengthSync(),
                                                          )
                                                          ]);
                                                        } : null,
                                                        child: IconButton(
                                                            onPressed: () {
                                                              EventDispatcher().emit("update-highlight", null);
                                                              CustomNavigator.pushAndRemoveUntil(
                                                                context,
                                                                ConversationView(
                                                                  isCreator: true,
                                                                ),
                                                                (route) => route.isFirst,
                                                              );
                                                            },
                                                            icon: Icon(
                                                              Icons.create_outlined,
                                                              color: context.theme.colorScheme.properOnSurface,
                                                            ),
                                                          ),
                                                    )
                                                    : Container(),
                                                widget.parent.buildSettingsButton(),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : SafeArea(
                            child: Padding(
                                padding: const EdgeInsets.only(
                                  right: 20.0,
                                  left: 20.0,
                                  top: 10,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            selected = [];
                                            setState(() {});
                                          },
                                          icon: Icon(
                                            Icons.close,
                                            color: context.theme.colorScheme.primary,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          selected.length.toString(),
                                          style: context.theme.textTheme.titleLarge!.copyWith(color: context.theme.colorScheme.primary,),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (([0, selected.length])
                                            .contains(selected.where((element) => element.hasUnreadMessage!).length))
                                          IconButton(
                                            onPressed: () {
                                              for (Chat element in selected) {
                                                element.toggleHasUnread(!element.hasUnreadMessage!);
                                              }
                                              selected = [];
                                              if (mounted) setState(() {});
                                            },
                                            icon: Icon(
                                              selected[0].hasUnreadMessage!
                                                  ? Icons.mark_chat_read_outlined
                                                  : Icons.mark_chat_unread_outlined,
                                              color: context.theme.colorScheme.primary,
                                            ),
                                          ),
                                        if (([0, selected.length])
                                            .contains(selected.where((element) => element.muteType == "mute").length))
                                          IconButton(
                                            onPressed: () {
                                              for (Chat element in selected) {
                                                element.toggleMute(element.muteType != "mute");
                                              }
                                              selected = [];
                                              if (mounted) setState(() {});
                                            },
                                            icon: Icon(
                                              selected[0].muteType == "mute"
                                                  ? Icons.notifications_active_outlined
                                                  : Icons.notifications_off_outlined,
                                              color: context.theme.colorScheme.primary,
                                            ),
                                          ),
                                        if (([0, selected.length])
                                            .contains(selected.where((element) => element.isPinned!).length))
                                          IconButton(
                                            onPressed: () {
                                              for (Chat element in selected) {
                                                element.togglePin(!element.isPinned!);
                                              }
                                              selected = [];
                                              if (mounted) setState(() {});
                                            },
                                            icon: Icon(
                                              selected[0].isPinned! ? Icons.push_pin_outlined : Icons.push_pin,
                                              color: context.theme.colorScheme.primary,
                                            ),
                                          ),
                                        IconButton(
                                          onPressed: () {
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
                                          icon: Icon(
                                            showArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                                            color: context.theme.colorScheme.primary,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            for (Chat element in selected) {
                                              ChatBloc().deleteChat(element);
                                              Chat.deleteChat(element);
                                            }
                                            selected = [];
                                            if (mounted) setState(() {});
                                          },
                                          icon: Icon(
                                            Icons.delete_outlined,
                                            color: context.theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            backgroundColor: _backgroundColor.value,
            extendBodyBehindAppBar: true,
            body: Obx(
              () {
                if (!ChatBloc().loadedChatBatch.value) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.only(top: 100.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Loading chats...",
                              style: context.theme.textTheme.labelLarge,
                            ),
                          ),
                          buildProgressIndicator(context, size: 15),
                        ],
                      ),
                    ),
                  );
                }
                if (ChatBloc().loadedChatBatch.value && ChatBloc()
                    .chats
                    .archivedHelper(showArchived)
                    .unknownSendersHelper(showUnknown)
                    .bigPinHelper(false).isEmpty) {
                  return Center(
                    child: Container(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Text(
                        "You have no archived chats",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                  );
                }
                return NotificationListener(
                  onNotification: (notif) {
                    if (notif is ScrollStartNotification) {
                      _FABStatefulWrapperState.initialPosition = widget.parent.scrollController.offset;
                    }
                    return true;
                  },
                  child: ScrollbarWrapper(
                    showScrollbar: true,
                    controller: widget.parent.scrollController,
                    child: Obx(
                      () => ListView.builder(
                        controller: widget.parent.scrollController,
                        physics: (SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                            ? NeverScrollableScrollPhysics()
                            : ThemeSwitcher.getScrollPhysics(),
                        itemBuilder: (context, index) {
                          return Obx(() {
                            if (SettingsManager().settings.swipableConversationTiles.value) {
                              return Dismissible(
                                  background: (kIsDesktop || kIsWeb)
                                      ? null
                                      : Obx(() => slideRightBackground(ChatBloc()
                                          .chats
                                          .archivedHelper(showArchived)
                                          .unknownSendersHelper(showUnknown)[index])),
                                  secondaryBackground: (kIsDesktop || kIsWeb)
                                      ? null
                                      : Obx(() => slideLeftBackground(ChatBloc()
                                          .chats
                                          .archivedHelper(showArchived)
                                          .unknownSendersHelper(showUnknown)[index])),
                                  // Each Dismissible must contain a Key. Keys allow Flutter to
                                  // uniquely identify widgets.
                                  key: UniqueKey(),
                                  // Provide a function that tells the app
                                  // what to do after an item has been swiped away.
                                  onDismissed: (direction) async {
                                    if (direction == DismissDirection.endToStart) {
                                      if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.pin) {
                                        ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]
                                            .togglePin(!ChatBloc()
                                                .chats
                                                .archivedHelper(showArchived)
                                                .unknownSendersHelper(showUnknown)[index]
                                                .isPinned!);
                                        EventDispatcher().emit("refresh", null);
                                        if (mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]
                                            .toggleMute(ChatBloc()
                                                    .chats
                                                    .archivedHelper(showArchived)
                                                    .unknownSendersHelper(showUnknown)[index]
                                                    .muteType !=
                                                "mute");
                                        if (mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]);
                                        Chat.deleteChat(ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]);
                                      } else if (SettingsManager().settings.materialLeftAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc()
                                                .chats
                                                .archivedHelper(showArchived)
                                                .unknownSendersHelper(showUnknown)[index],
                                            !ChatBloc()
                                                .chats
                                                .archivedHelper(showArchived)
                                                .unknownSendersHelper(showUnknown)[index]
                                                .hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]
                                            .isArchived!) {
                                          ChatBloc().unArchiveChat(ChatBloc()
                                              .chats
                                              .archivedHelper(showArchived)
                                              .unknownSendersHelper(showUnknown)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc()
                                              .chats
                                              .archivedHelper(showArchived)
                                              .unknownSendersHelper(showUnknown)[index]);
                                        }
                                      }
                                    } else {
                                      if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.pin) {
                                        ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]
                                            .togglePin(!ChatBloc()
                                                .chats
                                                .archivedHelper(showArchived)
                                                .unknownSendersHelper(showUnknown)[index]
                                                .isPinned!);
                                        EventDispatcher().emit("refresh", null);
                                        if (mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.alerts) {
                                        ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]
                                            .toggleMute(ChatBloc()
                                                    .chats
                                                    .archivedHelper(showArchived)
                                                    .unknownSendersHelper(showUnknown)[index]
                                                    .muteType !=
                                                "mute");
                                        if (mounted) setState(() {});
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.delete) {
                                        ChatBloc().deleteChat(ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]);
                                        Chat.deleteChat(ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]);
                                      } else if (SettingsManager().settings.materialRightAction.value ==
                                          MaterialSwipeAction.mark_read) {
                                        ChatBloc().toggleChatUnread(
                                            ChatBloc()
                                                .chats
                                                .archivedHelper(showArchived)
                                                .unknownSendersHelper(showUnknown)[index],
                                            !ChatBloc()
                                                .chats
                                                .archivedHelper(showArchived)
                                                .unknownSendersHelper(showUnknown)[index]
                                                .hasUnreadMessage!);
                                      } else {
                                        if (ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]
                                            .isArchived!) {
                                          ChatBloc().unArchiveChat(ChatBloc()
                                              .chats
                                              .archivedHelper(showArchived)
                                              .unknownSendersHelper(showUnknown)[index]);
                                        } else {
                                          ChatBloc().archiveChat(ChatBloc()
                                              .chats
                                              .archivedHelper(showArchived)
                                              .unknownSendersHelper(showUnknown)[index]);
                                        }
                                      }
                                    }
                                  },
                                  child: (!showArchived &&
                                          ChatBloc()
                                              .chats
                                              .archivedHelper(showArchived)
                                              .unknownSendersHelper(showUnknown)[index]
                                              .isArchived!)
                                      ? Container()
                                      : (showArchived &&
                                              !ChatBloc()
                                                  .chats
                                                  .archivedHelper(showArchived)
                                                  .unknownSendersHelper(showUnknown)[index]
                                                  .isArchived!)
                                          ? Container()
                                          : ConversationTile(
                                              key: UniqueKey(),
                                              chat: ChatBloc()
                                                  .chats
                                                  .archivedHelper(showArchived)
                                                  .unknownSendersHelper(showUnknown)[index],
                                              inSelectMode: selected.isNotEmpty,
                                              selected: selected,
                                              onSelect: (bool selected) {
                                                if (selected) {
                                                  this.selected.add(ChatBloc()
                                                      .chats
                                                      .archivedHelper(showArchived)
                                                      .unknownSendersHelper(showUnknown)[index]);
                                                  setState(() {});
                                                } else {
                                                  this.selected.removeWhere((element) =>
                                                      element.guid ==
                                                      ChatBloc()
                                                          .chats
                                                          .archivedHelper(showArchived)
                                                          .unknownSendersHelper(showUnknown)[index]
                                                          .guid);
                                                  setState(() {});
                                                }
                                              },
                                            ));
                            } else {
                              return ConversationTile(
                                key: UniqueKey(),
                                chat: ChatBloc()
                                    .chats
                                    .archivedHelper(showArchived)
                                    .unknownSendersHelper(showUnknown)[index],
                                inSelectMode: selected.isNotEmpty,
                                selected: selected,
                                onSelect: (bool selected) {
                                  if (selected) {
                                    this.selected.add(ChatBloc()
                                        .chats
                                        .archivedHelper(showArchived)
                                        .unknownSendersHelper(showUnknown)[index]);
                                    setState(() {});
                                  } else {
                                    this.selected.removeWhere((element) =>
                                        element.guid ==
                                        ChatBloc()
                                            .chats
                                            .archivedHelper(showArchived)
                                            .unknownSendersHelper(showUnknown)[index]
                                            .guid);
                                    setState(() {});
                                  }
                                },
                              );
                            }
                          });
                        },
                        itemCount:
                            ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).length,
                      ),
                    ),
                  ),
                );
              },
            ),
            floatingActionButton: selected.isEmpty && !SettingsManager().settings.moveChatCreatorToHeader.value
                ? FABStatefulWrapper(parent: widget.parent)
                : null,
          ),
        ),
      ),
    );
  }

  Widget buildForLandscape(BuildContext context, Widget chatList) {
    final Rx<Color> _backgroundColor = (SettingsManager().settings.windowEffect.value == WindowEffect.disabled
        ? context.theme.colorScheme.background
        : Colors.transparent)
        .obs;

    if (kIsDesktop) {
      SettingsManager().settings.windowEffect.listen((WindowEffect effect) {
        if (mounted) {
          _backgroundColor.value =
          effect != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background;
        }
      });
    }

    return VerticalSplitView(
      initialRatio: 0.4,
      minRatio: kIsDesktop || kIsWeb ? 0.2 : 0.33,
      maxRatio: 0.5,
      allowResize: true,
      left: LayoutBuilder(builder: (context, constraints) {
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
      }),
      right: LayoutBuilder(builder: (context, constraints) {
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
            pages: [
              CupertinoPage(
                  name: "initial",
                  child: Scaffold(
                    backgroundColor: _backgroundColor.value,
                    extendBodyBehindAppBar: true,
                    body: Center(
                      child: Container(
                          child: Text("Select a chat from the list",
                              style: context.theme.textTheme.bodyLarge)),
                    ),
                  ))
            ],
          ),
        );
      }),
    );
  }

  Widget buildForDevice() {
    bool showAltLayout =
        SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape) && context.width > 600 && !LifeCycleManager().isBubble;
    Widget chatList = buildChatList();
    if (showAltLayout && !widget.parent.widget.showUnknownSenders && !widget.parent.widget.showArchivedChats) {
      return buildForLandscape(context, chatList);
    } else if (!widget.parent.widget.showArchivedChats && !widget.parent.widget.showUnknownSenders) {
      return TitleBarWrapper(child: chatList);
    }

    return chatList;
  }
}

class FABStatefulWrapper extends StatefulWidget {
  final ConversationListState parent;

  FABStatefulWrapper({required this.parent});

  @override
  State<StatefulWidget> createState() => _FABStatefulWrapperState();
}

class _FABStatefulWrapperState extends State<FABStatefulWrapper> {
  bool showText = true;
  static double initialPosition = 0;

  @override
  void initState() {
    super.initState();
    widget.parent.scrollController.addListener(() {
      if (SettingsManager().settings.skin.value != Skins.Material) return;
      if (initialPosition - widget.parent.scrollController.offset < -75 &&
          widget.parent.scrollController.position.userScrollDirection == ScrollDirection.reverse &&
          showText &&
          mounted) {
        setState(() {
          showText = false;
        });
      } else if (initialPosition - widget.parent.scrollController.offset > 75 &&
          widget.parent.scrollController.position.userScrollDirection == ScrollDirection.forward &&
          !showText &&
          mounted) {
        setState(() {
          showText = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: SettingsManager().settings.cameraFAB.value ? widget.parent.openCamera : null,
      child: Container(
        height: 65,
        padding: const EdgeInsets.fromLTRB(
          0,
          0,
          4.5,
          9,
        ),
        child: FloatingActionButton.extended(
          backgroundColor: context.theme.colorScheme.primaryContainer,
          label: AnimatedSwitcher(
            duration: Duration(milliseconds: 150),
            transitionBuilder: (Widget child, Animation<double> animation) => SizeTransition(
              child: child,
              sizeFactor: animation,
              axis: Axis.horizontal,
            ),
            child: showText
                ? Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: Text(
                      "Start Chat",
                      style: TextStyle(
                        color: context.theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                : Container(width: 0, height: 0),
          ),
          extendedIconLabelSpacing: 0,
          icon: Padding(
            padding: const EdgeInsets.only(left: 5.0),
            child: Icon(
                Icons.message_outlined,
                color: context.theme.colorScheme.onPrimaryContainer,
                size: 25),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          onPressed: widget.parent.openNewChatCreator,
        ),
      ),
    );
  }
}
