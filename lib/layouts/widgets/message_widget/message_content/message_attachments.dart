import 'dart:io';

import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachment.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart' as p;

class MessageAttachments extends StatefulWidget {
  MessageAttachments({
    Key key,
    @required this.message,
    @required this.showTail,
    @required this.showHandle,
  }) : super(key: key);
  final Message message;
  final bool showTail;
  final bool showHandle;

  @override
  _MessageAttachmentsState createState() => _MessageAttachmentsState();
}

class _MessageAttachmentsState extends State<MessageAttachments>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    EdgeInsets padding = EdgeInsets.all(0.0);
    if (widget.message.hasReactions && widget.message.hasAttachments) {
      if (widget.message.isFromMe) {
        padding = EdgeInsets.only(
            top: 15.0,
            bottom: (widget.message.hasAttachments) ? 2.0 : 10.0,
            left: 12.0,
            right: 0.0);
      } else {
        padding = EdgeInsets.only(
            top: (widget.showHandle) ? 18.0 : 15.0,
            bottom: (widget.message.hasAttachments) ? 2.0 : 10.0,
            left: 10.0,
            right: 10.0);
      }
    } else {
      if (widget.showTail || !widget.showHandle) {
        if (!widget.message.isFromMe) {
          padding = EdgeInsets.only(left: 10.0, bottom: 2.0);
        }
      } else {
        padding = EdgeInsets.only(left: 10.0);
      }
    }

    return Column(
      mainAxisAlignment: widget.message.isFromMe
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Stack(
          alignment: Alignment.topRight,
          children: <Widget>[
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildAttachments(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildAttachments() {
    List<Widget> content = <Widget>[];

    for (Attachment attachment
        in CurrentChat.of(context)?.getAttachmentsForMessage(widget.message) ??
            []) {
      if (attachment.mimeType != null) {
        content.add(
          MessageAttachment(
            message: widget.message,
            attachment: attachment,
            updateAttachment: () {
              // attachment = AttachmentHelper.getContent(attachment);
            },
          ),
        );
      }
    }

    return content;
  }

  String getMimeType(File attachment) {
    String mimeType = mime(p.basename(attachment.path));
    if (mimeType == null) return "";
    mimeType = mimeType.substring(0, mimeType.indexOf("/"));
    return mimeType;
  }
}
