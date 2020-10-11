import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/new_message_loader.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/layouts/widgets/send_widget.dart';
import 'package:video_player/video_player.dart';

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
  Future<LoadMessageResult> loader;
  bool reachedTopOfChat = false;
  List<Message> _messages = <Message>[];
  GlobalKey<SliverAnimatedListState> _listKey;
  final Duration animationDuration = Duration(milliseconds: 400);
  OverlayEntry entry;
  List<String> sentMessages = <String>[];
  Map<String, SavedAttachmentData> attachments = Map();
  bool initializedList = false;
  double timeStampOffset = 0;
  Map<String, VideoPlayerController> currentPlayingVideo;
  List<VideoPlayerController> controllersToDispose = [];

  List<Attachment> allAttachments = [];

  @override
  void initState() {
    super.initState();
    widget.messageBloc.stream.listen(handleNewMessage);
    updateAllAttachments();
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

  Future<void> updateAllAttachments() async {
    allAttachments = await Chat.getAttachments(widget.messageBloc.currentChat);
    setState(() {});
  }

  @override
  void dispose() {
    if (currentPlayingVideo != null && currentPlayingVideo.length > 0) {
      currentPlayingVideo.values.forEach((element) {
        element.dispose();
      });
    }
    if (entry != null) entry.remove();
    super.dispose();
  }

  void handleNewMessage(MessageBlocEvent event) async {
    if (event.type == MessageBlocEventType.insert) {
      getAttachmentsForMessage(event.message);
      if (event.outGoing) {
        sentMessages.add(event.message.guid);
        Future.delayed(Duration(milliseconds: 500), () {
          sentMessages.removeWhere((element) => element == event.message.guid);
          _listKey.currentState.setState(() {});
        });
        Navigator.of(context).push(
          SendPageBuilder(
            builder: (context) {
              return SendWidget(
                text: event.message.text,
                tag: "first",
              );
            },
          ),
        );
      }

      _messages = event.messages;
      if (_listKey != null && _listKey.currentState != null) {
        _listKey.currentState.insertItem(
          event.index != null ? event.index : 0,
          duration:
              event.outGoing ? Duration(milliseconds: 500) : animationDuration,
        );
      }
    } else if (event.type == MessageBlocEventType.update) {
      if (attachments.containsKey(event.oldGuid)) {
        Message messageWithROWID =
            await Message.findOne({"guid": event.message.guid});
        List<Attachment> updatedAttachments =
            await Message.getAttachments(messageWithROWID);
        SavedAttachmentData data = attachments.remove(event.oldGuid);
        data.attachments = updatedAttachments;
        attachments[event.message.guid] = data;
      }
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].guid == event.oldGuid) {
          _messages[i] = event.message;
          if (this.mounted) setState(() {});
          break;
        }
      }
    } else if (event.type == MessageBlocEventType.remove) {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].guid == event.remove) {
          _messages.removeAt(i);
          _listKey.currentState
              .removeItem(i, (context, animation) => Container());
        }
      }
    } else {
      int originalMessageLength = _messages.length;
      _messages = event.messages;
      _messages.forEach((message) => getAttachmentsForMessage(message));
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
    updateAllAttachments();
  }

  @override
  Widget build(BuildContext context) {
    controllersToDispose.forEach((element) {
      element.dispose();
    });
    controllersToDispose = [];

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
                    if (index == _messages.length) {
                      if (loader == null && !reachedTopOfChat) {
                        loader = widget.messageBloc
                            .loadMessageChunk(_messages.length);
                        loader.then((val) {
                          if (val == LoadMessageResult.FAILED_TO_RETREIVE) {
                            loader = widget.messageBloc
                                .loadMessageChunk(_messages.length);
                          } else if (val ==
                              LoadMessageResult.RETREIVED_NO_MESSAGES) {
                            debugPrint("Reached the top of the chat");
                            reachedTopOfChat = true;
                            loader = null;
                          } else {
                            loader = null;
                          }
                          setState(() {});
                        });
                      }

                      return NewMessageLoader(
                        messageBloc: widget.messageBloc,
                        offset: _messages.length,
                        loader: loader,
                      );
                    } else if (index > _messages.length) {
                      return Container();
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
                            showHero: index == 0 &&
                                _messages[index].originalROWID == null,
                            currentPlayingVideo: currentPlayingVideo,
                            changeCurrentPlayingVideo:
                                (Map<String, VideoPlayerController> video) {
                              if (currentPlayingVideo != null &&
                                  currentPlayingVideo.length > 0) {
                                currentPlayingVideo.values.forEach((element) {
                                  controllersToDispose.add(element);
                                  element = null;
                                });
                              }
                              if (this.mounted)
                                setState(() {
                                  currentPlayingVideo = video;
                                });
                            },
                            allAttachments: allAttachments,
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
