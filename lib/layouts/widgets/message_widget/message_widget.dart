import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../helpers/utils.dart';
import '../../../repository/models/message.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({
    Key key,
    this.fromSelf,
    this.message,
    this.chat,
    this.olderMessage,
    this.newerMessage,
    this.showHandle,
    this.customContent,
    this.shouldFadeIn,
    this.isFirstSentMessage,
    this.showHero,
    this.savedAttachmentData,
    this.offset,
  }) : super(key: key);

  final fromSelf;
  final Message message;
  final Chat chat;
  final Message newerMessage;
  final Message olderMessage;
  final bool showHandle;
  final bool shouldFadeIn;
  final bool isFirstSentMessage;
  final bool showHero;
  final SavedAttachmentData savedAttachmentData;
  final double offset;

  final List<Widget> customContent;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> {
  List<Attachment> attachments = <Attachment>[];
  bool showTail = true;
  Widget blurredImage;

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
    if (widget.newerMessage != null) {
      showTail = withinTimeThreshold(widget.message, widget.newerMessage,
              threshold: 1) ||
          !sameSender(widget.message, widget.newerMessage) ||
          (widget.message.isFromMe &&
              widget.newerMessage.isFromMe &&
              widget.message.dateDelivered != null &&
              widget.newerMessage.dateDelivered == null);
    }
    if (widget.message != null &&
        isEmptyString(widget.message.text) &&
        !widget.message.hasAttachments) {
      return GroupEvent(
        message: widget.message,
      );
    } else if (widget.fromSelf) {
      return SentMessage(
        offset: widget.offset,
        timeStamp: _buildTimeStamp(context),
        message: widget.message,
        chat: widget.chat,
        showDeliveredReceipt:
            widget.customContent == null && widget.isFirstSentMessage,
        // overlayEntry: _createOverlayEntry(context),
        showTail: showTail,
        limited: widget.customContent == null,
        shouldFadeIn: widget.shouldFadeIn,
        customContent: widget.customContent,
        isFromMe: widget.fromSelf,
        attachments: widget.savedAttachmentData != null
            ? MessageAttachments(
                message: widget.message,
                savedAttachmentData: widget.savedAttachmentData)
            : Container(),
        showHero: widget.showHero,
      );
    } else {
      return ReceivedMessage(
        offset: widget.offset,
        timeStamp: _buildTimeStamp(context),
        showTail: showTail,
        olderMessage: widget.olderMessage,
        message: widget.message,
        // overlayEntry: _createOverlayEntry(context),
        showHandle: widget.showHandle,
        customContent: widget.customContent,
        isFromMe: widget.fromSelf,
        attachments: widget.savedAttachmentData != null
            ? MessageAttachments(
                message: widget.message,
                savedAttachmentData: widget.savedAttachmentData)
            : Container(),
      );
    }
  }
}
