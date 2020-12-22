import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path/path.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class AttachmentDetailsCard extends StatefulWidget {
  AttachmentDetailsCard({Key key, this.attachment, this.allAttachments})
      : super(key: key);
  final Attachment attachment;
  final List<Attachment> allAttachments;

  @override
  _AttachmentDetailsCardState createState() => _AttachmentDetailsCardState();
}

class _AttachmentDetailsCardState extends State<AttachmentDetailsCard> {
  StreamSubscription downloadStream;
  Uint8List previewImage;
  double aspectRatio = 4 / 3;

  @override
  void initState() {
    super.initState();
    subscribeToDownloadStream();
  }

  @override
  void dispose() {
    if (downloadStream != null) downloadStream.cancel();
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
          Future.delayed(Duration(milliseconds: 500), () {
            setState(() {});
          });
        }
      });
    }
  }

  void getCompressedImage() {
    String path = AttachmentHelper.getAttachmentPath(widget.attachment);
    FlutterImageCompress.compressWithFile(path, quality: 20).then((data) {
      if (this.mounted) {
        setState(() {
          previewImage = data;
        });
      }
    });
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
                      onPressed: () async {
                        AttachmentDownloader downloader =
                            new AttachmentDownloader(attachment,
                                autoFetch: false);
                        await downloader.fetchAttachment(attachment);
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

  Future<void> getVideoPreview(File file) async {
    if (previewImage != null) return;
    previewImage = await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      quality: 50,
    );
    Size size = ImageSizeGetter.getSize(MemoryInput(previewImage));
    widget.attachment.width = size.width;
    widget.attachment.height = size.height;
    aspectRatio = size.width / size.height;
    if (this.mounted) setState(() {});
  }

  Widget _buildPreview(File file, BuildContext context) {
    if (widget.attachment.mimeType.startsWith("image/")) {
      if (previewImage == null) {
        getCompressedImage();
      }

      return Stack(
        children: <Widget>[
          SizedBox(
            child: Hero(
                tag: widget.attachment.guid,
                child: (previewImage != null)
                    ? Image.memory(
                        previewImage,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        alignment: Alignment.center,
                      )
                    : Container()),
            width: MediaQuery.of(context).size.width / 2,
            height: MediaQuery.of(context).size.width / 2,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                CurrentChat currentChat = CurrentChat.of(context);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => AttachmentFullscreenViewer(
                      currentChat: currentChat,
                      attachment: widget.attachment,
                      showInteractions: true,
                    ),
                  ),
                );
              },
            ),
          )
        ],
      );
    } else if (widget.attachment.mimeType.startsWith("video/")) {
      getVideoPreview(file);

      return Stack(
        children: <Widget>[
          SizedBox(
            child: Hero(
              tag: widget.attachment.guid,
              child: previewImage != null
                  ? Image.memory(
                      previewImage,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      alignment: Alignment.center,
                    )
                  : Container(),
            ),
            width: MediaQuery.of(context).size.width / 2,
            height: MediaQuery.of(context).size.width / 2,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                CurrentChat currentChat = CurrentChat.of(context);
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => AttachmentFullscreenViewer(
                      currentChat: currentChat,
                      attachment: widget.attachment,
                      showInteractions: true,
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
