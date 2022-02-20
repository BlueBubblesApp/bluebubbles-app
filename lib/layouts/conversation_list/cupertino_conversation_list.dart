import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_list/pinned_conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/vertical_split_view.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_improved_scrolling/flutter_improved_scrolling.dart';
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
        headerColor.value = Get.context!.theme.colorScheme.secondary.withOpacity(0.5);
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
        ChatManager().activeChat?.chat.guid != prefs.getString('lastOpenedChat')) {
      await ChatBloc().chatRequest!.future;
      CustomNavigator.pushAndRemoveUntil(
        context,
        ConversationView(chat: ChatBloc().chats.firstWhere((e) => e.guid == prefs.getString('lastOpenedChat'))),
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
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value
            ? Colors.transparent
            : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Obx(() => buildForDevice(context)),
    );
  }

  Widget buildChatList(BuildContext context, bool showAltLayout) {
    bool showArchived = widget.parent.widget.showArchivedChats;
    bool showUnknown = widget.parent.widget.showUnknownSenders;
    Brightness brightness = ThemeData.estimateBrightnessForColor(context.theme.backgroundColor);
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
                          crossFadeState: headerColor.value == Colors.transparent
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: Duration(milliseconds: 250),
                          secondChild: AppBar(
                            iconTheme: IconThemeData(color: context.theme.primaryColor),
                            elevation: 0,
                            backgroundColor: headerColor.value,
                            centerTitle: true,
                            systemOverlayStyle:
                                brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: <Widget>[
                                Text(
                                  showArchived
                                      ? "Archive"
                                      : showUnknown
                                          ? "Unknown Senders"
                                          : "Messages",
                                  style: context.textTheme.bodyText1,
                                ),
                              ],
                            ),
                          ),
                          firstChild: AppBar(
                            leading: Container(),
                            elevation: 0,
                            systemOverlayStyle:
                                brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                            backgroundColor: context.theme.backgroundColor,
                          ),
                        ),
                      )),
                ),
              ),
        backgroundColor: context.theme.backgroundColor,
        extendBodyBehindAppBar: true,
        body: ImprovedScrolling(
          enableMMBScrolling: true,
          mmbScrollConfig: MMBScrollConfig(
            customScrollCursor: DefaultCustomScrollCursor(
              cursorColor: context.textTheme.subtitle1!.color!,
              backgroundColor: Colors.white,
              borderColor: context.textTheme.headline1!.color!,
            ),
          ),
          scrollController: widget.parent.scrollController,
          child: CustomScrollView(
            controller: widget.parent.scrollController,
            physics: ThemeManager().scrollPhysics,
            slivers: <Widget>[
              SliverAppBar(
                leading: ((SettingsManager().settings.skin.value == Skins.iOS && (showArchived || showUnknown)) ||
                        (SettingsManager().settings.skin.value == Skins.Material ||
                                SettingsManager().settings.skin.value == Skins.Samsung) &&
                            !showArchived &&
                            !showUnknown)
                    ? buildBackButton(context)
                    : Container(),
                stretch: true,
                expandedHeight: (!showArchived && !showUnknown) ? 80 : 50,
                backgroundColor: Colors.transparent,
                pinned: false,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: <StretchMode>[StretchMode.zoomBackground],
                  background: Stack(
                    fit: StackFit.expand,
                  ),
                  centerTitle: true,
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      if (!kIsWeb && !kIsDesktop) Container(height: 20),
                      Container(
                        margin: EdgeInsets.only(right: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Container(width: (!showArchived && !showUnknown) ? 20 : 50),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                widget.parent.getHeaderTextWidget(),
                                widget.parent.getConnectionIndicatorWidget(),
                                widget.parent.getSyncIndicatorWidget(),
                              ],
                            ),
                            Spacer(
                              flex: 25,
                            ),
                            if (!showArchived && !showUnknown)
                              ClipOval(
                                child: Material(
                                  color: context.theme.colorScheme.secondary, // button color
                                  child: InkWell(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            Icon(CupertinoIcons.search, color: context.theme.primaryColor, size: 12)),
                                    onTap: () async {
                                      CustomNavigator.pushLeft(context, SearchView());
                                    },
                                  ),
                                ),
                              ),
                            if (!showArchived && !showUnknown) Container(width: 10.0),
                            if (SettingsManager().settings.moveChatCreatorToHeader.value &&
                                !showArchived &&
                                !showUnknown)
                              ClipOval(
                                child: Material(
                                  color: context.theme.colorScheme.secondary, // button color
                                  child: InkWell(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Icon(CupertinoIcons.pencil, color: context.theme.primaryColor, size: 12),
                                    ),
                                    onTap: widget.parent.openNewChatCreator,
                                  ),
                                ),
                              ),
                            if (SettingsManager().settings.moveChatCreatorToHeader.value &&
                                SettingsManager().settings.cameraFAB.value)
                              Container(width: 10.0),
                            if (SettingsManager().settings.moveChatCreatorToHeader.value &&
                                SettingsManager().settings.cameraFAB.value &&
                                !showArchived &&
                                !showUnknown)
                              ClipOval(
                                child: Material(
                                  color: context.theme.colorScheme.secondary, // button color
                                  child: InkWell(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Icon(CupertinoIcons.camera, color: context.theme.primaryColor, size: 12),
                                    ),
                                    onTap: () async {
                                      bool camera = await Permission.camera.isGranted;
                                      if (!camera) {
                                        bool granted = (await Permission.camera.request()) == PermissionStatus.granted;
                                        if (!granted) {
                                          showSnackbar("Error", "Camera was denied");
                                          return;
                                        }
                                      }

                                      String appDocPath = SettingsManager().appDocDir.path;
                                      String ext = ".png";
                                      File file = File("$appDocPath/attachments/" + randomString(16) + ext);
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
                            Spacer(
                              flex: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                    top: 0,
                    bottom: 10,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) => ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: (constraints.maxWidth) / colCount * usedRowCount * (showAltLayout ? 1.175 : 1.125),
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
                                    crossAxisAlignment: WrapCrossAlignment.center,
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
                                  activeDotColor: context.theme.primaryColor,
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
                                style: Theme.of(context).textTheme.subtitle1,
                              ),
                            ),
                            buildProgressIndicator(context, size: 15),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                if (ChatBloc().loadedChatBatch.value && !ChatBloc().hasChats.value) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.only(top: 50.0),
                        child: Text(
                          showArchived
                              ? "You have no archived chats :("
                              : showUnknown
                                  ? "You have no messages from unknown senders :)"
                                  : "You have no chats :(",
                          style: Theme.of(context).textTheme.subtitle1,
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
                    backgroundColor: context.theme.backgroundColor,
                    extendBodyBehindAppBar: true,
                    body: Center(
                      child: Container(
                          child: Text("Select a chat from the list",
                              style: Theme.of(Get.context!).textTheme.subtitle1!.copyWith(fontSize: 18))),
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
        SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape) && context.width > 600;
    Widget chatList = buildChatList(context, showAltLayout);
    if (showAltLayout && !widget.parent.widget.showUnknownSenders && !widget.parent.widget.showArchivedChats) {
      return buildForLandscape(context, chatList);
    } else if (!widget.parent.widget.showArchivedChats && !widget.parent.widget.showUnknownSenders) {
      return TitleBarWrapper(child: chatList);
    }
    return chatList;
  }
}
