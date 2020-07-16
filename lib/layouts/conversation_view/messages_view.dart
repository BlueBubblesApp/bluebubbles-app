import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bluebubble_messages/layouts/widgets/send_widget.dart';
import 'package:metadata_fetch/metadata_fetch.dart';

class MessageView extends StatefulWidget {
  final MessageBloc messageBloc;
  final bool showHandle;
  MessageView({
    Key key,
    this.messageBloc,
    this.showHandle,
  }) : super(key: key);

  @override
  _MessageViewState createState() => _MessageViewState();
}

class _MessageViewState extends State<MessageView>
    with TickerProviderStateMixin {
  Future loader;
  List<Message> _messages = <Message>[];
  GlobalKey<SliverAnimatedListState> _listKey;
  final Duration animationDuration = Duration(milliseconds: 400);
  OverlayEntry entry;
  List<String> sentMessages = <String>[];
  Map<String, Widget> attachments = Map();
  Map<String, Future<List<Attachment>>> attachmentFutures = Map();
  Map<String, Map<String, dynamic>> attachmentResults = Map();
  bool initializedList = false;

  @override
  void initState() {
    super.initState();
    widget.messageBloc.stream.listen((event) {
      if (event["insert"] != null) {
        getAttachmentsForMessage(event["insert"]);
        // debugPrint(attachments.containsKey(event["insert"].guid).toString());
        if (event["sentFromThisClient"]) {
          sentMessages.add(event["insert"].guid);
          Future.delayed(Duration(milliseconds: 500), () {
            sentMessages
                .removeWhere((element) => element == event["insert"].guid);
            _listKey.currentState.setState(() {});
          });
          Navigator.of(context).push(
            SendPageBuilder(
              builder: (context) {
                return SendWidget(
                  text: event["insert"].text,
                  tag: "first",
                );
              },
            ),
          );
        }

        _messages = event["messages"].values.toList();
        if (_listKey.currentState != null) {
          _listKey.currentState.insertItem(
              event.containsKey("index") ? event["index"] : 0,
              duration: event["sentFromThisClient"]
                  ? Duration(milliseconds: 500)
                  : animationDuration);
        }
      } else if (event.containsKey("update") && event["update"] != null) {
        if (event.containsKey("oldGuid") &&
            event["oldGuid"] != null &&
            event["oldGuid"] != (event["update"] as Message).guid) {
          if (attachments.containsKey(event["oldGuid"]))
            attachments[(event["update"] as Message).guid] =
                attachments.remove(event["oldGuid"]);
          if (attachmentFutures.containsKey(event["oldGuid"]))
            attachmentFutures[(event["update"] as Message).guid] =
                attachmentFutures.remove(event["oldGuid"]);
          if (attachments.containsKey(event["oldGuid"]))
            attachmentFutures[(event["update"] as Message).guid] =
                attachmentFutures.remove(event["oldGuid"]);
        }
        _messages = event["messages"].values.toList();
        if (this.mounted) setState(() {});
        _listKey.currentState.setState(() {});
      } else {
        int originalMessageLength = _messages.length;
        _messages = event["messages"].values.toList();
        _messages.forEach((element) => getAttachmentsForMessage(element));
        initializedList = true;
        if (_listKey == null) _listKey = GlobalKey<SliverAnimatedListState>();

        if (originalMessageLength < _messages.length) {
          for (int i = originalMessageLength; i < _messages.length; i++) {
            if (_listKey.currentState != null)
              _listKey.currentState
                  .insertItem(i, duration: Duration(milliseconds: 0));
          }
        } else if (originalMessageLength > _messages.length) {
          for (int i = originalMessageLength; i >= _messages.length; i--) {
            if (_listKey.currentState != null)
              _listKey.currentState.removeItem(
                  i, (context, animation) => Container(),
                  duration: Duration(milliseconds: 0));
          }
        }
        if (_listKey.currentState != null)
          _listKey.currentState.setState(() {});
        if (this.mounted) setState(() {});
      }
    });

    widget.messageBloc.getMessages();
  }

  void getAttachmentsForMessage(Message message) {
    if (attachments.containsKey(message.guid)) return;
    if (message.hasAttachments) {
      debugPrint("getting attachments for new insert");
      attachmentFutures[message.guid] = Message.getAttachments(message);
      attachments[message.guid] = AnimatedSize(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        vsync: this,
        child: FutureBuilder(
          builder: (context, snapshot) {
            if (snapshot.hasData ||
                attachmentResults.containsKey(message.guid)) {
              if (!attachmentResults.containsKey(message.guid)) {
                attachmentResults[message.guid] = {
                  "attachments": snapshot.data
                };
              }
              return MessageAttachments(
                attachments: attachmentResults[message.guid]["attachments"],
                message: message,
                existingMetaData:
                    attachmentResults[message.guid].containsKey("urlMetaData")
                        ? attachmentResults[message.guid]["urlMetaData"]
                        : null,
                onFinishURLs: (Metadata data) {
                  attachmentResults[message.guid]["urlMetaData"] = data;
                },
              );
            } else {
              return Container();
            }
          },
          future: attachmentFutures[message.guid],
        ),
      );
      // setState(() {});
    }
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
        _listKey != null
            ? SliverAnimatedList(
                initialItemCount: _messages.length + 1,
                key: _listKey,
                itemBuilder: (BuildContext context, int index,
                    Animation<double> animation) {
                  if (index == _messages.length) {
                    if (loader == null) {
                      loader =
                          widget.messageBloc.loadMessageChunk(_messages.length);
                      loader.then((val) {
                        loader = null;
                      });
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

                  Widget messageWidget = MessageWidget(
                    key: Key(_messages[index].guid),
                    fromSelf: _messages[index].isFromMe,
                    message: _messages[index],
                    olderMessage: olderMessage,
                    newerMessage: newerMessage,
                    showHandle: widget.showHandle,
                    shouldFadeIn: sentMessages.contains(_messages[index].guid),
                    isFirstSentMessage: widget.messageBloc.firstSentMessage ==
                        _messages[index].guid,
                    attachments: attachments.containsKey(_messages[index].guid)
                        ? attachments[_messages[index].guid]
                        : Container(),
                    showHero: index == 0,
                  );

                  return SizeTransition(
                    axis: Axis.vertical,
                    sizeFactor: animation.drive(Tween(begin: 0.0, end: 1.0)
                        .chain(CurveTween(curve: Curves.easeInOut))),
                    child: SlideTransition(
                      position: animation.drive(
                          Tween(begin: Offset(0.0, 1), end: Offset(0.0, 0.0))
                              .chain(CurveTween(curve: Curves.easeInOut))),
                      child: FadeTransition(
                        opacity: animation,
                        child: messageWidget,
                      ),
                    ),
                  );
                },
              )
            : SliverToBoxAdapter(child: Container()),
        SliverPadding(
          padding: EdgeInsets.all(70),
        ),
      ],
    );
  }
}
