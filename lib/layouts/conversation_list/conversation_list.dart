import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator.dart';
import 'package:bluebubbles/repository/models/chat.dart';

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
  Color _theme;
  List<Chat> _chats = <Chat>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _theme = Colors.transparent;
    });
  }

  void scrollListener() {
    return !_isAppBarExpanded
        ? _theme != Colors.transparent
            ? setState(() {
                _theme = Colors.transparent;
              })
            : {}
        : _theme != Theme.of(context).accentColor.withOpacity(0.5)
            ? setState(() {
                _theme = Theme.of(context).accentColor.withOpacity(0.5);
              })
            : {};
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

    _scrollController = ScrollController()..addListener(scrollListener);
  }

  bool get _isAppBarExpanded {
    return _scrollController != null &&
        _scrollController.hasClients &&
        _scrollController.offset > (125 - kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      widget.showArchivedChats ? "Archive" : "Messages",
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
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: <Widget>[
          SliverAppBar(
            leading: new Container(),
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
                                // shape: RoundedRectangleBorder(
                                //   borderRadius: BorderRadius.circular(40),
                                // ),
                                color: Theme.of(context).accentColor,
                                onSelected: (value) {
                                  if (value == 0) {
                                    Navigator.of(context).push(
                                      CupertinoPageRoute(
                                        builder: (context) => ConversationList(
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
                                    color: Colors.blue.withOpacity(0.75),
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
                  if (a.latestMessageDate == null &&
                      b.latestMessageDate == null) return 0;
                  if (a.latestMessageDate == null) return 1;
                  if (b.latestMessageDate == null) return -1;
                  return -a.latestMessageDate.compareTo(b.latestMessageDate);
                });

                if (_chats.length == 0) {
                  return SliverToBoxAdapter(
                      child: Center(
                          child: Container(
                              padding: EdgeInsets.only(top: 50.0),
                              child: Text("You have no chats :(",
                                  style:
                                      Theme.of(context).textTheme.subtitle1))));
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return ConversationTile(
                          key: Key(_chats[index].guid.toString()),
                          chat: _chats[index]);
                    },
                    childCount: _chats.length,
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
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();

    // Remove the scroll listener from the state
    if (_scrollController != null)
      _scrollController.removeListener(scrollListener);
  }
}
