import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_holder.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player/video_player.dart' as vp;

class VideoPlayer extends StatefulWidget {
  final PlatformFile file;
  final Attachment attachment;
  final bool isFromMe;

  VideoPlayer({
    Key? key,
    required this.file,
    required this.attachment,
    required this.controller,
    required this.isFromMe
  }) : super(key: key);

  final ConversationViewController? controller;

  @override
  OptimizedState createState() => _VideoPlayerState();
}

class _VideoPlayerState extends OptimizedState<VideoPlayer> with AutomaticKeepAliveClientMixin {
  Attachment get attachment => widget.attachment;
  PlatformFile get file => widget.file;
  bool get isFromMe => widget.isFromMe;
  ConversationViewController? get cvController => widget.controller;

  PlayerStatus status = PlayerStatus.NONE;
  bool hasListener = false;
  VideoPlayerController? controller;
  Uint8List? thumbnail;
  final RxBool showPlayPauseOverlay = true.obs;
  final RxBool muted = ss.settings.startVideosMuted;

  @override
  void initState() {
    super.initState();
    controller = cvController?.videoPlayers[attachment.guid];
    thumbnail = cvController?.imageData[attachment.guid];

    updateObx(() {
      if (controller != null) {
        createListener(controller!);
      }
      if (thumbnail == null) {
        getThumbnail();
      }
    });
  }

  Future<void> initializeController() async {
    PlatformFile _file = file;
    if (kIsWeb || _file.path == null) {
      final blob = html.Blob([_file.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      controller = VideoPlayerController.network(url);
    } else {
      dynamic file = File(_file.path!);
      controller = VideoPlayerController.file(file);
    }
    await controller!.initialize();
    createListener(controller!);
    cvController?.videoPlayers[attachment.guid!] = controller!;
    setState(() {});
  }

  void createListener(VideoPlayerController controller) {
    if (hasListener) return;
    controller.addListener(() async {
      final currentStatus = getControllerStatus(controller);
      // If the status hasn't changed, don't do anything
      if (currentStatus == status) return;
      status = currentStatus;
      // If the status is ended, restart
      if (status == PlayerStatus.ENDED) {
        showPlayPauseOverlay.value = true;
        await controller.pause();
        await controller.seekTo(Duration.zero);
      }
    });
    hasListener = true;
  }

  void getThumbnail() async {
    if (!kIsWeb) {
      try {
        // If we already errored, throw an error to load the error logo
        if (attachment.metadata?['thumbnail_status'] == 'error') {
          throw Exception('No video preview');
        }
        // If we haven't errored at all, fetch the thumbnail
        thumbnail = await as.getVideoThumbnail(file.path!);
      } catch (ex) {
        // If an error occurs, set the thumnail to the cached no preview image.
        // Only save to DB if the status wasn't already `error` somehow
        thumbnail = fs.noVideoPreviewIcon;
        if (attachment.metadata?['thumbnail_status'] != 'error') {
          attachment.metadata ??= {};
          attachment.metadata!['thumbnail_status'] = 'error';
          if (attachment.id != null) {
            attachment.save(null);
          }
        }
      }

      if (thumbnail == null) return;
      cvController?.imageData[attachment.guid!] = thumbnail!;
      await precacheImage(MemoryImage(thumbnail!), context);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (controller != null) {
      return GestureDetector(
        onTap: () async {
          if (!kIsWeb && attachment.id == null) return;
          if (controller!.value.isPlaying) {
            controller!.pause();
            showPlayPauseOverlay.value = true;
          } else {
            if (!kIsWeb && attachment.id == null) return;
            await Navigator.of(Get.context!).push(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => FullscreenMediaHolder(
                  currentChat: cm.activeChat,
                  attachment: attachment,
                  showInteractions: true,
                ),
              ),
            );
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AspectRatio(
              aspectRatio: controller!.value.aspectRatio,
              child: vp.VideoPlayer(controller!),
            ),
            PlayPauseButton(showPlayPauseOverlay: showPlayPauseOverlay, controller: controller),
            MuteButton(
              showPlayPauseOverlay: showPlayPauseOverlay,
              muted: muted,
              controller: controller,
              isFromMe: widget.isFromMe
            ),
          ],
        ),
      );
    }
    return InkWell(
      onTap: () async {
        if (!kIsWeb && attachment.id == null) return;
        await Navigator.of(Get.context!).push(
          ThemeSwitcher.buildPageRoute(
            builder: (context) => FullscreenMediaHolder(
              currentChat: cm.activeChat,
              attachment: attachment,
              showInteractions: true,
            ),
          ),
        );
      },
      child: thumbnail == null ? SizedBox(
        width: min((attachment.width?.toDouble() ?? ns.width(context) * 0.5), ns.width(context) * 0.5),
        height: min((attachment.height?.toDouble() ?? ns.width(context) * 0.5 / attachment.aspectRatio), ns.width(context) * 0.5 / attachment.aspectRatio),
      ) : Image.memory(
        thumbnail!,
        // prevents the image widget from "refreshing" when the provider changes
        gaplessPlayback: true,
        filterQuality: FilterQuality.none,
        cacheWidth: (min((attachment.width ?? 0), ns.width(context) * 0.5) * Get.pixelRatio / 2).round().abs().nonZero,
        cacheHeight: (min((attachment.height ?? 0), ns.width(context) * 0.5 / attachment.aspectRatio) * Get.pixelRatio / 2).round().abs().nonZero,
        fit: BoxFit.cover,
        frameBuilder: (context, widget, frame, wasSyncLoaded) {
          return AnimatedCrossFade(
            crossFadeState: frame == null ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            alignment: Alignment.center,
            duration: const Duration(milliseconds: 150),
            secondChild: Stack(
              alignment: Alignment.center,
              children: [
                widget,
                PlayPauseButton(showPlayPauseOverlay: showPlayPauseOverlay, controller: controller, customOnTap: () async {
                  await initializeController();
                  controller!.setVolume(muted.value ? 0.0 : 1.0);
                  controller!.play();
                  showPlayPauseOverlay.value = false;
                }),
                MuteButton(
                  showPlayPauseOverlay: showPlayPauseOverlay,
                  muted: muted,
                  controller: controller,
                  isFromMe: isFromMe
                ),
              ],
            ),
            firstChild: SizedBox(
              width: min((attachment.width?.toDouble() ?? ns.width(context) * 0.5), ns.width(context) * 0.5),
              height: min((attachment.height?.toDouble() ?? ns.width(context) * 0.5 / attachment.aspectRatio), ns.width(context) * 0.5 / attachment.aspectRatio),
            )
          );
        },
      )
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    Key? key,
    required this.showPlayPauseOverlay,
    required this.controller,
    this.customOnTap
  }) : super(key: key);

  final RxBool showPlayPauseOverlay;
  final VideoPlayerController? controller;
  final Function? customOnTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() => AnimatedOpacity(
      opacity: showPlayPauseOverlay.value && ReplyScope.maybeOf(context) == null ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        height: 75,
        width: 75,
        decoration: BoxDecoration(
          color: HexColor('26262a').withOpacity(0.5),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: ss.settings.skin.value == Skins.iOS && !(controller?.value.isPlaying ?? false) ? 17 : 10,
            top: ss.settings.skin.value == Skins.iOS ? 13 : 10,
            right: 10,
            bottom: 10,
          ),
          child: controller?.value.isPlaying ?? false ? GestureDetector(
            child: Icon(
              ss.settings.skin.value == Skins.iOS ? CupertinoIcons.pause : Icons.pause,
              color: Colors.white,
              size: 45,
            ),
            onTap: () {
              controller!.pause();
              showPlayPauseOverlay.value = true;
            },
          ) : GestureDetector(
            child: Icon(
              ss.settings.skin.value == Skins.iOS
                  ? CupertinoIcons.play
                  : Icons.play_arrow,
              color: Colors.white,
              size: 45,
            ),
            onTap: () {
              if (customOnTap != null) {
                customOnTap?.call();
              } else {
                controller!.play();
                showPlayPauseOverlay.value = false;
              }
            },
          ),
        ),
      ),
    ));
  }
}

class MuteButton extends StatelessWidget {
  const MuteButton({
    Key? key,
    required this.showPlayPauseOverlay,
    required this.muted,
    required this.controller,
    required this.isFromMe
  }) : super(key: key);

  final RxBool showPlayPauseOverlay;
  final RxBool muted;
  final VideoPlayerController? controller;
  final bool isFromMe;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 8,
      right: (isFromMe) ? 15 : 8,
      child: Obx(() => AnimatedOpacity(
        opacity: showPlayPauseOverlay.value && ReplyScope.maybeOf(context) == null ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: AbsorbPointer(
          absorbing: !showPlayPauseOverlay.value,
          child: GestureDetector(
            onTap: () {
              muted.toggle();
              controller?.setVolume(muted.value ? 0.0 : 1.0);
            },
            child: Container(
              decoration: BoxDecoration(
                color: HexColor('26262a').withOpacity(0.5),
                borderRadius: BorderRadius.circular(40),
              ),
              padding: const EdgeInsets.all(5),
              child: Icon(
                muted.value
                    ? ss.settings.skin.value == Skins.iOS
                    ? CupertinoIcons.volume_mute
                    : Icons.volume_mute
                    : ss.settings.skin.value == Skins.iOS
                    ? CupertinoIcons.volume_up
                    : Icons.volume_up,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ),
      )),
    );
  }
}
