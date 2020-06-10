import 'dart:ui';

import 'package:bluebubble_messages/blocs/chat_bloc.dart';
import 'package:bluebubble_messages/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/notification_manager.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';

import './conversation_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../helpers/hex_color.dart';
import '../settings/settings_panel.dart';
import '../../socket_manager.dart';

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
            : _theme != HexColor('26262a').withOpacity(0.5)
                ? setState(() {
                    _theme = HexColor('26262a').withOpacity(0.5);
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
            60,
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
                  backgroundColor: _theme,
                  centerTitle: true,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Text(
                        "Messages",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                firstChild: AppBar(
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        backgroundColor: Colors.black,
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
              expandedHeight: 120,
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
                            flex: 10,
                          ),
                          Container(
                            child: Text("Messages"),
                          ),
                          Spacer(
                            flex: 25,
                          ),
                          ButtonTheme(
                            minWidth: 25,
                            height: 25,
                            child: RaisedButton(
                              padding: EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                              color: HexColor('26262a'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (BuildContext context) {
                                      return SettingsPanel();
                                    },
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.more_horiz,
                                color: Colors.blue,
                                size: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                            ),
                          ),
                          ButtonTheme(
                            minWidth: 25,
                            height: 25,
                            child: RaisedButton(
                              padding: EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                              color: Colors.blue,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (BuildContext context) {
                                      return NewChatCreator(
                                        isCreator: true,
                                      );
                                    },
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.message,
                                color: Colors.white,
                                size: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                            ),
                          ),
                          Spacer(
                            flex: 5,
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      color: HexColor("26262a"),
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
                              ["hasNotification"],
                          messageBloc: snapshot.data[_chats[index].guid]
                              ["bloc"],
                        );
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
          onPressed: () async {
            await ChatBloc().getChats();
            await NewMessageManager().updateWithMessage(null, null);
          },
        ),
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
