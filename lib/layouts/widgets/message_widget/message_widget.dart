import 'dart:io';
import 'dart:ui';

import 'package:android_intent/android_intent.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/attachment_helper.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/contact_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/image_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/loaction_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_file.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/message_content.dart';
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
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:latlong/latlong.dart';
import 'package:link_previewer/link_previewer.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher.dart';
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
    this.customContent,
    this.shouldFadeIn,
    this.isFirstSentMessage,
    this.attachments,
  }) : super(key: key);

  final fromSelf;
  final Message message;
  final Message newerMessage;
  final Message olderMessage;
  final List<Message> reactions;
  final bool showHandle;
  final bool shouldFadeIn;
  final bool isFirstSentMessage;
  final Widget attachments;

  final List<Widget> customContent;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> {
  List<Attachment> attachments = <Attachment>[];
  bool showTail = true;
  final String like = "like";
  final String love = "love";
  final String dislike = "dislike";
  final String question = "question";
  final String emphasize = "emphasize";
  final String laugh = "laugh";
  Map<String, List<Message>> reactions = new Map();
  Widget blurredImage;

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
    return second.dateCreated.difference(first.dateCreated).inMinutes.abs() >
        threshold;
  }

  Map<String, String> _buildTimeStamp(BuildContext context) {
    if (widget.newerMessage != null &&
        (!isEmptyString(widget.message.text) ||
            widget.message.hasAttachments) &&
        withinTimeThreshold(widget.message, widget.newerMessage,
            threshold: 30)) {
      DateTime timeOfnewerMessage = widget.newerMessage.dateCreated;
      String time = new DateFormat.jm().format(timeOfnewerMessage);
      String date;
      if (widget.newerMessage.dateCreated.isToday()) {
        date = "Today";
      } else if (widget.newerMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${timeOfnewerMessage.month.toString()}/${timeOfnewerMessage.day.toString()}/${timeOfnewerMessage.year.toString()}";
      }
      return {"date": date, "time": time};
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message != null &&
        isEmptyString(widget.message.text) &&
        !widget.message.hasAttachments) {
      return GroupEvent(
        message: widget.message,
      );
    } else if (widget.fromSelf) {
      return SentMessage(
        timeStamp: _buildTimeStamp(context),
        message: widget.message,
        showDeliveredReceipt:
            widget.customContent == null && widget.isFirstSentMessage,
        overlayEntry: _createOverlayEntry(context),
        showTail: showTail,
        limited: widget.customContent == null,
        shouldFadeIn: widget.shouldFadeIn,
        customContent: widget.customContent,
        isFromMe: widget.fromSelf,
        attachments: widget.attachments,
      );
    } else {
      return ReceivedMessage(
        timeStamp: _buildTimeStamp(context),
        reactions: _buildReactions(),
        showTail: showTail,
        olderMessage: widget.olderMessage,
        message: widget.message,
        overlayEntry: _createOverlayEntry(context),
        showHandle: widget.showHandle,
        customContent: widget.customContent,
        isFromMe: widget.fromSelf,
        attachments: widget.attachments,
      );
    }
  }

  Widget _buildReactions() {
    if (widget.reactions.length == 0) return Container();
    List<Widget> reactionIcon = <Widget>[];
    reactions.keys.forEach(
      (String key) {
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
      },
    );
    // return Stack(
    //   alignment: widget.message.isFromMe
    //       ? Alignment.bottomRight
    //       : Alignment.bottomLeft,
    //   children: <Widget>[
    //     for (int i = 0; i < reactionIcon.length; i++)
    //       Padding(
    //         padding: EdgeInsets.fromLTRB(i.toDouble() * 20.0, 0, 0, 0),
    //         child: Container(
    //           height: 30,
    //           width: 30,
    //           decoration: BoxDecoration(
    //             borderRadius: BorderRadius.circular(100),
    //             color: HexColor('26262a'),
    //             boxShadow: [
    //               new BoxShadow(
    //                 blurRadius: 5.0,
    //                 offset:
    //                     Offset(3.0 * (widget.message.isFromMe ? 1 : -1), 0.0),
    //                 color: Colors.black,
    //               )
    //             ],
    //           ),
    //           child: reactionIcon[i],
    //         ),
    //       ),
    //   ],
    // );
    return Container();
  }

  OverlayEntry _createOverlayEntry(BuildContext context) {
    List<Widget> reactioners = <Widget>[];
    reactions.keys.forEach(
      (element) {
        List<Widget> reactionGroup = <Widget>[];
        List<String> names = [];
        reactions[element].forEach(
          (message) async {
            if (message.handle == null) return;

            String name = "You";
            if (!message.isFromMe) {
              name = getContactTitle(
                  ContactManager().contacts, message.handle.address);
            }

            names.add(name);
          },
        );

        if (reactions[element].length > 0) {
          reactionGroup.add(Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              'assets/reactions/$element-black.svg',
              height: 24.0,
              width: 24.0,
              color: element == love ? Colors.pink : Colors.white,
            ),
          ));

          reactionGroup.add(
            Text(
              names.join(", "),
              softWrap: true,
              style: Theme.of(context).textTheme.bodyText1,
            ),
          );

          reactioners.add(Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: reactionGroup));
        }
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
}
