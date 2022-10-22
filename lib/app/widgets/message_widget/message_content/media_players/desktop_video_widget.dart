import 'dart:typed_data';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/core/managers/chat/chat_controller.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum PlayerStatus { NONE, STOPPED, PAUSED, PLAYING, ENDED }

class DesktopVideoWidgetController extends GetxController {
  bool navigated = false;
  bool isVisible = false;
  PlaybackState status = PlaybackState();
  bool hasListener = false;
  Player? controller;
  Uint8List? thumbnail;
  late final RxBool showPlayPauseOverlay;
  final RxBool initComplete = false.obs;
  final RxBool muted = ss.settings.startVideosMuted;
  final PlatformFile file;
  final Attachment attachment;
  final BuildContext context;

  DesktopVideoWidgetController({
    required this.file,
    required this.attachment,
    required this.context,
  });

  @override
  void onInit() {
    super.onInit();
    Map<String, Player> controllers = ChatManager().activeChat?.videoPlayersDesktop ?? {};
    showPlayPauseOverlay =
        RxBool(!controllers.containsKey(attachment.guid) || !controllers[attachment.guid]!.playback.isPlaying);

    if (controllers.containsKey(attachment.guid)) {
      controller = controllers[attachment.guid]!;
      Future.delayed(Duration.zero, () => initComplete.value = true);
    } else {
      Future.delayed(Duration.zero, () async => await initializeController());
    }
  }

  Future<void> initializeController() async {
    PlatformFile file2 = file;
    dynamic _file = File(file2.path!);
    controller = Player(id: attachment.hashCode);
    initComplete.value = true;
    if (controller!.current.medias.isEmpty) {
      controller!.add(Media.file(_file));
    }
    controller!.play();
    await controller!.playbackStream.first;
    controller!.pause();
    controller!.seek(Duration.zero);
    createListeners(controller!);
    ChatManager().activeChat?.addVideoDesktop({attachment.guid!: controller!});
  }

  void createListeners(Player controller) {
    if (hasListener) return;

    controller.playbackStream.listen((playbackState) async {
      // Get the current status
      PlaybackState currentStatus = playbackState;

      // If the status hasn't changed, don't do anything
      status = currentStatus;

      // If the status is playing, remove the overlay
      if (status.isPlaying && showPlayPauseOverlay.value == true) {
        showPlayPauseOverlay.value = false;
      }

      // If the status is ended, restart
      if (status.isCompleted) {
        controller.seek(Duration.zero);
        controller.stop();
        showPlayPauseOverlay.value = true;
      }
    });

    hasListener = true;
  }
}

class DesktopVideoWidget extends StatelessWidget {
  DesktopVideoWidget({Key? key, required this.file, required this.attachment}) : super(key: key);
  final PlatformFile file;
  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DesktopVideoWidgetController>(
      global: false,
      init: DesktopVideoWidgetController(file: file, attachment: attachment, context: context),
      dispose: (state) {
        state.controller?.navigated = true;
      },
      builder: (controller) {
        return VisibilityDetector(
          onVisibilityChanged: (info) {
            if (info.visibleFraction == 0 && controller.isVisible && !controller.navigated) {
              controller.isVisible = false;
              controller.controller?.pause();
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
              child: Obx(
                () => Container(
                  child: !controller.initComplete.value
                      ? buildPlaceHolder(controller, context)
                      : buildPlayer(controller, context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildPlayer(DesktopVideoWidgetController controller, BuildContext context) {
    double width = controller.controller!.videoDimensions.width.toDouble();
    double height = controller.controller!.videoDimensions.height.toDouble();
    return GestureDetector(
      onTap: () async {
        if (controller.controller!.playback.isPlaying) {
          controller.controller!.pause();
        } else {
          controller.navigated = true;
          ChatController? currentChat = ChatManager().activeChat;
          await Navigator.of(context).push(
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
        width: width,
        height: height,
        child: Obx(
          () => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: ns.width(context) / 2,
                  maxHeight: context.height / 2,
                ),
                child: Hero(
                  tag: attachment.guid!,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      AspectRatio(
                        aspectRatio: width / height > 0 ? width / height : 1,
                        child: Obx(
                          () => Video(
                            player: controller.controller!,
                            fillColor: Colors.transparent,
                            showTimeLeft: true,
                            showControls: !controller.showPlayPauseOverlay.value,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (controller.showPlayPauseOverlay.value)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      controller.controller!.setVolume(controller.muted.value ? 0.0 : 1.0);
                      controller.controller!.play();
                      controller.showPlayPauseOverlay.value = false;
                    },
                    child: Container(
                      height: 75,
                      width: 75,
                      decoration: BoxDecoration(
                        color: HexColor('26262a').withOpacity(0.5),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      padding: EdgeInsets.all(10),
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: ss.settings.skin.value == Skins.iOS ? 7 : 0,
                            top: ss.settings.skin.value == Skins.iOS ? 3 : 0),
                        child: Icon(
                          ss.settings.skin.value == Skins.iOS ? CupertinoIcons.play : Icons.play_arrow,
                          color: Colors.white,
                          size: 45,
                        ),
                      ),
                    ),
                  ),
                ),
              if (controller.showPlayPauseOverlay.value)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
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
                            child: Obx(
                              () => Icon(
                                controller.muted.value
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
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPlaceHolder(DesktopVideoWidgetController controller, BuildContext context) {
    return controller.controller != null
        ? buildPlayer(controller, context)
        : AspectRatio(
            aspectRatio: !controller.attachment.hasValidSize
                ? 1
                : controller.attachment.width!.toDouble() / controller.attachment.height!.toDouble(),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  color: context.theme.colorScheme.properSurface,
                  child: null,
                ),
              ],
            ),
          );
  }
}
