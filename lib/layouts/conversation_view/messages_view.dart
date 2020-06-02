import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/layouts/conversation_view/message_widget.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/material.dart';

class MessageView extends StatefulWidget {
  final MessageBloc messageBloc;
  MessageView({Key key, this.messageBloc}) : super(key: key);

  @override
  _MessageViewState createState() => _MessageViewState();
}

class _MessageViewState extends State<MessageView> {
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
            if (index == 0) {
              return SizedBox(
                height: 80,
              );
            }

            Message olderMessage;
            Message newerMessage;
            if (index >= 0 && index < _messages.length) {
              olderMessage = _messages[index];
            }
            if (index - 2 >= 0 && index - 2 < _messages.length) {
              newerMessage = _messages[index - 2];
            }

            return MessageWidget(
                key: Key(_messages[index - 1].guid),
                fromSelf: _messages[index - 1].isFromMe,
                message: _messages[index - 1],
                olderMessage: olderMessage,
                newerMessage: newerMessage);
          },
        );
      },
    );
  }
}
