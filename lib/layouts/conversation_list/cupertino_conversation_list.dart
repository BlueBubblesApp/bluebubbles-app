import 'dart:io';
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
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/widgets/vertical_split_view.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class CupertinoConversationList extends StatefulWidget {
  const CupertinoConversationList({Key? key, required this.parent}) : super(key: key);

  final ConversationListState parent;

  @override
  State<StatefulWidget> createState() => CupertinoConversationListState();
}

class CupertinoConversationListState extends State<CupertinoConversationList> {
  final key = new GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: context.theme.backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            context.theme.backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: buildForDevice(context),
    );
  }

  Widget buildChatList(BuildContext context, bool showAltLayout) {
    bool showArchived = widget.parent.widget.showArchivedChats;
    bool showUnknown = widget.parent.widget.showUnknownSenders;
    Brightness brightness = ThemeData.estimateBrightnessForColor(context.theme.backgroundColor);
    return Obx(
      () => Scaffold(
        appBar: PreferredSize(
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
              child: StreamBuilder<Color?>(
                stream: widget.parent.headerColorStream.stream,
                builder: (context, snapshot) {
                  return AnimatedCrossFade(
                    crossFadeState: widget.parent.theme == Colors.transparent
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: Duration(milliseconds: 250),
                    secondChild: AppBar(
                      iconTheme: IconThemeData(color: context.theme.primaryColor),
                      elevation: 0,
                      backgroundColor: widget.parent.theme,
                      centerTitle: true,
                      brightness: brightness,
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
                      leading: new Container(),
                      elevation: 0,
                      brightness: brightness,
                      backgroundColor: context.theme.backgroundColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        backgroundColor: context.theme.backgroundColor,
        extendBodyBehindAppBar: true,
        body: CustomScrollView(
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
                  : new Container(),
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
                    Container(height: 20),
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
                              ...widget.parent.getHeaderTextWidgets(),
                              ...widget.parent.getConnectionIndicatorWidgets(),
                              widget.parent.getSyncIndicatorWidget(),
                            ],
                          ),
                          Spacer(
                            flex: 25,
                          ),
                          if (!showArchived && !showUnknown)
                            ClipOval(
                              child: Material(
                                color: context.theme.accentColor, // button color
                                child: InkWell(
                                  child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Icon(CupertinoIcons.search, color: context.theme.primaryColor, size: 12)),
                                  onTap: () async {
                                    CustomNavigator.pushLeft(context, SearchView());
                                  },
                                ),
                              ),
                            ),
                          if (!showArchived && !showUnknown) Container(width: 10.0),
                          if (SettingsManager().settings.moveChatCreatorToHeader.value && !showArchived && !showUnknown)
                            ClipOval(
                              child: Material(
                                color: context.theme.accentColor, // button color
                                child: InkWell(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Icon(CupertinoIcons.pencil, color: context.theme.primaryColor, size: 12),
                                  ),
                                  onTap: this.widget.parent.openNewChatCreator,
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
                                color: context.theme.accentColor, // button color
                                child: InkWell(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Icon(CupertinoIcons.camera, color: context.theme.primaryColor, size: 12),
                                  ),
                                  onTap: () async {
                                    String appDocPath = SettingsManager().appDocDir.path;
                                    String ext = ".png";
                                    File file = new File("$appDocPath/attachments/" + randomString(16) + ext);
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

                                    widget.parent.openNewChatCreator(existing: [file]);
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
              ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).sort(Chat.sort);

              int rowCount = context.mediaQuery.orientation == Orientation.portrait
                  ? SettingsManager().settings.pinRowsPortrait.value
                  : SettingsManager().settings.pinRowsLandscape.value;
              int colCount = SettingsManager().settings.pinColumnsPortrait.value;
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
              ChatBloc().chats.archivedHelper(showArchived).unknownSendersHelper(showUnknown).sort(Chat.sort);
              if (!ChatBloc().hasChats.value) {
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
              if (!ChatBloc().hasChats.value) {
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
        floatingActionButton: !SettingsManager().settings.moveChatCreatorToHeader.value
            ? widget.parent.buildFloatingActionButton()
            : null,
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

  Widget buildForDevice(BuildContext context) {
    bool showAltLayout = !context.isPhone || context.isLandscape;
    Widget chatList = buildChatList(context, showAltLayout);
    if (showAltLayout && !widget.parent.widget.showUnknownSenders && !widget.parent.widget.showArchivedChats) {
      return buildForLandscape(context, chatList);
    }

    return chatList;
  }
}
