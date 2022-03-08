import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum PlayerStatus { NONE, STOPPED, PAUSED, PLAYING, ENDED }

class VideoWidgetController extends GetxController {
  bool navigated = false;
  bool isVisible = false;
  PlayerStatus status = PlayerStatus.NONE;
  bool hasListener = false;
  VideoPlayerController? controller;
  Uint8List? thumbnail;
  late final RxBool showPlayPauseOverlay;
  final RxBool muted = SettingsManager().settings.startVideosMuted;
  final PlatformFile file;
  final Attachment attachment;
  final BuildContext context;

  VideoWidgetController({
    required this.file,
    required this.attachment,
    required this.context,
  });

  @override
  void onInit() {
    super.onInit();
    Map<String, VideoPlayerController> controllers = ChatManager().activeChat!.currentPlayingVideo;
    showPlayPauseOverlay =
        RxBool(!controllers.containsKey(attachment.guid) || !controllers[attachment.guid]!.value.isPlaying);

    if (controllers.containsKey(attachment.guid)) {
      controller = controllers[attachment.guid]!;
      createListener(controller!);
    } else {
      if (ChatManager().activeChat?.imageData[attachment.guid] != null) {
        thumbnail = ChatManager().activeChat?.imageData[attachment.guid];
      } else {
        getThumbnail();
      }
    }
  }

  Future<void> initializeController() async {
    PlatformFile file2 = file;
    if (kIsWeb || file2.path == null) {
      final blob = html.Blob([file2.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      controller = VideoPlayerController.network(url);
    } else {
      dynamic file = File(file2.path!);
      controller = VideoPlayerController.file(file);
    }
    await controller!.initialize();
    createListener(controller!);
    ChatManager().activeChat?.changeCurrentPlayingVideo({attachment.guid!: controller!});
  }

  void createListener(VideoPlayerController controller) {
    if (hasListener) return;

    controller.addListener(() async {
      // Get the current status
      PlayerStatus currentStatus = await getControllerStatus(controller);

      // If the status hasn't changed, don't do anything
      if (currentStatus == status) return;
      status = currentStatus;

      // If the status is ended, restart
      if (status == PlayerStatus.ENDED) {
        showPlayPauseOverlay.value = true;
        await controller.pause();
        await controller.seekTo(Duration());
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
        thumbnail = await AttachmentHelper.getVideoThumbnail(file.path!);
      } catch (ex) {
        // If an error occurs, set the thumnail to the cached no preview image.
        // Only save to DB if the status wasn't already `error` somehow
        thumbnail = ChatManager().noVideoPreviewIcon;
        if (attachment.metadata?['thumbnail_status'] != 'error') {
          attachment.metadata ??= {};
          attachment.metadata!['thumbnail_status'] = 'error';
          attachment.save(null);
        }
      }
      
      if (thumbnail == null) return;
      ChatManager().activeChat?.imageData[attachment.guid!] = thumbnail!;
      await precacheImage(MemoryImage(thumbnail!), context);
      update();
    }
  }
}

class VideoWidget extends StatelessWidget {
  VideoWidget({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);
  final PlatformFile file;
  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VideoWidgetController>(
      global: false,
      init: VideoWidgetController(file: file, attachment: attachment, context: context),
      dispose: (state) {
        state.controller?.navigated = true;
      },
      builder: (controller) {
        return VisibilityDetector(
          onVisibilityChanged: (info) {
            if (info.visibleFraction == 0 && controller.isVisible && !controller.navigated) {
              controller.isVisible = false;
              controller.controller?.pause();
              controller.showPlayPauseOverlay.value = true;
            } else if (!controller.isVisible) {
              controller.isVisible = true;
            }
          },
          key: Key(attachment.guid!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: AnimatedSize(
              curve: Curves.easeInOut,
              alignment: Alignment.center,
              duration: Duration(milliseconds: 250),
              child: controller.controller != null ? Obx(() => buildPlayer(controller, context)) : buildPreview(controller, context),
            ),
          ),
        );
      },
    );
  }

  Widget buildPlayer(VideoWidgetController controller, BuildContext context) => GestureDetector(
    onTap: () async {
      if (controller.controller!.value.isPlaying) {
        controller.controller!.pause();
        controller.showPlayPauseOverlay.value = true;
      } else {
        controller.navigated = true;
        ChatController? currentChat = ChatManager().activeChat;
        await Navigator.of(Get.context!).push(
          ThemeSwitcher.buildPageRoute(
            builder: (context) => AttachmentFullscreenViewer(
              currentChat: currentChat,
              attachment: attachment,
              showInteractions: true,
            ),
          ),
        );
        controller.navigated = false;
      }
    },
    child: Container(
      constraints: BoxConstraints(
        maxWidth: CustomNavigator.width(context) / 2,
        maxHeight: context.height / 2,
      ),
      child: Hero(
        tag: attachment.guid!,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            AspectRatio(
              aspectRatio: controller.controller!.value.aspectRatio,
              child: VideoPlayer(controller.controller!),
            ),
            AnimatedOpacity(
              opacity: controller.showPlayPauseOverlay.value ? 1 : 0,
              duration: Duration(milliseconds: 250),
              child: Container(
                  height: 75,
                  width: 75,
                  decoration: BoxDecoration(
                    color: HexColor('26262a').withOpacity(0.5),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: EdgeInsets.all(10),
                  child: Padding(
                    padding: EdgeInsets.only(left: SettingsManager().settings.skin.value == Skins.iOS && !controller.controller!.value.isPlaying ? 7 : 0,
                        top: SettingsManager().settings.skin.value == Skins.iOS ? 3 : 0),
                    child: controller.controller!.value.isPlaying ? GestureDetector(
                      child: Icon(
                        SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.pause : Icons.pause,
                        color: Colors.white,
                        size: 45,
                      ),
                      onTap: () {
                        controller.controller!.pause();
                        controller.showPlayPauseOverlay.value = true;
                      },
                    ) : GestureDetector(
                      child: Icon(
                        SettingsManager().settings.skin.value == Skins.iOS
                            ? CupertinoIcons.play
                            : Icons.play_arrow,
                        color: Colors.white,
                        size: 45,
                      ),
                      onTap: () {
                        controller.controller!.play();
                        controller.showPlayPauseOverlay.value = false;
                      },
                    ),
                  )
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                  child: AnimatedOpacity(
                    opacity: controller.showPlayPauseOverlay.value ? 1 : 0,
                    duration: Duration(milliseconds: 250),
                    child: AbsorbPointer(
                      absorbing: !controller.showPlayPauseOverlay.value,
                      child: GestureDetector(
                        onTap: () {
                          controller.muted.toggle();
                          controller.controller!.setVolume(controller.muted.value ? 0.0 : 1.0);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: HexColor('26262a').withOpacity(0.5),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          padding: EdgeInsets.all(5),
                          child: Obx(() => Icon(
                            controller.muted.value
                                ? SettingsManager().settings.skin.value == Skins.iOS
                                ? CupertinoIcons.volume_mute
                                : Icons.volume_mute
                                : SettingsManager().settings.skin.value == Skins.iOS
                                ? CupertinoIcons.volume_up
                                : Icons.volume_up,
                            color: Colors.white,
                            size: 15,
                          )),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget buildPreview(VideoWidgetController controller, BuildContext context) => GestureDetector(
    onTap: () async {
      await controller.initializeController();
      controller.controller!.setVolume(controller.muted.value ? 0.0 : 1.0);
      controller.controller!.play();
    },
    child: Stack(
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: context.width / 2,
            maxHeight: context.height / 2,
          ),
          child: buildSwitcher(controller),
        ),
        Container(
          height: 75,
          width: 75,
          decoration: BoxDecoration(
            color: HexColor('26262a').withOpacity(0.5),
            borderRadius: BorderRadius.circular(40),
          ),
          padding: EdgeInsets.all(10),
          child: Padding(
            padding: EdgeInsets.only(left: SettingsManager().settings.skin.value == Skins.iOS ? 7 : 0,
                top: SettingsManager().settings.skin.value == Skins.iOS ? 3 : 0),
            child: Icon(
              SettingsManager().settings.skin.value == Skins.iOS
                  ? CupertinoIcons.play
                  : Icons.play_arrow,
              color: Colors.white,
              size: 45,
            ),
          ),
        ),
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
              child: GestureDetector(
                onTap: () {
                  controller.muted.toggle();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: HexColor('26262a').withOpacity(0.5),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: EdgeInsets.all(5),
                  child: Obx(() => Icon(
                    controller.muted.value
                        ? SettingsManager().settings.skin.value == Skins.iOS
                        ? CupertinoIcons.volume_mute
                        : Icons.volume_mute
                        : SettingsManager().settings.skin.value == Skins.iOS
                        ? CupertinoIcons.volume_up
                        : Icons.volume_up,
                    color: Colors.white,
                    size: 15,
                  )),
                ),
              ),
            ),
          ),
        ),
      ],
      alignment: Alignment.center,
    ),
  );

  Widget buildSwitcher(VideoWidgetController controller) => AnimatedSwitcher(
    duration: Duration(milliseconds: 150),
    child: controller.thumbnail != null ? Image.memory(controller.thumbnail!) : buildPlaceHolder(controller),
  );

  Widget buildPlaceHolder(VideoWidgetController controller) {
    if (controller.attachment.hasValidSize) {
      return AspectRatio(
        aspectRatio: controller.attachment.width!.toDouble() / controller.attachment.height!.toDouble(),
        child: Container(
          width: controller.attachment.width!.toDouble(),
          height: controller.attachment.height!.toDouble(),
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