import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/layouts/widgets/send_widget.dart';

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
  Map<String, SavedAttachmentData> attachments = Map();
  // Map<String, Future<List<Attachment>>> attachmentFutures = Map();
  // Map<String, Map<String, dynamic>> attachmentResults = Map();
  bool initializedList = false;
  double timeStampOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.messageBloc.stream.listen((event) async {
      if (event["insert"] != null) {
        getAttachmentsForMessage(event["insert"]);
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
        if (_listKey != null && _listKey.currentState != null) {
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
          if (attachments.containsKey(event["oldGuid"])) {
            Message messageWithROWID = await Message.findOne(
                {"guid": (event["update"] as Message).guid});
            List<Attachment> updatedAttachments =
                await Message.getAttachments(messageWithROWID);
            SavedAttachmentData data = attachments.remove(event["oldGuid"]);
            data.attachments = updatedAttachments;
            attachments[(event["update"] as Message).guid] = data;
          }
        } else if (event.containsKey("remove") && event["remove"] != null) {
          for (int i = 0; i < _messages.length; i++) {
            if (_messages[i].guid == event["remove"]) {
              _messages = event["messages"].values.toList();
              _listKey.currentState
                  .removeItem(i, (context, animation) => Container());
            }
          }
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
            if (_listKey != null && _listKey.currentState != null)
              _listKey.currentState
                  .insertItem(i, duration: Duration(milliseconds: 0));
          }
        } else if (originalMessageLength > _messages.length) {
          for (int i = originalMessageLength; i >= _messages.length; i--) {
            if (_listKey != null && _listKey.currentState != null) {
              try {
                _listKey.currentState.removeItem(
                  i, (context, animation) => Container(),
                    duration: Duration(milliseconds: 0));
              } catch (ex) {
                debugPrint("Error removing item animation");
                debugPrint(ex.toString());
              }
            }
          }
        }
        if (_listKey != null && _listKey.currentState != null)
          _listKey.currentState.setState(() {});
        if (this.mounted) setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    if (_messages.length == 0) {
      widget.messageBloc.getMessages();
      setState(() {});
    }
  }

  void getAttachmentsForMessage(Message message) {
    if (attachments.containsKey(message.guid)) return;
    if (message.hasAttachments) {
      attachments[message.guid] = new SavedAttachmentData();
    }
  }

  @override
  void dispose() {
    if (entry != null) entry.remove();
    attachments.values.forEach((element) {
      element.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragStart: (details) {},
      onHorizontalDragUpdate: (details) {
        setState(() {
          timeStampOffset += details.delta.dx * 0.3;
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          timeStampOffset = 0;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          timeStampOffset = 0;
        });
      },
      child: CustomScrollView(
        reverse: true,
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: <Widget>[
          _listKey != null
              ? SliverAnimatedList(
                  initialItemCount: _messages.length + 1,
                  key: _listKey,
                  itemBuilder: (BuildContext context, int index,
                      Animation<double> animation) {
                    if (index >= _messages.length) {
                      if (loader == null) {
                        loader = widget.messageBloc
                            .loadMessageChunk(_messages.length);
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
                          child: MessageWidget(
                            key: Key(_messages[index].guid),
                            offset: timeStampOffset,
                            fromSelf: _messages[index].isFromMe,
                            message: _messages[index],
                            chat: widget.messageBloc.currentChat,
                            olderMessage: olderMessage,
                            newerMessage: newerMessage,
                            showHandle: widget.showHandle,
                            shouldFadeIn:
                                sentMessages.contains(_messages[index].guid),
                            isFirstSentMessage:
                                widget.messageBloc.firstSentMessage ==
                                    _messages[index].guid,
                            savedAttachmentData:
                                attachments.containsKey(_messages[index].guid)
                                    ? attachments[_messages[index].guid]
                                    : null,
                            showHero: index == 0,
                          ),
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
      ),
    );
  }
}
