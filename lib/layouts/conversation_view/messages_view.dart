import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubble_messages/repository/models/handle.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MessageView extends StatefulWidget {
  final MessageBloc messageBloc;
  MessageView({Key key, this.messageBloc}) : super(key: key);

  @override
  _MessageViewState createState() => _MessageViewState();
}

class _MessageViewState extends State<MessageView> {
  Future loader;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.messageBloc.stream,
      builder: (BuildContext context, AsyncSnapshot<List<Message>> snapshot) {
        List<Message> _messages = <Message>[];
        if (snapshot.hasData) {
          _messages = snapshot.data;
        } else {
          _messages = widget.messageBloc.messages;
        }

        return ListView.builder(
          reverse: true,
          physics:
              AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          itemCount: _messages.length + 1,
          itemBuilder: (BuildContext context, int index) {
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
              olderMessage = _messages[index];
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

            return MessageWidget(
              key: Key(_messages[index].guid),
              fromSelf: _messages[index].isFromMe,
              message: _messages[index],
              olderMessage: olderMessage,
              newerMessage: newerMessage,
              reactions: reactions,
            );
          },
        );
      },
    );
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
