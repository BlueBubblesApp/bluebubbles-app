import 'dart:ui';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';

import './conversation_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../helpers/hex_color.dart';
import '../settings/settings_panel.dart';

class ConversationList extends StatefulWidget {
  ConversationList({Key key}) : super(key: key);

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  ScrollController _scrollController;
  Color _theme;
  List<Chat> _chats = <Chat>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _theme = Colors.transparent;
    });
  }

  @override
  void initState() {
    super.initState();
    ChatBloc().chatStream.listen((List<Chat> chats) {
      _chats = chats;
    });
    ChatBloc().getChats();

    _scrollController = ScrollController()
      ..addListener(
        () => !_isAppBarExpanded
            ? _theme != Colors.transparent
                ? setState(() {
                    _theme = Colors.transparent;
                  })
                : {}
            : _theme != Theme.of(context).accentColor.withOpacity(0.5)
                ? setState(() {
                    _theme = Theme.of(context).accentColor.withOpacity(0.5);
                  })
                : {},
      );
  }

  bool get _isAppBarExpanded {
    return _scrollController.hasClients &&
        _scrollController.offset > (125 - kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size(
            MediaQuery.of(context).size.width,
            40,
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AnimatedCrossFade(
                crossFadeState: _theme == Colors.transparent
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: Duration(milliseconds: 250),
                secondChild: AppBar(
                  elevation: 0,
                  backgroundColor: _theme,
                  centerTitle: true,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Text(
                        "Messages",
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                    ],
                  ),
                ),
                firstChild: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        backgroundColor: Theme.of(context).backgroundColor,
        extendBodyBehindAppBar: true,
        body: CustomScrollView(
          controller: _scrollController,
          physics:
              AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: <Widget>[
            SliverAppBar(
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
                    Container(
                      height: 20,
                    ),
                    Container(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Spacer(
                            flex: 5,
                          ),
                          Container(
                            child: Text(
                              "Messages",
                              style: Theme.of(context).textTheme.headline1,
                            ),
                          ),
                          Spacer(
                            flex: 25,
                          ),
                          ButtonTheme(
                            minWidth: 20,
                            height: 20,
                            child: FlatButton(
                              padding: EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                              color: Theme.of(context).accentColor,
                              onPressed: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
                                    builder: (BuildContext context) {
                                      return SettingsPanel();
                                    },
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.more_horiz,
                                color: Colors.blue.withOpacity(0.75),
                                size: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                            ),
                          ),
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
              stream: ChatBloc().tileStream,
              builder: (BuildContext context,
                  AsyncSnapshot<Map<String, Map<String, dynamic>>> snapshot) {
                if (snapshot.hasData) {
                  // debugPrint(snapshot.data.toString());
                  _chats.sort((a, b) {
                    return -snapshot.data[a.guid]["actualDate"]
                        .compareTo(snapshot.data[b.guid]["actualDate"]);
                  });
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (!snapshot.data.containsKey(_chats[index].guid))
                          return Container();
                        return ConversationTile(
                            key: Key(_chats[index].guid.toString()),
                            chat: _chats[index],
                            title: snapshot.data[_chats[index].guid]["title"],
                            subtitle: snapshot.data[_chats[index].guid]
                                ["subtitle"],
                            date: snapshot.data[_chats[index].guid]["date"],
                            hasNewMessage: snapshot.data[_chats[index].guid]
                                ["hasNotification"]);
                      },
                      childCount: _chats.length,
                    ),
                  );
                } else {
                  return SliverToBoxAdapter(
                    child: Container(),
                  );
                }
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blue,
            child: Icon(Icons.message, color: Colors.white, size: 25),
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return NewChatCreator(
                      isCreator: true,
                    );
                  },
                ),
              );
            }),
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    debugPrint("disposed");
    super.dispose();
  }
}
