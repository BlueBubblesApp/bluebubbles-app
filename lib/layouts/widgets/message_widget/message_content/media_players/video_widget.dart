import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum PlayerStatus { NONE, STOPPED, PAUSED, PLAYING, ENDED }

class VideoWidget extends StatefulWidget {
  VideoWidget({
    Key key,
    @required this.file,
    @required this.attachment,
  }) : super(key: key);
  final File file;
  final Attachment attachment;

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> with TickerProviderStateMixin {
  bool showPlayPauseOverlay = true;
  bool isVisible = false;
  Timer hideOverlayTimer;
  bool navigated = false;
  Uint8List thumbnail;
  PlayerStatus status = PlayerStatus.NONE;
  bool hasListener = false;

  @override
  void initState() {
    super.initState();
    Map<String, VideoPlayerController> controllers = CurrentChat.of(context).currentPlayingVideo ?? {};
    showPlayPauseOverlay = controllers == null ||
        !controllers.containsKey(widget.attachment.guid) ||
        !controllers[widget.attachment.guid].value.isPlaying;

    if (controllers.containsKey(widget.attachment.guid)) {
      createListener(controllers[widget.attachment.guid]);
    }
  }

  void createListener(VideoPlayerController controller) {
    if (controller == null || hasListener) return;

    controller.addListener(() async {
      if (controller == null) return;

      // Get the current status
      PlayerStatus currentStatus = await getControllerStatus(controller);

      // If the status hasn't changed, don't do anything
      if (controller == null || currentStatus == status) return;
      this.status = currentStatus;

      // If the status is ended, restart
      if (this.status == PlayerStatus.ENDED) {
        showPlayPauseOverlay = true;
        await controller.pause();
        await controller.seekTo(Duration());
      }

      if (this.mounted) setState(() {});
    });

    hasListener = true;
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    getThumbnail();
  }

  void getThumbnail() async {
    thumbnail = CurrentChat.of(context).getImageData(widget.attachment);
    if (thumbnail != null) return;
    thumbnail = await VideoThumbnail.thumbnailData(
      video: widget.file.path,
      imageFormat: ImageFormat.JPEG,
      quality: 25,
    );
    CurrentChat.of(context).saveImageData(thumbnail, widget.attachment);
    if (this.mounted) this.setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    VideoPlayerController controller;
    Map<String, VideoPlayerController> controllers = CurrentChat.of(context).currentPlayingVideo;
    // If the currently playing video is this attachment guid
    if (controllers != null && controllers.containsKey(widget.attachment.guid)) {
      controller = controllers[widget.attachment.guid];
      this.createListener(controller);
    }

    return VisibilityDetector(
      onVisibilityChanged: (info) {
        if (info.visibleFraction == 0 && isVisible && !navigated) {
          isVisible = false;
          if (controller != null && context != null) {
            controller = null;
            CurrentChat.of(context)?.changeCurrentPlayingVideo(null);
          }
          if (SettingsManager().settings.lowMemoryMode && context != null) {
            CurrentChat.of(context)?.clearImageData(widget.attachment);
          }
        } else if (!isVisible) {
          isVisible = true;
          if (SettingsManager().settings.lowMemoryMode) {
            getThumbnail();
          }
        }
        if (this.mounted) setState(() {});
      },
      key: Key(widget.attachment.guid),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: AnimatedSize(
          vsync: this,
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          duration: Duration(milliseconds: 250),
          child: controller != null ? buildPlayer(controller) : buildPreview(),
        ),
      ),
    );
  }

  Widget buildPlayer(VideoPlayerController controller) => GestureDetector(
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
            CurrentChat currentChat = CurrentChat.of(context);
            await Navigator.of(context).push(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => AttachmentFullscreenViewer(
                  currentChat: currentChat,
                  attachment: widget.attachment,
                  showInteractions: true,
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
                        aspectRatio: controller.value.aspectRatio,
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
      );

  Widget buildPreview() => GestureDetector(
        onTap: () async {
          VideoPlayerController controller = VideoPlayerController.file(widget.file);
          await controller.initialize();
          controller.play();
          CurrentChat.of(context).changeCurrentPlayingVideo({widget.attachment.guid: controller});
        },
        child: Stack(
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width / 2,
                maxHeight: MediaQuery.of(context).size.height / 2,
              ),
              child: buildSwitcher(),
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
      );

  Widget buildSwitcher() => AnimatedSwitcher(
        duration: Duration(milliseconds: 150),
        child: thumbnail != null ? Image.memory(thumbnail) : buildPlaceHolder(),
      );

  Widget buildPlaceHolder() {
    if (widget.attachment.hasValidSize) {
      return AspectRatio(
        aspectRatio: widget.attachment.width.toDouble() / widget.attachment.height.toDouble(),
        child: Container(
          width: widget.attachment.width.toDouble(),
          height: widget.attachment.height.toDouble(),
        ),
      );
    } else {
      return Container(
        width: 0,
        height: 0,
      );
    }
  }
}
