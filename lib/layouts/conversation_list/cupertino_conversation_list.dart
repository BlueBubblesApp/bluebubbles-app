import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/scrollbar_wrapper.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/vertical_split_view.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:universal_io/io.dart';

class CupertinoConversationList extends StatefulWidget {
  const CupertinoConversationList({Key? key, required this.parent}) : super(key: key);

  final ConversationListState parent;

  @override
  State<StatefulWidget> createState() => CupertinoConversationListState();
}

class CupertinoConversationListState extends State<CupertinoConversationList> {
  final key = GlobalKey<NavigatorState>();
  final Rx<Color> headerColor = Rx<Color>(Colors.transparent);
  bool openedChatAlready = false;

  @override
  void initState() {
    super.initState();
    widget.parent.scrollController.addListener(() {
      if (widget.parent.scrollController.hasClients && widget.parent.scrollController.offset > (125 - kToolbarHeight)) {
        headerColor.value = Get.theme.colorScheme.properSurface.withOpacity(0.5);
      } else {
        headerColor.value = Colors.transparent;
      }
    });
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Obx(() => buildForDevice(context)),
    );
  }

  Widget buildChatList(BuildContext context, bool showAltLayout) {
    bool showArchived = widget.parent.widget.showArchivedChats;
    bool showUnknown = widget.parent.widget.showUnknownSenders;
    Brightness brightness = context.theme.colorScheme.brightness;
    return Obx(
      () => Scaffold(
        appBar: kIsWeb || kIsDesktop
            ? null
            : PreferredSize(
                preferredSize: Size(
                  (showAltLayout) ? CustomNavigator.width(context) * 0.33 : CustomNavigator.width(context),
                  context.orientation == Orientation.landscape
                      ? 0
                      : SettingsManager().settings.reducedForehead.value
                          ? 10
                          : 40,
                ),
                child: ClipRRect(
                  child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Obx(
                        () => AnimatedCrossFade(
                          crossFadeState: headerColor.value == Colors.transparent || (showArchived || showUnknown)
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: Duration(milliseconds: 250),
                          secondChild: AppBar(
                            iconTheme: IconThemeData(color: context.theme.colorScheme.primary),
                            elevation: 0,
                            backgroundColor: headerColor.value,
                            centerTitle: true,
                            systemOverlayStyle:
                                brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                            title: Text(
                              showArchived
                                  ? "Archive"
                                  : showUnknown
                                      ? "Unknown Senders"
                                      : "Messages",
                              style: context.textTheme.titleMedium!.copyWith(color: context.theme.colorScheme.properOnSurface),
                            ),
                          ),
                          firstChild: !showArchived && !showUnknown ? AppBar(
                            leading: Container(),
                            elevation: 0,
                            systemOverlayStyle:
                                brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                            backgroundColor: context.theme.colorScheme.background,
                          ) : AppBar(
                            leading: buildBackButton(context),
                            elevation: 0,
                            systemOverlayStyle:
                            brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                            backgroundColor: context.theme.colorScheme.background,
                            centerTitle: true,
                            title: Text(
                                showArchived
                                    ? "Archive"
                                    : "Unknown Senders",
                                style: context.theme.textTheme.titleLarge),
                          ),
                        ),
                      )),
                ),
              ),
        backgroundColor: context.theme.colorScheme.background,
        extendBodyBehindAppBar: !showArchived && !showUnknown,
        body: ScrollbarWrapper(
          showScrollbar: true,
          controller: widget.parent.scrollController,
          child: Obx(
            () => CustomScrollView(
              controller: widget.parent.scrollController,
              physics: (SettingsManager().settings.betterScrolling.value && (kIsDesktop || kIsWeb))
                  ? NeverScrollableScrollPhysics()
                  : ThemeManager().scrollPhysics,
              slivers: <Widget>[
                if (!showArchived && !showUnknown)
                  SliverAppBar(
                    leading: null,
                    backgroundColor: Colors.transparent,
                    pinned: false,
                    centerTitle: true,
                    automaticallyImplyLeading: false,
                    title: Column(
                      children: <Widget>[
                        Container(
                          margin: EdgeInsets.only(left: 10, right: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  widget.parent.getHeaderTextWidget(),
                                  widget.parent.getConnectionIndicatorWidget(),
                                  widget.parent.getSyncIndicatorWidget(),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ClipOval(
                                    child: Material(
                                      color: context.theme.colorScheme.properSurface, // button color
                                      child: InkWell(
                                        child: SizedBox(
                                            width: 30,
                                            height: 30,
                                            child:
                                            Icon(CupertinoIcons.search, color: context.theme.colorScheme.properOnSurface, size: 20)),
                                        onTap: () async {
                                          CustomNavigator.pushLeft(context, SearchView());
                                        },
                                      ),
                                    ),
                                  ),
                                  Container(width: 10.0),
                                  if (SettingsManager().settings.moveChatCreatorToHeader.value)
                                    ClipOval(
                                      child: Material(
                                        color: context.theme.colorScheme.properSurface, // button color
                                        child: InkWell(
                                          child: SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: Icon(CupertinoIcons.pencil, color: context.theme.colorScheme.properOnSurface, size: 20),
                                          ),
                                          onTap: widget.parent.openNewChatCreator,
                                        ),
                                      ),
                                    ),
                                  if (SettingsManager().settings.moveChatCreatorToHeader.value &&
                                      SettingsManager().settings.cameraFAB.value)
                                    Container(width: 10.0),
                                  if (SettingsManager().settings.moveChatCreatorToHeader.value &&
                                      SettingsManager().settings.cameraFAB.value)
                                    ClipOval(
                                      child: Material(
                                        color: context.theme.colorScheme.properSurface, // button color
                                        child: InkWell(
                                          child: SizedBox(
                                            width: 30,
                                            height: 30,
                                            child: Icon(CupertinoIcons.camera, color: context.theme.colorScheme.properOnSurface, size: 20),
                                          ),
                                          onTap: () async {
                                            bool camera = await Permission.camera.isGranted;
                                            if (!camera) {
                                              bool granted =
                                                  (await Permission.camera.request()) == PermissionStatus.granted;
                                              if (!granted) {
                                                showSnackbar("Error", "Camera was denied");
                                                return;
                                              }
                                            }

                                            String appDocPath = SettingsManager().appDocDir.path;
                                            String ext = ".png";
                                            File file = File("$appDocPath/attachments/${randomString(16)}$ext");
                                            await file.create(recursive: true);

                                            // Take the picture after opening the camera
                                            await MethodChannelInterface()
                                                .invokeMethod("open-camera", {"path": file.path, "type": "camera"});

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
                                          },
                                        ),
                                      ),
                                    ),
                                  if (SettingsManager().settings.moveChatCreatorToHeader.value) Container(width: 10.0),
                                  widget.parent.buildSettingsButton(),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    )),
                // SliverToBoxAdapter(
                //   child: Container(
                //     padding: EdgeInsets.symmetric(horizontal: 30, vertical: 5),
                //     child: GestureDetector(
                //       onTap: () {
                //         Navigator.of(context).push(
                //           MaterialPageRoute(
                //             builder: (context) => SearchView(),
                //           ),
                //         );
                //       },
                //       child: AbsorbPointer(
                //         child: SearchTextBox(),
                //       ),
                //     ),
                //   ),
                // ),
                Obx(() {
                  if (ChatBloc()
                      .chats
                      .archivedHelper(showArchived)
                      .unknownSendersHelper(showUnknown)
                      .bigPinHelper(true)
                      .isEmpty) {
                    return SliverToBoxAdapter(child: Container());
                  }

                  int rowCount = context.mediaQuery.orientation == Orientation.portrait || kIsDesktop
                      ? SettingsManager().settings.pinRowsPortrait.value
                      : SettingsManager().settings.pinRowsLandscape.value;
                  int colCount = kIsDesktop
                      ? SettingsManager().settings.pinColumnsLandscape.value
                      : SettingsManager().settings.pinColumnsPortrait.value;
                  int pinCount = ChatBloc()
                      .chats
                      .archivedHelper(showArchived)
                      .unknownSendersHelper(showUnknown)
                      .bigPinHelper(true)
                      .length;
                  int usedRowCount = min((pinCount / colCount).ceil(), rowCount);
                  int maxOnPage = rowCount * colCount;
                  PageController _controller = PageController();
                  int _pageCount = (pinCount / maxOnPage).ceil();
                  int _filledPageCount = (pinCount / maxOnPage).floor();

                  return SliverPadding(
                    padding: EdgeInsets.only(
                      top: 10,
                      bottom: 0,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) => ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                (constraints.maxWidth) / colCount * usedRowCount * (showAltLayout ? 1.175 : 1.125),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.bottomCenter,
                            children: <Widget>[
                              PageView.builder(
                                clipBehavior: Clip.none,
                                physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                scrollDirection: Axis.horizontal,
                                controller: _controller,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.start,
                                      alignment: _pageCount > 1 ? WrapAlignment.start : WrapAlignment.center,
                                      children: List.generate(
                                        index < _filledPageCount
                                            ? maxOnPage
                                            : ChatBloc()
                                                    .chats
                                                    .archivedHelper(showArchived)
                                                    .unknownSendersHelper(showUnknown)
                                                    .bigPinHelper(true)
                                                    .length %
                                                maxOnPage,
                                        (_index) {
                                          return PinnedConversationTile(
                                            key: Key(ChatBloc()
                                                .chats
                                                .archivedHelper(showArchived)
                                                .unknownSendersHelper(showUnknown)
                                                .bigPinHelper(true)[index * maxOnPage + _index]
                                                .guid
                                                .toString()),
                                            chat: ChatBloc()
                                                .chats
                                                .archivedHelper(showArchived)
                                                .unknownSendersHelper(showUnknown)
                                                .bigPinHelper(true)[index * maxOnPage + _index],
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                                itemCount: _pageCount,
                              ),
                              if (_pageCount > 1)
                                SmoothPageIndicator(
                                  controller: _controller,
                                  count: _pageCount,
                                  effect: ScaleEffect(
                                    dotHeight: 5.0,
                                    dotWidth: 5.0,
                                    spacing: 5.0,
                                    radius: 5.0,
                                    scale: 1.5,
                                    activeDotColor: context.theme.colorScheme.secondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                Obx(() {
                  if (!ChatBloc().loadedChatBatch.value) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.only(top: 50.0),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  "Loading chats...",
                                  style: context.textTheme.labelLarge,
                                ),
                              ),
                              buildProgressIndicator(context, size: 15),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  if (ChatBloc().loadedChatBatch.value && ChatBloc()
                      .chats
                      .archivedHelper(showArchived)
                      .unknownSendersHelper(showUnknown)
                      .bigPinHelper(false).isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.only(top: 50.0),
                          child: Text(
                            showArchived
                                ? "You have no archived chats"
                                : showUnknown
                                    ? "You have no messages from unknown senders :)"
                                    : "You have no chats :(",
                            style: context.theme.textTheme.labelLarge,
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return ConversationTile(
                          key: Key(ChatBloc()
                              .chats
                              .archivedHelper(showArchived)
                              .unknownSendersHelper(showUnknown)
                              .bigPinHelper(false)[index]
                              .guid
                              .toString()),
                          chat: ChatBloc()
                              .chats
                              .archivedHelper(showArchived)
                              .unknownSendersHelper(showUnknown)
                              .bigPinHelper(false)[index],
                        );
                      },
                      childCount: ChatBloc()
                          .chats
                          .archivedHelper(showArchived)
                          .unknownSendersHelper(showUnknown)
                          .bigPinHelper(false)
                          .length,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        floatingActionButton: !SettingsManager().settings.moveChatCreatorToHeader.value
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
              pages: [
                CupertinoPage(
                  name: "initial",
                  child: Scaffold(
                    backgroundColor: context.theme.colorScheme.background,
                    extendBodyBehindAppBar: true,
                    body: Center(
                      child: Container(
                          child: Text("Select a chat from the list",
                              style: context.theme.textTheme.bodyLarge)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildForDevice(BuildContext context) {
    bool showAltLayout =
        SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape) && context.width > 600 && !LifeCycleManager().isBubble;
    Widget chatList = buildChatList(context, showAltLayout);
    if (showAltLayout && !widget.parent.widget.showUnknownSenders && !widget.parent.widget.showArchivedChats) {
      return buildForLandscape(context, chatList);
    } else if (!widget.parent.widget.showArchivedChats && !widget.parent.widget.showUnknownSenders) {
      return TitleBarWrapper(child: chatList);
    }
    return chatList;
  }
}
