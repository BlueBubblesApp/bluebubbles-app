import 'dart:ui';

import './conversation_tile.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'hex_color.dart';
import 'settings.dart';
import 'settings_panel.dart';

class ConversationList extends StatefulWidget {
  final Function onPressed;
  final Settings settings;
  final Function saveSettings;
  final Function sendSocketMessage;
  final Function requestMessages;
  final List chats;

  ConversationList({
    Key key,
    this.onPressed,
    this.settings,
    this.saveSettings,
    this.sendSocketMessage,
    this.chats,
    this.requestMessages,
  }) : super(key: key);
  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  ScrollController _scrollController;
  Color _theme;

  @override
  void initState() {
    super.initState();

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
      _theme = Colors.transparent;
    });
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
                                    return SettingsPanel(
                                      settings: widget.settings,
                                      saveSettings: widget.saveSettings,
                                    );
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return ConversationTile(
                  key: Key(index.toString()),
                  data: widget.chats[index],
                  requestMessages: widget.requestMessages,
                );
              },
              childCount: widget.chats.length,
            ),
          )
        ],
      ),
    );
  }
}
