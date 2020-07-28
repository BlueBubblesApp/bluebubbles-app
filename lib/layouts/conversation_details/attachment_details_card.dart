import 'dart:async';
import 'dart:io';

import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubble_messages/layouts/image_viewer/video_viewer.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:path/path.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class AttachmentDetailsCard extends StatefulWidget {
  AttachmentDetailsCard({Key key, this.attachment}) : super(key: key);
  final Attachment attachment;

  @override
  _AttachmentDetailsCardState createState() => _AttachmentDetailsCardState();
}

class _AttachmentDetailsCardState extends State<AttachmentDetailsCard> {
  StreamSubscription downloadStream;
  VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    if (downloadStream != null) downloadStream.cancel();
    if (_controller != null) _controller.dispose();
    super.dispose();
  }

  void subscribeToDownloadStream() {
    if (SocketManager()
            .attachmentDownloaders
            .containsKey(widget.attachment.guid) &&
        downloadStream == null) {
      downloadStream = SocketManager()
          .attachmentDownloaders[widget.attachment.guid]
          .stream
          .listen((event) {
        if (event is File && this.mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Attachment attachment = widget.attachment;
    File file = new File(
      "${SettingsManager().appDocDir.path}/attachments/${attachment.guid}/${attachment.transferName}",
    );
    if (!file.existsSync()) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // attachment.blurhash != null
          //     ? BlurHash(
          //         hash: attachment.blurhash,
          //         decodingWidth:
          //             (attachment.width).clamp(1, double.infinity).toInt(),
          //         decodingHeight:
          //             (attachment.height).clamp(1, double.infinity).toInt(),
          //         imageFit: BoxFit.fill,
          //       )
          //     :
          Container(
            color: Theme.of(context).accentColor,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              !SocketManager()
                      .attachmentDownloaders
                      .containsKey(attachment.guid)
                  ? CupertinoButton(
                      padding: EdgeInsets.only(
                          left: 20, right: 20, top: 10, bottom: 10),
                      onPressed: () {
                        new AttachmentDownloader(attachment, null);
                        subscribeToDownloadStream();
                        if (this.mounted) setState(() {});
                      },
                      color: Colors.transparent,
                      child: Column(
                        children: <Widget>[
                          Text(
                            attachment.getFriendlySize(),
                            style: Theme.of(context).textTheme.bodyText1,
                          ),
                          Icon(Icons.cloud_download, size: 28.0),
                          (attachment.mimeType != null)
                              ? Text(
                                  basename(file.path),
                                  style: Theme.of(context).textTheme.bodyText1,
                                )
                              : Container()
                        ],
                      ),
                    )
                  : StreamBuilder<Object>(
                      stream: SocketManager()
                          .attachmentDownloaders[attachment.guid]
                          .stream,
                      builder: (context, snapshot) {
                        return CircularProgressIndicator(
                          backgroundColor: Colors.grey,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          value: snapshot.hasData && snapshot.data is Map
                              ? (snapshot.data
                                  as Map<String, double>)["Progress"]
                              : 0,
                        );
                      },
                    ),
            ],
          ),
        ],
      );
    } else {
      return SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: _buildPreview(file, context),
      );
    }
  }

  Widget _buildPreview(File file, BuildContext context) {
    if (widget.attachment.mimeType.startsWith("image/")) {
      return Stack(
        children: <Widget>[
          SizedBox(
            child: Hero(
              tag: widget.attachment.guid,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            width: MediaQuery.of(context).size.width / 2,
            height: MediaQuery.of(context).size.width / 2,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => ImageViewer(
                      file: file,
                      tag: widget.attachment.guid,
                    ),
                  ),
                );
              },
            ),
          )
        ],
      );
    } else if (widget.attachment.mimeType.startsWith("video/")) {
      if (_controller == null)
        _controller = VideoPlayerController.file(file)..initialize();

      return Stack(
        children: <Widget>[
          Hero(
            tag: widget.attachment.guid,
            child: VideoPlayer(_controller),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => VideoViewer(
                      controller: _controller,
                      heroTag: widget.attachment.guid,
                    ),
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ],
      );
    } else {
      return Container(
        color: Theme.of(context).accentColor,
        child: Center(
          child: RegularFileOpener(
            file: file,
            attachment: widget.attachment,
          ),
        ),
      );
    }
  }
}
