import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/managers/theme_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/settings.dart';
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
  ScrollController _scrollController;
  List<Chat> _chats = <Chat>[];
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
        _chats = chats;
        if (this.mounted) setState(() {});
      });

      ChatBloc().refreshChats();
    } else {
      ChatBloc().archivedChatStream.listen((List<Chat> chats) {
        _chats = chats;
        if (this.mounted) setState(() {});
      });
      _chats = ChatBloc().archivedChats;
    }

    colorfulAvatars = SettingsManager().settings.colorfulAvatars;
    SettingsManager().stream.listen((Settings newSettings) {
      if (newSettings.colorfulAvatars != colorfulAvatars && this.mounted) {
        setState(() {
          colorfulAvatars = newSettings.colorfulAvatars;
        });
      }
    });

    _scrollController = ScrollController()..addListener(scrollListener);

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
    return _scrollController != null &&
        _scrollController.hasClients &&
        _scrollController.offset > (125 - kToolbarHeight);
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
          preferredSize: Size(
            MediaQuery.of(context).size.width,
            (model == "pixel") ? 20 : 40,
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: StreamBuilder<Color>(
                stream: headerColorStream.stream,
                builder: (context, snapshot) {
                  return AnimatedCrossFade(
                    crossFadeState: theme == Colors.transparent
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: Duration(milliseconds: 250),
                    secondChild: AppBar(
                      iconTheme:
                          IconThemeData(color: Theme.of(context).primaryColor),
                      elevation: 0,
                      backgroundColor: theme,
                      centerTitle: true,
                      brightness: this.brightness,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Text(
                            widget.showArchivedChats ? "Archive" : "Messages",
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                        ],
                      ),
                    ),
                    firstChild: AppBar(
                      leading: new Container(),
                      elevation: 0,
                      brightness: this.brightness,
                      backgroundColor: Theme.of(context).backgroundColor,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        backgroundColor: Theme.of(context).backgroundColor,
        extendBodyBehindAppBar: true,
        body: CustomScrollView(
          controller: _scrollController,
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
                              widget.showArchivedChats ? "Archive" : "Messages",
                              style: Theme.of(context).textTheme.headline1,
                            ),
                          ),
                          Spacer(
                            flex: 25,
                          ),
                          !widget.showArchivedChats
                              ? PopupMenuButton(
                                  color: Theme.of(context).accentColor,
                                  onSelected: (value) {
                                    if (value == 0) {
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder: (context) =>
                                              ConversationList(
                                            showArchivedChats: true,
                                          ),
                                        ),
                                      );
                                    } else if (value == 1) {
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
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
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1,
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 1,
                                        child: Text(
                                          'Settings',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyText1,
                                        ),
                                      ),
                                    ];
                                  },
                                  child: Container(
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
                                )
                              : Container(),
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
            StreamBuilder(
              stream: ChatBloc().chatStream,
              builder:
                  (BuildContext context, AsyncSnapshot<List<Chat>> snapshot) {
                if (snapshot.hasData || widget.showArchivedChats) {
                  _chats.sort((a, b) {
                    if (!a.isPinned && b.isPinned) return 1;
                    if (a.isPinned && !b.isPinned) return -1;
                    if (a.latestMessageDate == null &&
                        b.latestMessageDate == null) return 0;
                    if (a.latestMessageDate == null) return 1;
                    if (b.latestMessageDate == null) return -1;
                    return -a.latestMessageDate.compareTo(b.latestMessageDate);
                  });

                  if (_chats.isEmpty) {
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
                        if (!widget.showArchivedChats &&
                            _chats[index].isArchived) return Container();
                        if (widget.showArchivedChats &&
                            !_chats[index].isArchived) return Container();
                        return ConversationTile(
                          key: Key(_chats[index].guid.toString()),
                          chat: _chats[index],
                        );
                      },
                      childCount: _chats?.length ?? 0,
                    ),
                  );
                } else {
                  return SliverToBoxAdapter(child: Container());
                }
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Theme.of(context).primaryColor,
          child: Icon(Icons.message, color: Colors.white, size: 25),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (BuildContext context) {
                  return ConversationView(
                    isCreator: true,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    headerColorStream.close();

    // Remove the scroll listener from the state
    if (_scrollController != null)
      _scrollController.removeListener(scrollListener);
  }
}
