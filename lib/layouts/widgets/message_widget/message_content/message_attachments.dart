import 'package:bluebubbles/helpers/utils.dart';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachment.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart' as p;

class MessageAttachments extends StatefulWidget {
  MessageAttachments({
    Key? key,
    required this.message,
    required this.showTail,
    required this.showHandle,
  }) : super(key: key);
  final Message? message;
  final bool showTail;
  final bool? showHandle;

  @override
  _MessageAttachmentsState createState() => _MessageAttachmentsState();
}

class _MessageAttachmentsState extends State<MessageAttachments> with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    EdgeInsets padding = EdgeInsets.all(0.0);
    if (widget.message!.hasReactions && widget.message!.hasAttachments) {
      if (widget.message!.isFromMe!) {
        padding =
            EdgeInsets.only(top: 15.0, bottom: (widget.message!.hasAttachments) ? 2.0 : 10.0, left: 12.0, right: 0.0);
      } else {
        padding = EdgeInsets.only(
            top: widget.showHandle! ? 18.0 : 15.0,
            bottom: (widget.message!.hasAttachments) ? 2.0 : 10.0,
            left: 10.0,
            right: 10.0);
      }
    } else {
      if (widget.showTail || !widget.showHandle!) {
        if (!widget.message!.isFromMe!) {
          padding = EdgeInsets.only(left: 10.0, bottom: 2.0);
        } else if (!isEmptyString(widget.message!.fullText)) {
          padding = EdgeInsets.only(right: 10.0, bottom: 2.0);
        }
      } else {
        padding = EdgeInsets.only(left: 10.0);
      }
    }

    return Column(
      mainAxisAlignment: widget.message!.isFromMe! ? MainAxisAlignment.end : MainAxisAlignment.start,
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
    var items;
    if (widget.message?.guid == "redacted-mode-demo" || widget.message!.guid!.contains("theme-selector")) {
      items = widget.message!.attachments;
    } else {
      items = CurrentChat.of(context)?.getAttachmentsForMessage(widget.message) ?? [];
    }
    for (Attachment? attachment in items) {
      if (attachment!.mimeType != null) {
        Widget attachmentWidget = MessageAttachment(
          attachment: attachment,
          updateAttachment: () {
            // attachment = AttachmentHelper.getContent(attachment);
          },
          isFromMe: widget.message?.isFromMe ?? false,
        );

        if (widget.message!.error == 0) {
          content.add(attachmentWidget);
        } else {
          content.add(Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              attachmentWidget,
              Container(width: 5),
              SentMessageHelper.getErrorWidget(context, widget.message, CurrentChat.of(context)?.chat, rightPadding: 0),
            ],
          ));
        }
      }
    }

    return content;
  }

  String? getMimeType(File attachment) {
    String? mimeType = mime(p.basename(attachment.path));
    if (mimeType == null) return "";
    mimeType = mimeType.substring(0, mimeType.indexOf("/"));
    return mimeType;
  }
}
