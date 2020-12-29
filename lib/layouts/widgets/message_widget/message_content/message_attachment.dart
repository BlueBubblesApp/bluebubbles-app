import 'dart:io';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_file.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/contact_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/image_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/location_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MessageAttachment extends StatefulWidget {
  MessageAttachment({
    Key key,
    @required this.attachment,
    @required this.updateAttachment,
    @required this.message,
  }) : super(key: key);
  final Attachment attachment;
  final Function() updateAttachment;
  final Message message;

  @override
  _MessageAttachmentState createState() => _MessageAttachmentState();
}

class _MessageAttachmentState extends State<MessageAttachment>
    with AutomaticKeepAliveClientMixin {
  Widget attachmentWidget;
  var content;

  @override
  void initState() {
    super.initState();
    updateContent();
  }

  void updateContent() async {
    // Ge the current attachment content (status)
    content = AttachmentHelper.getContent(widget.attachment);

    // If we can download it, do so
    if (await AttachmentHelper.canAutoDownload() && content is Attachment) {
      if (this.mounted) {
        setState(() {
          content = new AttachmentDownloader(content);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    updateContent();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 3 / 4,
          // maxHeight: 600,
        ),
        child: _buildAttachmentWidget(),
      ),
    );
  }

  Widget _buildAttachmentWidget() {
    // If it's a file, it's already been downlaoded, so just display it
    if (content is File) {
      String mimeType = widget.attachment.mimeType;
      if (mimeType != null)
        mimeType = mimeType.substring(0, mimeType.indexOf("/"));
      if (mimeType == "image") {
        return MediaFile(
          attachment: widget.attachment,
          child: ImageWidget(
            attachment: widget.attachment,
            file: content,
          ),
        );
      } else if (mimeType == "video") {
        return MediaFile(
          attachment: widget.attachment,
          child: VideoWidget(
            attachment: widget.attachment,
            file: content,
          ),
        );
      } else if (mimeType == "audio" &&
          !widget.attachment.mimeType.contains("caf")) {
        return MediaFile(
          attachment: widget.attachment,
          child: AudioPlayerWiget(file: content, context: context, width: 250),
        );
      } else if (widget.attachment.mimeType == "text/x-vlocation") {
        return MediaFile(
          attachment: widget.attachment,
          child: LocationWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (widget.attachment.mimeType == "text/vcard") {
        return MediaFile(
          attachment: widget.attachment,
          child: ContactWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (widget.attachment.mimeType == null) {
        return Container();
      } else {
        return MediaFile(
          attachment: widget.attachment,
          child: RegularFileOpener(
            file: content,
            attachment: widget.attachment,
          ),
        );
      }

      // If it's an attachment, then it needs to be manually downloaded
    } else if (content is Attachment) {
      return AttachmentDownloaderWidget(
        onPressed: () {
          content = new AttachmentDownloader(content);
          if (this.mounted) setState(() {});
        },
        attachment: content,
        placeHolder: buildPlaceHolder(),
      );

      // If it's an AttachmentDownloader, it is currently being downloaded
    } else if (content is AttachmentDownloader) {
      if (widget.attachment.mimeType == null) return Container();
      return StreamBuilder(
        stream: content.stream,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          // If there is an error, return an error text
          if (snapshot.hasError) {
            content = widget.attachment;
            return AttachmentDownloaderWidget(
              onPressed: () {
                content = new AttachmentDownloader(content);
                if (this.mounted) setState(() {});
              },
              attachment: content,
              placeHolder: buildPlaceHolder(),
            );
          }

          // If the snapshot data is a file, we have finished downloading
          if (snapshot.data is File) {
            content = snapshot.data;
            return _buildAttachmentWidget();
          }

          double progress = 0.0;
          if (snapshot.hasData) {
            progress = snapshot.data["progress"];
          } else {
            progress = content.progress;
          }

          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              buildPlaceHolder(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Center(
                        child: CircularProgressIndicator(
                          value: progress == 1.0 ? null : (progress ?? 0),
                          backgroundColor: Colors.grey,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      ((content as AttachmentDownloader).attachment.mimeType !=
                              null)
                          ? Container(height: 5.0)
                          : Container(),
                      (content.attachment.mimeType != null)
                          ? Text(
                              content.attachment.mimeType,
                              style: Theme.of(context).textTheme.bodyText1,
                            )
                          : Container()
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      );
    } else {
      return Text(
        "Error loading",
        style: Theme.of(context).textTheme.bodyText1,
      );
      //     return Container();
    }
  }

  Widget buildPlaceHolder() => ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          height: 150,
          width: 200,
          color: Theme.of(context).accentColor,
        ),
      );

  @override
  bool get wantKeepAlive => true;
}
