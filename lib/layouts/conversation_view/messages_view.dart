import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MessageView extends StatefulWidget {
  final MessageBloc messageBloc;
  final bool showHandle;
  final LayerLink layerLink;
  MessageView({
    Key key,
    this.messageBloc,
    this.showHandle,
    this.layerLink,
  }) : super(key: key);

  @override
  _MessageViewState createState() => _MessageViewState();
}

class _MessageViewState extends State<MessageView> {
  Future loader;
  List<Message> _messages = <Message>[];
  final GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();
  final Duration animationDuration = Duration(milliseconds: 400);
  OverlayEntry entry;

  @override
  void initState() {
    super.initState();
    _messages = widget.messageBloc.messages;
    debugPrint("initial messages is " + _messages.length.toString());
    widget.messageBloc.stream.listen((event) {
      if (event["insert"] != null) {
        _messages = event["messages"];
        if (_listKey.currentState != null) {
          _listKey.currentState.insertItem(
              event.containsKey("index") ? event["index"] : 0,
              duration: animationDuration);
        }
      } else {
        int originalMessageLength = _messages.length;
        _messages = event["messages"];

        for (int i = originalMessageLength; i < _messages.length; i++) {
          if (_listKey.currentState != null)
            _listKey.currentState.insertItem(i, duration: animationDuration);
        }
        if (_listKey.currentState != null)
          _listKey.currentState.setState(() {});
      }
    });
    widget.messageBloc.getMessages();
  }

  @override
  void dispose() {
    if (entry != null) entry.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      reverse: true,
      physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: <Widget>[
        SliverAnimatedList(
          initialItemCount: _messages.length,
          key: _listKey,
          itemBuilder:
              (BuildContext context, int index, Animation<double> animation) {
            if (index == _messages.length) {
              if (loader == null) {
                loader = widget.messageBloc.loadMessageChunk(_messages.length);
                loader.whenComplete(() => loader = null);
              }
              return NewMessageLoader(
                messageBloc: widget.messageBloc,
                offset: _messages.length,
                loader: loader,
              );
            }

            Message olderMessage;
            Message newerMessage;
            if (index + 1 >= 0 && index + 1 < _messages.length) {
              olderMessage = _messages[index + 1];
            }
            if (index - 1 >= 0 && index - 1 < _messages.length) {
              newerMessage = _messages[index - 1];
            }
            List<Message> reactions = <Message>[];
            if (widget.messageBloc.reactions
                .containsKey(_messages[index].guid)) {
              reactions.addAll(
                widget.messageBloc.reactions[_messages[index].guid],
              );
            }

            Widget messageWidget = MessageWidget(
              key: Key(_messages[index].guid),
              fromSelf: _messages[index].isFromMe,
              message: _messages[index],
              olderMessage: olderMessage,
              newerMessage: newerMessage,
              reactions: reactions,
              showHandle: widget.showHandle,
            );

            if (_messages[index].isFromMe) {
              if (index == 0) {
                return Hero(
                  tag: "first",
                  child: Material(
                    type: MaterialType.transparency,
                    child: messageWidget,
                  ),
                );
              } else {
                return messageWidget;
              }
            } else {
              return SlideTransition(
                position: animation.drive(
                    Tween(begin: Offset(0.0, 1), end: Offset(0.0, 0.0))
                        .chain(CurveTween(curve: Curves.easeInOut))),
                child: FadeTransition(
                  opacity: animation,
                  child: messageWidget,
                ),
              );
            }
          },
        ),
      ],
    );
    // return StreamBuilder(
    //   stream: widget.messageBloc.stream,
    //   builder: (BuildContext context, AsyncSnapshot<List<Message>> snapshot) {
    //     List<Message> _messages = <Message>[];
    //     if (snapshot.hasData) {
    //       _messages = snapshot.data;
    //     } else {
    //       _messages = widget.messageBloc.messages;
    //     }

    //     return ListView.builder(
    //       reverse: true,
    //       physics:
    //           AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
    //       itemCount: _messages.length + 1,
    //       itemBuilder: (BuildContext context, int index) {
    //         if (index == _messages.length) {
    //           if (loader == null) {
    //             loader = widget.messageBloc.loadMessageChunk(_messages.length);
    //             loader.whenComplete(() => loader = null);
    //           }
    //           return NewMessageLoader(
    //             messageBloc: widget.messageBloc,
    //             offset: _messages.length,
    //             loader: loader,
    //           );
    //         }

    //         Message olderMessage;
    //         Message newerMessage;
    //         if (index + 1 >= 0 && index + 1 < _messages.length) {
    //           olderMessage = _messages[index + 1];
    //         }
    //         if (index - 1 >= 0 && index - 1 < _messages.length) {
    //           newerMessage = _messages[index - 1];
    //         }
    //         List<Message> reactions = <Message>[];
    //         if (widget.messageBloc.reactions
    //             .containsKey(_messages[index].guid)) {
    //           reactions.addAll(
    //             widget.messageBloc.reactions[_messages[index].guid],
    //           );
    //         }

    //         return MessageWidget(
    //           key: Key(_messages[index].guid),
    //           fromSelf: _messages[index].isFromMe,
    //           message: _messages[index],
    //           olderMessage: olderMessage,
    //           newerMessage: newerMessage,
    //           reactions: reactions,
    //           showHandle: widget.showHandle,
    //           bloc: widget.messageBloc,
    //         );
    //       },
    //     );
    //   },
    // );
  }
}

class NewMessageLoader extends StatefulWidget {
  final MessageBloc messageBloc;
  final int offset;
  final Future loader;
  NewMessageLoader({
    Key key,
    this.messageBloc,
    this.offset,
    this.loader,
  }) : super(key: key);

  @override
  _NewMessageLoaderState createState() => _NewMessageLoaderState();
}

class _NewMessageLoaderState extends State<NewMessageLoader> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: widget.loader,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Container();
        }
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Loading more messages...",
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoActivityIndicator(
                animating: true,
                radius: 15,
              ),
            ),
          ],
        );
      },
    );
  }
}
