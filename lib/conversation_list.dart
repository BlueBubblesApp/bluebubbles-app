import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'conversation_view.dart';

class ConversationList extends StatefulWidget {
  ConversationList({Key key}) : super(key: key);
  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            stretch: true,
            onStretchTrigger: () {},
            expandedHeight: 100,
            backgroundColor: Colors.transparent,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: <StretchMode>[StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
              ),
              centerTitle: true,
              title: BackdropFilter(
                child: Text("Messages"),
                filter: ImageFilter.blur(
                  sigmaX: 10,
                  sigmaY: 10,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Material(
                  color: Colors.black,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (BuildContext context) {
                            return ConversationView();
                          },
                        ),
                      );
                    },
                    child: ListTile(
                      title: Text(
                        "Some chat",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      leading: Icon(
                        Icons.account_circle,
                        color: Colors.white,
                      ),
                      trailing: Container(
                        width: 70,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 15,
                            ),
                            Text(
                              "4:20",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
