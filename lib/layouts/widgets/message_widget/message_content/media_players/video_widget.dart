import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/layouts/image_viewer/video_viewer.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoWidget extends StatefulWidget {
  VideoWidget({
    Key key,
    @required this.file,
    @required this.attachment,
    @required this.savedAttachmentData,
    @required this.controllers,
    @required this.changeCurrentPlayingVideo,
  }) : super(key: key);
  final File file;
  final Attachment attachment;
  final SavedAttachmentData savedAttachmentData;
  final Map<String, VideoPlayerController> controllers;
  final Function(Map<String, VideoPlayerController>) changeCurrentPlayingVideo;

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget>
    with TickerProviderStateMixin {
  // VideoPlayerController widget.savedAttachmentData.controller;

  bool showPlayPauseOverlay = true;
  bool isVisible = false;
  Timer hideOverlayTimer;
  bool navigated = false;

  @override
  void initState() {
    super.initState();
    showPlayPauseOverlay = widget.controllers == null ||
        !widget.controllers.containsKey(widget.attachment.guid) ||
        !widget.controllers[widget.attachment.guid].value.isPlaying;
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    getThumbnail();
  }

  void getThumbnail() async {
    if (widget.savedAttachmentData.imageData
            .containsKey(widget.attachment.guid) &&
        widget.savedAttachmentData.imageData[widget.attachment.guid] != null)
      return;
    widget.savedAttachmentData.imageData[widget.attachment.guid] =
        await VideoThumbnail.thumbnailData(
      video: widget.file.path,
      imageFormat: ImageFormat.JPEG,
      quality: 25,
    );
    if (widget.attachment.width == null) {
      Size size = ImageSizeGetter.getSize(MemoryInput(
          widget.savedAttachmentData.imageData[widget.attachment.guid]));
      widget.attachment.width = size.width;
      widget.attachment.height = size.height;
    }
    if (this.mounted) this.setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    VideoPlayerController controller;
    if (widget.controllers != null &&
        widget.controllers.containsKey(widget.attachment.guid)) {
      controller = widget.controllers[widget.attachment.guid];
    }
    return VisibilityDetector(
      onVisibilityChanged: (info) {
        if (info.visibleFraction == 0 && isVisible && !navigated) {
          isVisible = false;
          if (controller != null) {
            controller = null;
            widget.changeCurrentPlayingVideo(null);
          }
        } else if (!isVisible) {
          isVisible = true;
        }
        if (this.mounted) setState(() {});
      },
      key: Key(widget.attachment.guid),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: controller != null
            ? GestureDetector(
                onTap: () async {
                  if (controller.value.isPlaying) {
                    controller.pause();
                    setState(() {
                      showPlayPauseOverlay = true;
                    });
                  } else {
                    setState(() {
                      navigated = true;
                    });
                    await Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (context) => VideoViewer(
                          controller: controller,
                          heroTag: widget.attachment.guid,
                          file: widget.file,
                        ),
                      ),
                    );
                    setState(() {
                      navigated = false;
                    });
                  }
                },
                child: controller.value.aspectRatio != null
                    ? Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width / 2,
                          maxHeight: MediaQuery.of(context).size.height / 2,
                        ),
                        child: Hero(
                          tag: widget.attachment.guid,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              AspectRatio(
                                aspectRatio: widget.attachment.width /
                                    widget.attachment.height,
                                child: Stack(
                                  children: <Widget>[
                                    VideoPlayer(controller),
                                  ],
                                ),
                              ),
                              AnimatedOpacity(
                                opacity: showPlayPauseOverlay ? 1 : 0,
                                duration: Duration(milliseconds: 250),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: HexColor('26262a').withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  padding: EdgeInsets.all(10),
                                  child: controller.value.isPlaying
                                      ? GestureDetector(
                                          child: Icon(
                                            Icons.pause,
                                            color: Colors.white,
                                            size: 45,
                                          ),
                                          onTap: () {
                                            controller.pause();
                                            setState(() {
                                              showPlayPauseOverlay = true;
                                            });
                                          },
                                        )
                                      : GestureDetector(
                                          child: Icon(
                                            Icons.play_arrow,
                                            color: Colors.white,
                                            size: 45,
                                          ),
                                          onTap: () {
                                            controller.play();
                                            setState(() {
                                              showPlayPauseOverlay = false;
                                            });
                                          },
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Container(),
              )
            : GestureDetector(
                onTap: () async {
                  VideoPlayerController controller =
                      VideoPlayerController.file(widget.file);
                  await controller.initialize();
                  controller.play();
                  widget.changeCurrentPlayingVideo(
                      {widget.attachment.guid: controller});
                },
                child: Stack(
                  children: [
                    AnimatedSize(
                      vsync: this,
                      curve: Curves.easeInOut,
                      alignment: Alignment.center,
                      duration: Duration(milliseconds: 250),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width / 2,
                          maxHeight: MediaQuery.of(context).size.height / 2,
                        ),
                        child: AspectRatio(
                          aspectRatio: widget.attachment.width != null &&
                                  widget.attachment.height != null
                              ? widget.attachment.width /
                                  widget.attachment.height
                              : MediaQuery.of(context).size.width / 5,
                          child: widget.savedAttachmentData.imageData
                                  .containsKey(widget.attachment.guid)
                              ? Image.memory(
                                  widget.savedAttachmentData
                                      .imageData[widget.attachment.guid],
                                )
                              : Container(
                                  height: 5,
                                  child: Center(
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.grey,
                                      valueColor: AlwaysStoppedAnimation(
                                        Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // child: Image.file(widget.file),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: HexColor('26262a').withOpacity(0.5),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 45,
                      ),
                    ),
                  ],
                  alignment: Alignment.center,
                ),
              ),
      ),
    );
  }
}
