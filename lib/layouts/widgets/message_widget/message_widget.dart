import 'dart:io';
import 'dart:ui';

import 'package:android_intent/android_intent.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/attachment_helper.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
import 'package:video_player/video_player.dart';

import '../../../helpers/hex_color.dart';
import '../../../helpers/utils.dart';
import '../../../repository/models/message.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({
    Key key,
    this.fromSelf,
    this.message,
    this.olderMessage,
    this.newerMessage,
    this.reactions,
    this.showHandle,
    this.bloc,
  }) : super(key: key);

  final fromSelf;
  final Message message;
  final Message newerMessage;
  final Message olderMessage;
  final List<Message> reactions;
  final bool showHandle;
  final MessageBloc bloc;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> {
  // List<Attachment> attachments = <Attachment>[];
  String body;
  bool showTail = true;
  final String like = "like";
  final String love = "love";
  final String dislike = "dislike";
  final String question = "question";
  final String emphasize = "emphasize";
  final String laugh = "laugh";
  Map<String, List<Message>> reactions = new Map();
  Widget blurredImage;

  FlickManager _flickManager;

  bool play = false;
  double progress = 0.0;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    reactions[like] = [];
    reactions[love] = [];
    reactions[dislike] = [];
    reactions[question] = [];
    reactions[emphasize] = [];
    reactions[laugh] = [];

    widget.reactions.forEach((reaction) {
      reactions[reaction.associatedMessageType].add(reaction);
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.newerMessage != null) {
      showTail = withinTimeThreshold(widget.message, widget.newerMessage,
              threshold: 1) ||
          !sameSender(widget.message, widget.newerMessage);
    }
  }

  bool withinTimeThreshold(Message first, Message second, {threshold: 5}) {
    if (first == null || second == null) return false;
    return first.dateCreated.difference(second.dateCreated).inMinutes >
        threshold;
  }

  List<Widget> _buildContent() {
    List<Widget> content = <Widget>[];

    if (widget.bloc.attachments.containsKey(widget.message.guid)) {
      debugPrint("contains key");
      content.addAll(widget.bloc.attachments[widget.message.guid]);
    }

    if (!isEmptyString(widget.message.text) &&
        widget.bloc.attachments.containsKey(widget.message.guid)) {
      content.add(Padding(
        padding: EdgeInsets.only(left: 20, right: 10),
        child: Text(
          widget.message.text,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ));
    } else if (!isEmptyString(widget.message.text) &&
        !widget.bloc.attachments.containsKey(widget.message.guid)) {
      content.add(
        Text(
          widget.message.text,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }

    // Add spacing to items in a message
    List<Widget> output = [];
    for (int i = 0; i < content.length; i++) {
      output.add(content[i]);
      if (i != content.length - 1) {
        output.add(Container(height: 8.0));
      }
    }

    return output;
  }

  Widget _buildTimeStamp() {
    if (widget.olderMessage != null &&
        withinTimeThreshold(widget.message, widget.olderMessage,
            threshold: 30)) {
      DateTime timeOfolderMessage = widget.olderMessage.dateCreated;
      String time = new DateFormat.jm().format(timeOfolderMessage);
      String date;
      if (widget.olderMessage.dateCreated.isToday()) {
        date = "Today";
      } else if (widget.olderMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${timeOfolderMessage.month.toString()}/${timeOfolderMessage.day.toString()}/${timeOfolderMessage.year.toString()}";
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "$date, $time",
              style: TextStyle(
                color: Colors.white,
              ),
            )
          ],
        ),
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fromSelf) {
      List<Widget> content = _buildContent();
      return SentMessage(
        content: content,
        deliveredReceipt: _buildDelieveredReceipt(),
        message: widget.message,
        overlayEntry: _createOverlayEntry(),
        showTail: showTail,
      );
    } else {
      return ReceivedMessage(
          timeStamp: _buildTimeStamp(),
          reactions: _buildReactions(),
          content: _buildContent(),
          showTail: showTail,
          olderMessage: widget.olderMessage,
          message: widget.message,
          overlayEntry: _createOverlayEntry(),
          showHandle: widget.showHandle);
    }
  }

  Widget _buildDelieveredReceipt() {
    if (!showTail) return Container();
    if (widget.message.dateRead == null && widget.message.dateDelivered == null)
      return Container();

    String text = "Delivered";
    if (widget.message.dateRead != null) text = "Read";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            text,
            style: TextStyle(
                color: Colors.white.withAlpha(80),
                fontWeight: FontWeight.w500,
                fontSize: 11),
          )
        ],
      ),
    );
  }

  Widget _buildReactions() {
    if (widget.reactions.length == 0) return Container();
    List<Widget> reactionIcon = <Widget>[];
    reactions.keys.forEach((String key) {
      if (reactions[key].length != 0) {
        reactionIcon.add(
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              'assets/reactions/$key-black.svg',
              color: key == love ? Colors.pink : Colors.white,
            ),
          ),
        );
      }
    });
    return Stack(
      alignment: widget.message.isFromMe
          ? Alignment.bottomRight
          : Alignment.bottomLeft,
      children: <Widget>[
        for (int i = 0; i < reactionIcon.length; i++)
          Padding(
            padding: EdgeInsets.fromLTRB(i.toDouble() * 20.0, 0, 0, 0),
            child: Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: HexColor('26262a'),
                  boxShadow: [
                    new BoxShadow(
                      blurRadius: 5.0,
                      offset:
                          Offset(3.0 * (widget.message.isFromMe ? 1 : -1), 0.0),
                      color: Colors.black,
                    )
                  ]),
              child: reactionIcon[i],
            ),
          ),
      ],
    );
  }

  OverlayEntry _createOverlayEntry() {
    List<Widget> reactioners = <Widget>[];
    reactions.keys.forEach(
      (element) {
        reactions[element].forEach(
          (reaction) async {
            if (reaction.handle != null) {
              reactioners.add(
                Text(
                  getContactTitle(
                      ContactManager().contacts, reaction.handle.address),
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              );
            }
          },
        );
      },
    );

    OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  debugPrint("remove entry");
                  entry.remove();
                },
                child: Container(
                  color: Colors.black.withAlpha(200),
                  child: Column(
                    children: <Widget>[
                      Spacer(
                        flex: 3,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 120,
                            width: MediaQuery.of(context).size.width * 9 / 5,
                            color: HexColor('26262a').withAlpha(200),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: reactioners,
                            ),
                          ),
                        ),
                      ),
                      Spacer(
                        flex: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return entry;
  }

  @override
  void dispose() {
    if (_flickManager != null) _flickManager.dispose();
    super.dispose();
  }
}
