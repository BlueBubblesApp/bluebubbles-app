import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachment.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
import 'package:video_player/video_player.dart';

class SavedAttachmentData {
  List<Attachment> attachments = [];
  Map<String, Metadata> urlMetaData = {};
  Future<List<Attachment>> attachmentsFuture;
  Map<String, Uint8List> imageData = {};
}

class MessageAttachments extends StatefulWidget {
  MessageAttachments({
    Key key,
    @required this.message,
    @required this.savedAttachmentData,
    @required this.showTail,
    @required this.showHandle,
    @required this.controllers,
    @required this.changeCurrentPlayingVideo,
    @required this.allAttachments,
  }) : super(key: key);
  final Message message;
  final SavedAttachmentData savedAttachmentData;
  final bool showTail;
  final bool showHandle;
  final Map<String, VideoPlayerController> controllers;
  final Function(Map<String, VideoPlayerController>) changeCurrentPlayingVideo;
  final List<Attachment> allAttachments;

  @override
  _MessageAttachmentsState createState() => _MessageAttachmentsState();
}

class _MessageAttachmentsState extends State<MessageAttachments>
    with TickerProviderStateMixin {
  Map<String, dynamic> _attachments = new Map();

  @override
  void initState() {
    super.initState();
    if (widget.savedAttachmentData.attachments.length > 0) {
      for (Attachment attachment in widget.savedAttachmentData.attachments) {
        _attachments[attachment.guid] = AttachmentHelper.getContent(attachment);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.savedAttachmentData.attachmentsFuture == null &&
        widget.savedAttachmentData.attachments.length == 0) {
      widget.savedAttachmentData.attachmentsFuture =
          Message.getAttachments(widget.message);
    }
    return FutureBuilder(
      builder: (context, snapshot) {
        if (snapshot.hasData ||
            widget.savedAttachmentData.attachments.length > 0) {
          if (widget.savedAttachmentData.attachments.length == 0)
            widget.savedAttachmentData.attachments = snapshot.data;

          for (Attachment attachment
              in widget.savedAttachmentData.attachments) {
            _attachments[attachment.guid] =
                AttachmentHelper.getContent(attachment);
          }
          return _buildActualWidget();
        } else {
          return Container();
        }
      },
      future: widget.savedAttachmentData.attachmentsFuture,
    );
  }

  Widget _buildActualWidget() {
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
                padding:
                    widget.message.hasReactions && widget.message.hasAttachments
                        ? EdgeInsets.only(
                            right: !widget.message.isFromMe ? 16.0 : 10.0,
                            bottom: 10.0,
                            left: widget.message.isFromMe
                                ? 16.0
                                : (widget.showTail) ? 10.0 : 45.0,
                            top: 24.0,
                          )
                        : EdgeInsets.symmetric(
                            horizontal: (widget.showTail ||
                                    !widget.showHandle ||
                                    widget.message.isFromMe)
                                ? 10.0
                                : 45.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildAttachments(),
                )),
            widget.message.hasReactions
                ? Reactions(
                    message: widget.message,
                  )
                : Container(),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildAttachments() {
    List<Widget> content = <Widget>[];
    List<Attachment> nullMimeTypeAttachments = <Attachment>[];

    for (Attachment attachment in widget.savedAttachmentData.attachments) {
      if (attachment.mimeType == null) {
        nullMimeTypeAttachments.add(attachment);
      } else {
        content.add(
          MessageAttachment(
            controllers: widget.controllers,
            message: widget.message,
            attachment: attachment,
            content: _attachments[attachment.guid],
            changeCurrentPlayingVideo: widget.changeCurrentPlayingVideo,
            updateAttachment: () {
              attachment = AttachmentHelper.getContent(attachment);
            },
            savedAttachmentData: widget.savedAttachmentData,
            allAttachments: widget.allAttachments,
          ),
        );
      }
    }
    if (nullMimeTypeAttachments.length != 0)
      content.add(
        UrlPreviewWidget(
          linkPreviews: nullMimeTypeAttachments,
          message: widget.message,
          savedAttachmentData: widget.savedAttachmentData,
        ),
      );

    return content;
  }

  String getMimeType(File attachment) {
    String mimeType = mime(basename(attachment.path));
    if (mimeType == null) return "";
    mimeType = mimeType.substring(0, mimeType.indexOf("/"));
    return mimeType;
  }
}
