import 'dart:ui';

import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:intl/intl.dart';

import './conversation_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'hex_color.dart';
import 'settings_panel.dart';
import 'singleton.dart';
import 'helpers/utils.dart';

class ConversationList extends StatefulWidget {
  ConversationList({Key key}) : super(key: key);

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  ScrollController _scrollController;
  Color _theme;
  Map<Chat, Map<String, String>> tileVals = new Map();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    updateChatVals();
    setState(() {
      _theme = Colors.transparent;
    });
  }

  @override
  void initState() {
    super.initState();
    Singleton().subscribe(() {
      updateChatVals();
    });

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

  void updateChatVals() async {
    for (int i = 0; i < Singleton().chats.length; i++) {
      Chat chat = Singleton().chats[i];
      String title = await chatTitle(chat);
      List<Message> messages = await Chat.getMessages(chat);
      messages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
      String subtitle = "";
      String date = "";
      if (messages.length > 0) {
        List<Attachment> attachments =
            await Message.getAttachments(messages.first);
        String text = messages.first.text.substring(attachments.length);
        if (text.length == 0 && attachments.length > 0) {
          text = "${attachments.length} attachments";
        }
        subtitle = text;

        Message lastMessage = messages.first;
        if (lastMessage.dateCreated.isToday()) {
          date = new DateFormat.jm().format(lastMessage.dateCreated);
        } else if (lastMessage.dateCreated.isYesterday()) {
          date = "Yesterday";
        } else {
          date =
              "${lastMessage.dateCreated.month.toString()}/${lastMessage.dateCreated.day.toString()}/${lastMessage.dateCreated.year.toString()}";
        }
      }

      Map<String, String> chatMap = {
        "title": title,
        "subtitle": subtitle,
        "date": date
      };
      if (tileVals.containsKey(chat)) {
        tileVals.remove(chat);
      }
      tileVals[chat] = chatMap;
      if (this.mounted &&
          tileVals.keys.length >= Singleton().chats.length &&
          i == Singleton().chats.length - 1) {
        setState(() {});
      }
    }
  }

  bool get _isAppBarExpanded {
    return _scrollController.hasClients &&
        _scrollController.offset > (125 - kToolbarHeight);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                          flex: 20,
                        ),
                        Container(
                          child: Text("Messages"),
                        ),
                        Spacer(
                          flex: 15,
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
                                CupertinoPageRoute(
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
                            onPressed: () {},
                            child: Icon(
                              Icons.message,
                              color: Colors.white,
                              size: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                          ),
                        ),
                        Spacer(
                          flex: 15,
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
          SliverToBoxAdapter(
            child: FutureBuilder(
              future: Singleton().setup(),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  // return ListView.builder(
                  //   itemBuilder: (BuildContext context, int index) {
                  //     return ConversationTile(
                  //       key: Key(index.toString()),
                  //       chat: Singleton().chats[index],
                  //     );
                  //   },
                  //   itemCount: Singleton().chats.length,
                  // );
                  return Container();
                } else {
                  return Column(
                    children: <Widget>[
                      SizedBox(
                        height: 3.5,
                        child: LinearProgressIndicator(),
                      ),
                      Container(
                        height: 20,
                      ),
                      Text(
                        "Setting things up, this make take a while...",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      )
                    ],
                  );
                }
              },
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (!tileVals.containsKey(Singleton().chats[index])) {
                  updateChatVals();
                }
                return ConversationTile(
                  key: Key(Singleton().chats[index].guid.toString()),
                  chat: Singleton().chats[index],
                  title: tileVals[Singleton().chats[index]]["title"],
                  subtitle: tileVals[Singleton().chats[index]]["subtitle"],
                  date: tileVals[Singleton().chats[index]]["date"],
                );
              },
              childCount: Singleton().chats.length,
            ),
          )
        ],
      ),
    );
  }
}
