import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/search/search_text_box.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/services.dart';

import './conversation_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../settings/settings_panel.dart';

class ConversationList extends StatefulWidget {
  ConversationList({Key key, this.showArchivedChats}) : super(key: key);
  final bool showArchivedChats;

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  ScrollController scrollController;
  List<Chat> chats = <Chat>[];
  bool colorfulAvatars = false;

  Brightness brightness = Brightness.light;
  bool gotBrightness = false;
  String model;

  Color currentHeaderColor;
  StreamController<Color> headerColorStream =
      StreamController<Color>.broadcast();

  Color get theme => currentHeaderColor;
  set theme(Color color) {
    if (currentHeaderColor == color) return;
    currentHeaderColor = color;
    if (!headerColorStream.isClosed)
      headerColorStream.sink.add(currentHeaderColor);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    getDeviceModel();
    if (this.mounted) {
      theme = Colors.transparent;
    }
  }

  void scrollListener() {
    !_isAppBarExpanded
        ? theme = Colors.transparent
        : theme = Theme.of(context).accentColor.withOpacity(0.5);
  }

  @override
  void initState() {
    super.initState();

    if (!widget.showArchivedChats) {
      ChatBloc().chatStream.listen((List<Chat> chats) {
        this.chats = chats;
        if (this.mounted) setState(() {});
      });

      ChatBloc().refreshChats();
    } else {
      ChatBloc().archivedChatStream.listen((List<Chat> chats) {
        this.chats = chats;
        if (this.mounted) setState(() {});
      });
      this.chats = ChatBloc().archivedChats;
    }

    colorfulAvatars = SettingsManager().settings.colorfulAvatars;
    SettingsManager().stream.listen((Settings newSettings) {
      if (newSettings.colorfulAvatars != colorfulAvatars && this.mounted) {
        setState(() {
          colorfulAvatars = newSettings.colorfulAvatars;
        });
      }
    });

    scrollController = ScrollController()..addListener(scrollListener);

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'show-snackbar') {
        // Make sure that the app is open and the conversation list is present
        if (!LifeCycleManager().isAlive ||
            CurrentChat.activeChat != null ||
            context == null) return;
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

  void getDeviceModel() async {
    if (model != null) return;

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

    // If the device is a pixel device
    String mod = androidInfo?.model ?? "";
    if (mod.contains("4a") &&
        (mod.contains("pixel") || mod.contains("gphone"))) {
      model = "pixel";
      if (this.mounted) setState(() {});
    } else {
      model = "other";
    }
  }

  void loadBrightness() {
    if (gotBrightness) return;

    if (this.context == null) {
      brightness = Brightness.light;
      gotBrightness = true;
      return;
    }

    bool isDark = Theme.of(context).backgroundColor.computeLuminance() < 0.179;
    brightness = isDark ? Brightness.dark : Brightness.light;
    gotBrightness = true;
  }

  bool get _isAppBarExpanded {
    return scrollController != null &&
        scrollController.hasClients &&
        scrollController.offset > (125 - kToolbarHeight);
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
              Navigator.of(context).push(
                ThemeSwitcher.buildPageRoute(
                  builder: (context) => ConversationList(
                    showArchivedChats: true,
                  ),
                ),
              );
            } else if (value == 1) {
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
                  'Archived',
                  style: Theme.of(context).textTheme.bodyText1,
                ),
              ),
              PopupMenuItem(
                value: 1,
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
              color: Theme.of(context).textTheme.subtitle1.color,
              size: 25,
            ),
          ),
        )
      : Container();

  FloatingActionButton buildFloatinActionButton() => FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(Icons.message, color: Colors.white, size: 25),
        onPressed: () {
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
      );

  @override
  Widget build(BuildContext context) {
    loadBrightness();

    return ThemeSwitcher(
      iOSSkin: _Cupertino(parent: this),
      materialSkin: _Material(parent: this),
    );
  }

  @override
  void dispose() {
    super.dispose();

    // Remove the scroll listener from the state
    if (scrollController != null)
      scrollController.removeListener(scrollListener);
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
            40,
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: StreamBuilder<Color>(
                  stream: parent.headerColorStream.stream,
                  builder: (context, snapshot) {
                    return AnimatedCrossFade(
                      crossFadeState: parent.theme == Colors.transparent
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: Duration(milliseconds: 250),
                      secondChild: AppBar(
                        iconTheme: IconThemeData(
                            color: Theme.of(context).primaryColor),
                        elevation: 0,
                        backgroundColor: parent.theme,
                        centerTitle: true,
                        brightness: parent.brightness,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Text(
                              parent.widget.showArchivedChats
                                  ? "Archive"
                                  : "Messages",
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
              iconTheme: IconThemeData(
                  color: Theme.of(context).textTheme.headline1.color),
              stretch: true,
              onStretchTrigger: () {
                return null;
              },
              expandedHeight: 80,
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Spacer(
                            flex: 5,
                          ),
                          Container(
                            child: Text(
                              parent.widget.showArchivedChats
                                  ? "Archive"
                                  : "Messages",
                              style: Theme.of(context).textTheme.headline1,
                            ),
                          ),
                          Spacer(
                            flex: 25,
                          ),
                          parent.buildSettingsButton(),
                          Spacer(
                            flex: 1,
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
              builder:
                  (BuildContext context, AsyncSnapshot<List<Chat>> snapshot) {
                if (snapshot.hasData ||
                    parent.widget.showArchivedChats ||
                    parent.chats.isNotEmpty) {
                  parent.sortChats();
                  if (parent.chats.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.only(top: 50.0),
                          child: Text(
                            "You have no chats :(",
                            style: Theme.of(context).textTheme.subtitle1,
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (!parent.widget.showArchivedChats &&
                            parent.chats[index].isArchived) return Container();
                        if (parent.widget.showArchivedChats &&
                            !parent.chats[index].isArchived) return Container();
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
        floatingActionButton: parent.buildFloatinActionButton(),
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
  List<Chat> selected = [];

  @override
  Widget build(BuildContext context) {
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
                    bottom: PreferredSize(
                      child: Container(
                        color: Theme.of(context).dividerColor,
                        height: 0.5,
                      ),
                      preferredSize: Size.fromHeight(0.5),
                    ),
                    title: Text(
                      "Messages",
                      style: Theme.of(context)
                          .textTheme
                          .headline1
                          .copyWith(fontSize: 20),
                    ),
                    actions: [
                      Padding(
                        padding: EdgeInsets.only(right: 20),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 15.5),
                          child: Container(
                            width: 25,
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
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyText1
                                        .color,
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
                                  widget.parent.widget.showArchivedChats
                                      ? Icons.restore_from_trash
                                      : Icons.delete,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyText1
                                      .color,
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
            if (snapshot.hasData ||
                widget.parent.widget.showArchivedChats ||
                widget.parent.chats.isNotEmpty) {
              widget.parent.sortChats();
              if (widget.parent.chats.isEmpty) {
                return Center(
                  child: Container(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Text(
                      "You have no chats :(",
                      style: Theme.of(context).textTheme.subtitle1,
                    ),
                  ),
                );
              }

              return ListView.builder(
                physics: ThemeSwitcher.getScrollPhysics(),
                itemBuilder: (context, index) {
                  if (!widget.parent.widget.showArchivedChats &&
                      widget.parent.chats[index].isArchived) return Container();
                  if (widget.parent.widget.showArchivedChats &&
                      !widget.parent.chats[index].isArchived)
                    return Container();
                  return ConversationTile(
                    key: Key(widget.parent.chats[index].guid.toString()),
                    chat: widget.parent.chats[index],
                    inSelectMode: selected.isNotEmpty,
                    selected: selected,
                    onSelect: (bool selected) {
                      if (selected) {
                        this.selected.add(widget.parent.chats[index]);
                        setState(() {});
                      } else {
                        this.selected.removeWhere((element) =>
                            element.guid == widget.parent.chats[index].guid);
                        setState(() {});
                      }
                    },
                  );
                },
                itemCount: widget.parent.chats?.length ?? 0,
              );
            } else {
              return Container();
            }
          },
        ),
        floatingActionButton:
            selected.isEmpty ? widget.parent.buildFloatinActionButton() : null,
      ),
    );
  }
}
