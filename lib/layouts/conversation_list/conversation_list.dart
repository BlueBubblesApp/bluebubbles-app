import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

class ConversationList extends StatefulWidget {
  ConversationList({Key key, this.showArchivedChats}) : super(key: key);

  final bool showArchivedChats;

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  List<Chat> chats = [];
  bool colorfulAvatars = false;
  bool reducedForehead = false;
  bool showIndicator = false;
  bool showSyncIndicator = false;
  bool moveChatCreatorButton = false;

  Brightness brightness = Brightness.light;
  Color previousBackgroundColor;

  Color currentHeaderColor;
  bool gotBrightness = false;
  bool hasPinnedChata = false;

  // ignore: close_sinks
  StreamController<Color> headerColorStream = StreamController<Color>.broadcast();

  String model;
  int pinnedChats = 0;
  ScrollController scrollController;
  Skins skinSet;
  bool swipableTiles = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (this.mounted) {
      theme = Colors.transparent;
    }
  }

  @override
  void dispose() {
    super.dispose();

    // Remove the scroll listener from the state
    if (scrollController != null) scrollController.removeListener(scrollListener);
  }

  @override
  void initState() {
    super.initState();
    if (!widget.showArchivedChats) {
      ChatBloc().chatStream.listen((List<Chat> chats) {
        if (chats == null || chats.length == 0) return;
        this.chats = chats;
        if (this.mounted) setState(() {});
      });

      ChatBloc().refreshChats();
    } else {
      ChatBloc().archivedChatStream.listen((List<Chat> chats) {
        if (chats == null || chats.length == 0) return;
        this.chats = chats;
        if (this.mounted) setState(() {});
      });
      this.chats = ChatBloc().archivedChats;
    }

    colorfulAvatars = SettingsManager().settings.colorfulAvatars;
    reducedForehead = SettingsManager().settings.reducedForehead;
    showIndicator = SettingsManager().settings.showConnectionIndicator;
    showSyncIndicator = SettingsManager().settings.showSyncIndicator;
    moveChatCreatorButton = SettingsManager().settings.moveChatCreatorToHeader;
    swipableTiles = SettingsManager().settings.swipableConversationTiles;
    skinSet = SettingsManager().settings.skin;

    SettingsManager().stream.listen((Settings newSettings) {
      if (!this.mounted) return;
      if (newSettings.colorfulAvatars != colorfulAvatars) {
        setState(() {
          colorfulAvatars = newSettings.colorfulAvatars;
        });
      } else if (newSettings.reducedForehead != reducedForehead) {
        setState(() {
          reducedForehead = newSettings.reducedForehead;
        });
      } else if (newSettings.showConnectionIndicator != showIndicator) {
        setState(() {
          showIndicator = newSettings.showConnectionIndicator;
        });
      } else if (newSettings.moveChatCreatorToHeader != moveChatCreatorButton) {
        setState(() {
          moveChatCreatorButton = newSettings.moveChatCreatorToHeader;
        });
      } else if (newSettings.swipableConversationTiles != swipableTiles) {
        setState(() {
          swipableTiles = newSettings.swipableConversationTiles;
        });
      } else if (newSettings.skin != skinSet) {
        setState(() {
          skinSet = newSettings.skin;
        });
      } else if (newSettings.showSyncIndicator != showSyncIndicator) {
        setState(() {
          showSyncIndicator = newSettings.showSyncIndicator;
        });
      }
    });

    scrollController = ScrollController()..addListener(scrollListener);

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'show-snackbar') {
        // Make sure that the app is open and the conversation list is present
        if (!LifeCycleManager().isAlive || CurrentChat.activeChat != null || context == null) return;
        final snackBar = SnackBar(content: Text(event["data"]["text"]));
        Scaffold.of(context).hideCurrentSnackBar();
        Scaffold.of(context).showSnackBar(snackBar);
      } else if (event["type"] == 'refresh' && this.mounted) {
        setState(() {});
      } else if (event["type"] == 'theme-update' && this.mounted) {
        setState(() {
          gotBrightness = false;
        });
      }
    });
  }

  Color get theme => currentHeaderColor;

  set theme(Color color) {
    if (currentHeaderColor == color) return;
    currentHeaderColor = color;
    if (!headerColorStream.isClosed) headerColorStream.sink.add(currentHeaderColor);
  }

  void scrollListener() {
    !_isAppBarExpanded ? theme = Colors.transparent : theme = Theme.of(context).accentColor.withOpacity(0.5);
  }

  void loadBrightness() {
    Color now = Theme.of(context).backgroundColor;
    bool themeChanged = previousBackgroundColor == null || previousBackgroundColor != now;
    if (!themeChanged && gotBrightness) return;

    previousBackgroundColor = now;
    if (this.context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = now.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
    if (this.mounted) setState(() {});
  }

  bool get _isAppBarExpanded {
    return scrollController != null && scrollController.hasClients && scrollController.offset > (125 - kToolbarHeight);
  }

  List<Widget> getHeaderTextWidgets({double size}) {
    TextStyle style = Theme.of(context).textTheme.headline1;
    if (size != null) style = style.copyWith(fontSize: size);

    return [Text(widget.showArchivedChats ? "Archive" : "Messages", style: style), Container(width: 10)];
  }

  List<Widget> getSyncIndicatorWidgets() {
    if (!showSyncIndicator) return [];

    return [
      StreamBuilder(
        stream: SocketManager().setup.stream,
        initialData: SetupData(0, []),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data.progress < 1 || snapshot.data.progress >= 100) return Container();

          if (skinSet == Skins.IOS) {
            return Theme(
              data: ThemeData(
                cupertinoOverrideTheme: CupertinoThemeData(brightness: brightness),
              ),
              child: CupertinoActivityIndicator(
                radius: 6.5,
              ),
            );
          }

          return Container(
              constraints: BoxConstraints(maxHeight: 15, maxWidth: 15),
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ));
        },
      )
    ];
  }

  void openNewChatCreator() async {
    bool shouldShowSnackbar = (await SettingsManager().getMacOSVersion()) >= 11;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (BuildContext context) {
          return ConversationView(
            isCreator: true,
            showSnackbar: shouldShowSnackbar,
          );
        },
      ),
    );
  }

  void sortChats() {
    chats.sort((a, b) {
      if (!a.isPinned && b.isPinned) return 1;
      if (a.isPinned && !b.isPinned) return -1;
      if (a.latestMessageDate == null && b.latestMessageDate == null) return 0;
      if (a.latestMessageDate == null) return 1;
      if (b.latestMessageDate == null) return -1;
      return -a.latestMessageDate.compareTo(b.latestMessageDate);
    });
  }

  Widget buildSettingsButton() => !widget.showArchivedChats
      ? PopupMenuButton(
          color: Theme.of(context).accentColor,
          onSelected: (value) {
            if (value == 0) {
              ChatBloc().markAllAsRead();
            } else if (value == 1) {
              Navigator.of(context).push(
                ThemeSwitcher.buildPageRoute(
                  builder: (context) => ConversationList(
                    showArchivedChats: true,
                  ),
                ),
              );
            } else if (value == 2) {
              Navigator.of(context).push(
                ThemeSwitcher.buildPageRoute(
                  builder: (BuildContext context) {
                    return SettingsPanel();
                  },
                ),
              );
            }
          },
          itemBuilder: (context) {
            return <PopupMenuItem>[
              PopupMenuItem(
                value: 0,
                child: Text(
                  'Mark all as read',
                  style: Theme.of(context).textTheme.bodyText1,
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Text(
                  'Archived',
                  style: Theme.of(context).textTheme.bodyText1,
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.bodyText1,
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
                color: Theme.of(context).accentColor,
              ),
              child: Icon(
                Icons.more_horiz,
                color: Theme.of(context).primaryColor,
                size: 15,
              ),
            ),
            materialSkin: Icon(
              Icons.more_vert,
              color: Theme.of(context).textTheme.bodyText1.color,
              size: 25,
            ),
            samsungSkin: Icon(
              Icons.more_vert,
              color: Theme.of(context).textTheme.bodyText1.color,
              size: 25,
            ),
          ),
        )
      : Container();

  FloatingActionButton buildFloatinActionButton() {
    return FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.message, color: Colors.white, size: 25),
        onPressed: openNewChatCreator);
  }

  List<Widget> getConnectionIndicatorWidgets() {
    if (!showIndicator) return [];

    return [
      StreamBuilder(
          stream: SocketManager().connectionStateStream,
          builder: (context, AsyncSnapshot<SocketState> snapshot) {
            SocketState connectionStatus;
            if (snapshot.hasData) {
              connectionStatus = snapshot.data;
            } else {
              connectionStatus = SocketManager().state;
            }

            return getIndicatorIcon(connectionStatus, size: 12);
          }),
      Container(width: 10.0)
    ];
  }

  @override
  Widget build(BuildContext context) {
    loadBrightness();
    return ThemeSwitcher(
      iOSSkin: _Cupertino(parent: this),
      materialSkin: _Material(parent: this),
      samsungSkin: _Samsung(parent: this),
    );
  }
}

class _Cupertino extends StatelessWidget {
  const _Cupertino({Key key, @required this.parent}) : super(key: key);

  final _ConversationListState parent;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size(
            MediaQuery.of(context).size.width,
            parent.reducedForehead ? 10 : 40,
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: StreamBuilder<Color>(
                  stream: parent.headerColorStream.stream,
                  builder: (context, snapshot) {
                    return AnimatedCrossFade(
                      crossFadeState:
                          parent.theme == Colors.transparent ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      duration: Duration(milliseconds: 250),
                      secondChild: AppBar(
                        iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
                        elevation: 0,
                        backgroundColor: parent.theme,
                        centerTitle: true,
                        brightness: parent.brightness,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Text(
                              parent.widget.showArchivedChats ? "Archive" : "Messages",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                          ],
                        ),
                      ),
                      firstChild: AppBar(
                        leading: new Container(),
                        elevation: 0,
                        brightness: parent.brightness,
                        backgroundColor: Theme.of(context).backgroundColor,
                      ),
                    );
                  }),
            ),
          ),
        ),
        backgroundColor: Theme.of(context).backgroundColor,
        extendBodyBehindAppBar: true,
        body: CustomScrollView(
          controller: parent.scrollController,
          physics: ThemeManager().scrollPhysics,
          slivers: <Widget>[
            SliverAppBar(
              leading: ((SettingsManager().settings.skin == Skins.IOS && parent.widget.showArchivedChats) ||
                      (SettingsManager().settings.skin == Skins.Material ||
                              SettingsManager().settings.skin == Skins.Samsung) &&
                          !parent.widget.showArchivedChats)
                  ? IconButton(
                      icon: Icon(
                          (SettingsManager().settings.skin == Skins.IOS && parent.widget.showArchivedChats)
                              ? Icons.arrow_back_ios
                              : Icons.arrow_back,
                          color: Theme.of(context).primaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  : new Container(),
              stretch: true,
              onStretchTrigger: () {
                return null;
              },
              expandedHeight: (!parent.widget.showArchivedChats) ? 80 : 50,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: <Widget>[
                          Container(width: (!parent.widget.showArchivedChats) ? 20 : 50),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ...parent.getHeaderTextWidgets(),
                              ...parent.getConnectionIndicatorWidgets(),
                              ...parent.getSyncIndicatorWidgets(),
                            ],
                          ),
                          Spacer(
                            flex: 25,
                          ),
                          if (!parent.widget.showArchivedChats)
                            ClipOval(
                              child: Material(
                                color: Theme.of(context).accentColor, // button color
                                child: InkWell(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Icon(Icons.search, color: Theme.of(context).primaryColor, size: 12)),
                                    onTap: () async {
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder: (context) => SearchView(),
                                        ),
                                      );
                                    }),
                              ),
                            ),
                          if (!parent.widget.showArchivedChats) Container(width: 10.0),
                          if (parent.moveChatCreatorButton && !parent.widget.showArchivedChats)
                            ClipOval(
                              child: Material(
                                color: Theme.of(context).accentColor, // button color
                                child: InkWell(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Icon(Icons.create, color: Theme.of(context).primaryColor, size: 12)),
                                    onTap: this.parent.openNewChatCreator),
                              ),
                            ),
                          if (parent.moveChatCreatorButton) Container(width: 10.0),
                          parent.buildSettingsButton(),
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
            StreamBuilder(
              stream: ChatBloc().chatStream,
              builder: (BuildContext context, AsyncSnapshot<List<Chat>> snapshot) {
                if (snapshot.hasData || parent.widget.showArchivedChats) {
                  parent.chats.sort(Chat.sort);
                  if (parent.chats.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.only(top: 50.0),
                          child: Text(
                            (parent.widget.showArchivedChats)
                                ? "You have no archived chats :("
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
                        if (!parent.widget.showArchivedChats && parent.chats[index].isArchived) return Container();
                        if (parent.widget.showArchivedChats && !parent.chats[index].isArchived) return Container();
                        return ConversationTile(
                          key: Key(parent.chats[index].guid.toString()),
                          chat: parent.chats[index],
                        );
                      },
                      childCount: parent.chats?.length ?? 0,
                    ),
                  );
                } else {
                  return SliverToBoxAdapter(child: Container());
                }
              },
            ),
          ],
        ),
        floatingActionButton: !parent.moveChatCreatorButton ? parent.buildFloatinActionButton() : null,
      ),
    );
  }
}

class _Material extends StatefulWidget {
  _Material({Key key, @required this.parent}) : super(key: key);

  final _ConversationListState parent;

  @override
  __MaterialState createState() => __MaterialState();
}

class __MaterialState extends State<_Material> {
  Brightness brightness;
  DisplayMode currentMode;
  bool gotBrightness = false;
  List<DisplayMode> modes;
  Color previousBackgroundColor;
  List<Chat> selected = [];

  void loadBrightness() {
    Color now = Theme.of(context).backgroundColor;
    bool themeChanged = previousBackgroundColor == null || previousBackgroundColor != now;
    if (!themeChanged && gotBrightness) return;

    previousBackgroundColor = now;
    if (this.context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = now.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
    if (this.mounted) setState(() {});
  }

  bool hasPinnedChat() {
    for (var i = 0; i < widget.parent.chats.length; i++) {
      if (widget.parent.chats[i].isPinned) {
        widget.parent.hasPinnedChata = true;
        return true;
      } else {
        return false;
      }
    }
    return false;
  }

  bool hasNormalChats() {
    int counter = 0;
    for (var i = 0; i < widget.parent.chats.length; i++) {
      if (widget.parent.chats[i].isPinned) {
        counter++;
      } else {}
    }
    if (counter == widget.parent.chats.length) {
      return false;
    } else {
      return true;
    }
  }

  Widget slideLeftBackground() {
    return Container(
      color: Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              Icons.delete,
              color: Colors.white,
            ),
            Text(
              " Archive",
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

  Widget slideLeftBackgroundArchived() {
    return Container(
      color: Colors.green,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              Icons.restore_from_trash,
              color: Colors.white,
            ),
            Text(
              " Unarchive",
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

  Widget slideRightBackground() {
    return Container(
      color: Colors.yellow,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 20,
            ),
            Icon(
              Icons.star,
              color: Colors.white,
            ),
            Text(
              " Pin",
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

  Widget slideRightBackgroundPinned() {
    return Container(
      color: Colors.yellow,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 20,
            ),
            Icon(
              Icons.star_outline,
              color: Colors.white,
            ),
            Text(
              " Unpin",
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
    loadBrightness();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            child: selected.isEmpty
                ? AppBar(
                    iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
                    brightness: brightness,
                    bottom: PreferredSize(
                      child: Container(
                        color: Theme.of(context).dividerColor,
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
                        ...widget.parent.getSyncIndicatorWidgets(),
                      ],
                    ),
                    actions: [
                      (!widget.parent.widget.showArchivedChats)
                          ? GestureDetector(
                              onTap: () async {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => SearchView(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.search,
                                  color: Theme.of(context).textTheme.bodyText1.color,
                                ),
                              ),
                            )
                          : Container(),
                      (SettingsManager().settings.moveChatCreatorToHeader && !widget.parent.widget.showArchivedChats)
                          ? GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  ThemeSwitcher.buildPageRoute(
                                    builder: (BuildContext context) {
                                      return ConversationView(
                                        isCreator: true,
                                      );
                                    },
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.create,
                                  color: Theme.of(context).textTheme.bodyText1.color,
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
                    backgroundColor: Theme.of(context).backgroundColor,
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
                                    element.isMuted = !element.isMuted;
                                    await element.save(updateLocalVals: true);
                                  });
                                  if (this.mounted) setState(() {});
                                  selected = [];
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.notifications_off,
                                    color: Theme.of(context).textTheme.bodyText1.color,
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: () {
                                selected.forEach((element) {
                                  if (element.isArchived) {
                                    ChatBloc().unArchiveChat(element);
                                  } else {
                                    ChatBloc().archiveChat(element);
                                  }
                                });
                                selected = [];
                                setState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  widget.parent.widget.showArchivedChats ? Icons.restore_from_trash : Icons.delete,
                                  color: Theme.of(context).textTheme.bodyText1.color,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                selected.forEach((element) {
                                  if (element.isPinned) {
                                    element.unpin();
                                  } else {
                                    element.pin();
                                  }
                                });
                                selected = [];
                                setState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.star,
                                  color: Theme.of(context).textTheme.bodyText1.color,
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
        backgroundColor: Theme.of(context).backgroundColor,
        body: StreamBuilder(
          stream: ChatBloc().chatStream,
          builder: (context, snapshot) {
            if (snapshot.hasData || widget.parent.widget.showArchivedChats || widget.parent.chats.isNotEmpty) {
              widget.parent.sortChats();
              if (widget.parent.chats.isEmpty) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text(
                      "You have no archived chats :(",
                      style: Theme.of(context).textTheme.subtitle1,
                    ),
                  ),
                );
              }
              return ListView.builder(
                  physics: ThemeSwitcher.getScrollPhysics(),
                  itemBuilder: (context, index) {
                    if (widget.parent.swipableTiles) {
                      return Dismissible(
                          background: (widget.parent.chats[index].isPinned)
                              ? slideRightBackgroundPinned()
                              : slideRightBackground(),
                          secondaryBackground: (!widget.parent.widget.showArchivedChats)
                              ? slideLeftBackground()
                              : slideLeftBackgroundArchived(),
                          // Each Dismissible must contain a Key. Keys allow Flutter to
                          // uniquely identify widgets.
                          key: UniqueKey(),
                          // Provide a function that tells the app
                          // what to do after an item has been swiped away.
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart) {
                              if (!widget.parent.widget.showArchivedChats) widget.parent.chats[index].unpin();

                              setState(() {
                                Scaffold.of(context).hideCurrentSnackBar();
                                (!widget.parent.widget.showArchivedChats)
                                    ? ChatBloc().archiveChat(widget.parent.chats[index])
                                    : ChatBloc().unArchiveChat(widget.parent.chats[index]);
                                widget.parent.chats.remove(index);
                              });
                            } else {
                              setState(() {
                                Scaffold.of(context).hideCurrentSnackBar();
                                if (widget.parent.chats[index].isPinned) {
                                  widget.parent.chats[index].unpin();
                                  widget.parent.chats.remove(index);
                                } else {
                                  widget.parent.chats[index].pin();
                                  widget.parent.chats.remove(index);
                                }
                              });
                            }
                          },
                          child: (!widget.parent.widget.showArchivedChats && widget.parent.chats[index].isArchived)
                              ? Container()
                              : (widget.parent.widget.showArchivedChats && !widget.parent.chats[index].isArchived)
                                  ? Container()
                                  : ConversationTile(
                                      key: UniqueKey(),
                                      chat: widget.parent.chats[index],
                                      inSelectMode: selected.isNotEmpty,
                                      selected: selected,
                                      onSelect: (bool selected) {
                                        if (selected) {
                                          this.selected.add(widget.parent.chats[index]);
                                          setState(() {});
                                        } else {
                                          this.selected.removeWhere(
                                              (element) => element.guid == widget.parent.chats[index].guid);
                                          setState(() {});
                                        }
                                      },
                                    ));
                    } else {
                      if (!widget.parent.widget.showArchivedChats && widget.parent.chats[index].isArchived)
                        return Container();
                      if (widget.parent.widget.showArchivedChats && !widget.parent.chats[index].isArchived)
                        return Container();
                      return ConversationTile(
                        key: UniqueKey(),
                        chat: widget.parent.chats[index],
                        inSelectMode: selected.isNotEmpty,
                        selected: selected,
                        onSelect: (bool selected) {
                          if (selected) {
                            this.selected.add(widget.parent.chats[index]);
                            setState(() {});
                          } else {
                            this.selected.removeWhere((element) => element.guid == widget.parent.chats[index].guid);
                            setState(() {});
                          }
                        },
                      );
                    }
                  },
                  itemCount: widget.parent.chats?.length ?? 0);
            } else {
              return Container();
            }
          },
        ),
        floatingActionButton: selected.isEmpty && !SettingsManager().settings.moveChatCreatorToHeader
            ? widget.parent.buildFloatinActionButton()
            : null,
      ),
    );
  }
}

class _Samsung extends StatefulWidget {
  _Samsung({Key key, @required this.parent}) : super(key: key);

  final _ConversationListState parent;

  @override
  _SamsungState createState() => _SamsungState();
}

class _SamsungState extends State<_Samsung> {
  Brightness brightness;
  DisplayMode currentMode;
  bool gotBrightness = false;
  List<DisplayMode> modes;
  Color previousBackgroundColor;
  List<Chat> selected = [];

  void loadBrightness() {
    Color now = Theme.of(context).backgroundColor;
    bool themeChanged = previousBackgroundColor == null || previousBackgroundColor != now;
    if (!themeChanged && gotBrightness) return;

    previousBackgroundColor = now;
    if (this.context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = now.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
    if (this.mounted) setState(() {});
  }

  bool hasPinnedChat() {
    for (var i = 0; i < widget.parent.chats.length; i++) {
      if (widget.parent.chats[i].isPinned) {
        widget.parent.hasPinnedChata = true;
        return true;
      } else {
        return false;
      }
    }
    return false;
  }

  bool hasNormalChats() {
    int counter = 0;
    for (var i = 0; i < widget.parent.chats.length; i++) {
      if (widget.parent.chats[i].isPinned) {
        counter++;
      } else {}
    }
    if (counter == widget.parent.chats.length) {
      return false;
    } else {
      return true;
    }
  }

  Widget slideLeftBackground() {
    return Container(
      color: Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              Icons.delete,
              color: Colors.white,
            ),
            Text(
              " Archive",
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

  Widget slideLeftBackgroundArchived() {
    return Container(
      color: Colors.green,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Icon(
              Icons.restore_from_trash,
              color: Colors.white,
            ),
            Text(
              " Unarchive",
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

  Widget slideRightBackground() {
    return Container(
      color: Colors.yellow,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 20,
            ),
            Icon(
              Icons.star,
              color: Colors.white,
            ),
            Text(
              " Pin",
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

  Widget slideRightBackgroundPinned() {
    return Container(
      color: Colors.yellow,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 20,
            ),
            Icon(
              Icons.star_outline,
              color: Colors.white,
            ),
            Text(
              " Unpin",
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
    loadBrightness();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor,
      ),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            child: selected.isEmpty
                ? AppBar(
                    shadowColor: Colors.transparent,
                    iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
                    brightness: brightness,
                    bottom: PreferredSize(
                      child: Container(
                        color: Theme.of(context).dividerColor,
                        height: 0,
                      ),
                      preferredSize: Size.fromHeight(0.5),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        ...widget.parent.getHeaderTextWidgets(size: 20),
                        ...widget.parent.getConnectionIndicatorWidgets(),
                        ...widget.parent.getSyncIndicatorWidgets(),
                      ],
                    ),
                    actions: [
                      (!widget.parent.widget.showArchivedChats)
                          ? GestureDetector(
                              onTap: () async {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (context) => SearchView(),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.search,
                                  color: Theme.of(context).textTheme.bodyText1.color,
                                ),
                              ),
                            )
                          : Container(),
                      (SettingsManager().settings.moveChatCreatorToHeader && !widget.parent.widget.showArchivedChats)
                          ? GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  ThemeSwitcher.buildPageRoute(
                                    builder: (BuildContext context) {
                                      return ConversationView(
                                        isCreator: true,
                                      );
                                    },
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.create,
                                  color: Theme.of(context).textTheme.bodyText1.color,
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
                    backgroundColor: Theme.of(context).backgroundColor,
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
                                    element.isMuted = !element.isMuted;
                                    await element.save(updateLocalVals: true);
                                  });
                                  if (this.mounted) setState(() {});
                                  selected = [];
                                  setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    Icons.notifications_off,
                                    color: Theme.of(context).textTheme.bodyText1.color,
                                  ),
                                ),
                              ),
                            GestureDetector(
                              onTap: () {
                                selected.forEach((element) {
                                  if (element.isArchived) {
                                    ChatBloc().unArchiveChat(element);
                                  } else {
                                    ChatBloc().archiveChat(element);
                                  }
                                });
                                selected = [];
                                setState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  widget.parent.widget.showArchivedChats ? Icons.restore_from_trash : Icons.delete,
                                  color: Theme.of(context).textTheme.bodyText1.color,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                selected.forEach((element) {
                                  if (element.isPinned) {
                                    element.unpin();
                                  } else {
                                    element.pin();
                                  }
                                });
                                selected = [];
                                setState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Icon(
                                  Icons.star,
                                  color: Theme.of(context).textTheme.bodyText1.color,
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
        backgroundColor: Theme.of(context).backgroundColor,
        body: StreamBuilder(
          stream: ChatBloc().chatStream,
          builder: (context, snapshot) {
            if (snapshot.hasData || widget.parent.widget.showArchivedChats || widget.parent.chats.isNotEmpty) {
              widget.parent.sortChats();
              if (widget.parent.chats.isEmpty) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text(
                      "You have no archived chats :(",
                      style: Theme.of(context).textTheme.subtitle1,
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
                            borderRadius: BorderRadius.all(Radius.circular(20))),
                      ),
                    if (hasPinned)
                      Container(
                        padding: EdgeInsets.all(6.0),
                        decoration: new BoxDecoration(
                            color: Theme.of(context).accentColor, borderRadius: BorderRadius.circular(20)),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            if (widget.parent.swipableTiles) {
                              return Dismissible(
                                background: slideRightBackgroundPinned(),
                                secondaryBackground: (!widget.parent.widget.showArchivedChats)
                                    ? slideLeftBackground()
                                    : slideLeftBackgroundArchived(),
                                // Each Dismissible must contain a Key. Keys allow Flutter to
                                // uniquely identify widgets.
                                key: UniqueKey(),
                                // Provide a function that tells the app
                                // what to do after an item has been swiped away.
                                onDismissed: (direction) {
                                  if (direction == DismissDirection.endToStart) {
                                    if (!widget.parent.widget.showArchivedChats) widget.parent.chats[index].unpin();
                                    setState(() {
                                      Scaffold.of(context).hideCurrentSnackBar();
                                      (!widget.parent.widget.showArchivedChats)
                                          ? ChatBloc().archiveChat(widget.parent.chats[index])
                                          : ChatBloc().unArchiveChat(widget.parent.chats[index]);

                                      widget.parent.chats.remove(index);
                                    });
                                  } else {
                                    setState(() {
                                      Scaffold.of(context).hideCurrentSnackBar();
                                      widget.parent.chats[index].unpin();
                                    });
                                  }
                                },
                                child: (!widget.parent.widget.showArchivedChats &&
                                        widget.parent.chats[index].isArchived)
                                    ? Container()
                                    : (widget.parent.widget.showArchivedChats && !widget.parent.chats[index].isArchived)
                                        ? Container()
                                        : (widget.parent.chats[index].isPinned)
                                            ? ConversationTile(
                                                key: UniqueKey(),
                                                chat: widget.parent.chats[index],
                                                inSelectMode: selected.isNotEmpty,
                                                selected: selected,
                                                onSelect: (bool selected) {
                                                  if (selected) {
                                                    this.selected.add(widget.parent.chats[index]);
                                                  } else {
                                                    this.selected.removeWhere(
                                                        (element) => element.guid == widget.parent.chats[index].guid);
                                                  }

                                                  if (this.mounted) setState(() {});
                                                },
                                              )
                                            : Container(),
                              );
                            } else {
                              if (!widget.parent.widget.showArchivedChats && widget.parent.chats[index].isArchived)
                                return Container();
                              if (widget.parent.widget.showArchivedChats && !widget.parent.chats[index].isArchived)
                                return Container();
                              if (widget.parent.chats[index].isPinned) {
                                return ConversationTile(
                                  key: UniqueKey(),
                                  chat: widget.parent.chats[index],
                                  inSelectMode: selected.isNotEmpty,
                                  selected: selected,
                                  onSelect: (bool selected) {
                                    if (selected) {
                                      this.selected.add(widget.parent.chats[index]);
                                      if (this.mounted) setState(() {});
                                    } else {
                                      this
                                          .selected
                                          .removeWhere((element) => element.guid == widget.parent.chats[index].guid);
                                      if (this.mounted) setState(() {});
                                    }
                                  },
                                );
                              }
                              return Container();
                            }
                          },
                          itemCount: widget.parent.chats?.length ?? 0,
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
                            color: Theme.of(context).accentColor,
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
                            if (widget.parent.swipableTiles) {
                              return Dismissible(
                                background: slideRightBackground(),
                                secondaryBackground: (!widget.parent.widget.showArchivedChats)
                                    ? slideLeftBackground()
                                    : slideLeftBackgroundArchived(),
                                // Each Dismissible must contain a Key. Keys allow Flutter to
                                // uniquely identify widgets.
                                key: UniqueKey(),
                                // Provide a function that tells the app
                                // what to do after an item has been swiped away.
                                onDismissed: (direction) {
                                  if (direction == DismissDirection.endToStart) {
                                    if (!widget.parent.widget.showArchivedChats) widget.parent.chats[index].unpin();
                                    setState(() {
                                      Scaffold.of(context).hideCurrentSnackBar();
                                      (!widget.parent.widget.showArchivedChats)
                                          ? ChatBloc().archiveChat(widget.parent.chats[index])
                                          : ChatBloc().unArchiveChat(widget.parent.chats[index]);
                                      widget.parent.chats.remove(index);
                                    });
                                  } else {
                                    setState(() {
                                      Scaffold.of(context).hideCurrentSnackBar();
                                      widget.parent.chats[index].pin();
                                    });
                                  }
                                },
                                child: (!widget.parent.widget.showArchivedChats &&
                                        widget.parent.chats[index].isArchived)
                                    ? Container()
                                    : (widget.parent.widget.showArchivedChats && !widget.parent.chats[index].isArchived)
                                        ? Container()
                                        : (!widget.parent.chats[index].isPinned)
                                            ? ConversationTile(
                                                key: UniqueKey(),
                                                chat: widget.parent.chats[index],
                                                inSelectMode: selected.isNotEmpty,
                                                selected: selected,
                                                onSelect: (bool selected) {
                                                  if (selected) {
                                                    this.selected.add(widget.parent.chats[index]);
                                                  } else {
                                                    this.selected.removeWhere(
                                                        (element) => element.guid == widget.parent.chats[index].guid);
                                                  }

                                                  if (this.mounted) setState(() {});
                                                },
                                              )
                                            : Container(),
                              );
                            } else {
                              if (!widget.parent.widget.showArchivedChats && widget.parent.chats[index].isArchived)
                                return Container();
                              if (widget.parent.widget.showArchivedChats && !widget.parent.chats[index].isArchived)
                                return Container();
                              if (!widget.parent.chats[index].isPinned) {
                                return ConversationTile(
                                  key: UniqueKey(),
                                  chat: widget.parent.chats[index],
                                  inSelectMode: selected.isNotEmpty,
                                  selected: selected,
                                  onSelect: (bool selected) {
                                    if (selected) {
                                      this.selected.add(widget.parent.chats[index]);
                                    } else {
                                      this
                                          .selected
                                          .removeWhere((element) => element.guid == widget.parent.chats[index].guid);
                                    }

                                    if (this.mounted) setState(() {});
                                  },
                                );
                              }
                              return Container();
                            }
                          },
                          itemCount: widget.parent.chats?.length ?? 0,
                        ),
                      )
                  ],
                ),
              );
            } else {
              return Container();
            }
          },
        ),
        floatingActionButton: selected.isEmpty && !SettingsManager().settings.moveChatCreatorToHeader
            ? widget.parent.buildFloatinActionButton()
            : null,
      ),
    );
  }
}
