import 'dart:async';

import 'package:bluebubbles/app/layouts/fullscreen_media/dialogs/metadata_dialog.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:chewie/chewie.dart';

// (needed for custom back button)
//ignore: implementation_imports
import 'package:chewie/src/notifiers/index.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

class FullscreenVideo extends StatefulWidget {
  FullscreenVideo({
    Key? key,
    required this.file,
    required this.attachment,
    required this.showInteractions,
  }) : super(key: key);

  final PlatformFile file;
  final Attachment attachment;
  final bool showInteractions;

  @override
  OptimizedState createState() => kIsDesktop ? _DesktopFullscreenVideoState() : _FullscreenVideoState();
}

class _FullscreenVideoState extends OptimizedState<FullscreenVideo> with AutomaticKeepAliveClientMixin {
  bool showPlayPauseOverlay = false;
  Timer? hideOverlayTimer;
  late VideoPlayerController controller;
  late ChewieController chewieController;
  PlayerStatus status = PlayerStatus.NONE;
  bool hasListener = false;
  Uint8List? thumbnail;
  bool hasError = false;
  final RxBool isReloading = true.obs;
  final RxBool muted = ss.settings.startVideosMutedFullscreen.value.obs;

  @override
  void initState() {
    super.initState();
    initControllers();
  }

  void togglePlayPauseOverlay(bool toggle) {
    if (!mounted) return;
    if (toggle != showPlayPauseOverlay) {
      setState(() {
        showPlayPauseOverlay = toggle;
      });
    }

    // eventDispatcher.emit('overlay-toggle', toggle);
  }

  void initControllers() async {
    if (kIsWeb || widget.file.path == null) {
      final blob = html.Blob([widget.file.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      controller = VideoPlayerController.network(url);
    } else {
      dynamic file = File(widget.file.path!);
      controller = VideoPlayerController.file(file);
    }
    controller.setVolume(muted.value ? 0 : 1);
    await controller.initialize();
    chewieController = makeController();
    createListener(controller);
    togglePlayPauseOverlay(!controller.value.isPlaying);
    isReloading.value = false;
  }

  ChewieController makeController() {
    return ChewieController(
        videoPlayerController: controller,
        aspectRatio: controller.value.aspectRatio,
        allowFullScreen: false,
        allowMuting: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: context.theme.colorScheme.primary,
          handleColor: context.theme.colorScheme.primary,
          bufferedColor: context.theme.colorScheme.primaryContainer,
          backgroundColor: context.theme.colorScheme.properSurface,
        ),
        cupertinoProgressColors: ChewieProgressColors(
            playedColor: context.theme.colorScheme.primary,
            handleColor: context.theme.colorScheme.primary,
            bufferedColor: context.theme.colorScheme.primaryContainer,
            backgroundColor: context.theme.colorScheme.properSurface),
        customControls: iOS
            ? null
            : Stack(children: [
                const Positioned.fill(child: MaterialControls()),
                Positioned(
                  top: 0,
                  left: 5,
                  child: Consumer<PlayerNotifier>(builder: (BuildContext context, PlayerNotifier notifier, Widget? widget) {
                    return AnimatedOpacity(
                      opacity: notifier.hideStuff ? 0.0 : 0.8,
                      duration: const Duration(
                        milliseconds: 250,
                      ),
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        onPressed: () async {
                          Navigator.pop(context);
                        },
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }),
                ),
              ]),
        additionalOptions: (context) => iOS || !widget.showInteractions
            ? []
            : [
                OptionItem(
                  onTap: () async {
                    showMetadataDialog(widget.attachment, context);
                  },
                  iconData: Icons.info,
                  title: 'Metadata',
                ),
                OptionItem(
                  onTap: () async {
                    Navigator.pop(context);
                    refreshAttachment();
                  },
                  iconData: Icons.refresh,
                  title: 'Redownload attachment',
                ),
                OptionItem(
                  onTap: () async {
                    Navigator.pop(context);
                    await as.saveToDisk(widget.file);
                  },
                  iconData: Icons.download,
                  title: 'Save to gallery',
                ),
                if (!kIsWeb && !kIsDesktop)
                  OptionItem(
                    onTap: () async {
                      Navigator.pop(context);
                      if (widget.file.path == null) return;
                      Share.file(
                        "Shared ${widget.attachment.mimeType!.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                        widget.file.path!,
                      );
                    },
                    iconData: Icons.share,
                    title: 'Share',
                  ),
                OptionItem(
                  onTap: () async {
                    Navigator.pop(context);
                    controller.setVolume(controller.value.volume != 0.0 ? 0.0 : 1.0);
                  },
                  iconData: controller.value.volume == 0.0 ? Icons.volume_up : Icons.volume_mute,
                  title: controller.value.volume == 0.0 ? 'Unmute' : 'Mute',
                ),
              ]);
  }

  void createListener(VideoPlayerController controller) {
    if (hasListener) return;
    controller.addListener(() async {
      // Get the current status
      PlayerStatus currentStatus = getControllerStatus(controller);
      // If the status hasn't changed, don't do anything
      if (currentStatus == status) return;
      status = currentStatus;
      // If the status is ended, restart
      if (status == PlayerStatus.ENDED) {
        togglePlayPauseOverlay(true);
        await controller.pause();
        await controller.seekTo(const Duration());
      }
    });
    hasListener = true;
  }

  @override
  void dispose() {
    hideOverlayTimer?.cancel();
    print("ON DISPOSE");
    controller.dispose();
    chewieController.dispose();
    super.dispose();
  }

  void refreshAttachment() {
    isReloading.value = true;
    showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
    as.redownloadAttachment(widget.attachment, onComplete: (file) async {
      controller.dispose();
      chewieController.dispose();
      hasListener = false;
      if (kIsWeb || file.path == null) {
        final blob = html.Blob([file.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        controller = VideoPlayerController.network(url);
      } else {
        dynamic _file = File(file.path!);
        controller = VideoPlayerController.file(_file);
      }
      await controller.initialize();
      isReloading.value = false;
      controller.setVolume(muted.value ? 0 : 1);
      chewieController = makeController();
      createListener(controller);
      togglePlayPauseOverlay(!controller.value.isPlaying);
    }, onError: () {
      setState(() {
        hasError = true;
      });
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: !showPlayPauseOverlay || !iOS || !widget.showInteractions
          ? null
          : Theme(
              data: context.theme.copyWith(
                navigationBarTheme: context.theme.navigationBarTheme.copyWith(
                  indicatorColor: samsung ? Colors.black : context.theme.colorScheme.properSurface,
                ),
              ),
              child: NavigationBar(
                selectedIndex: 0,
                backgroundColor: samsung ? Colors.black : context.theme.colorScheme.properSurface,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                elevation: 0,
                height: 60,
                destinations: [
                  NavigationDestination(
                      icon: Icon(
                        iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                        color: samsung ? Colors.white : context.theme.colorScheme.primary,
                      ),
                      label: 'Download'),
                  NavigationDestination(
                      icon: Icon(
                        iOS ? CupertinoIcons.info : Icons.info,
                        color: context.theme.colorScheme.primary,
                      ),
                      label: 'Metadata'),
                  NavigationDestination(
                      icon: Icon(
                        iOS ? CupertinoIcons.refresh : Icons.refresh,
                        color: context.theme.colorScheme.primary,
                      ),
                      label: 'Refresh'),
                  NavigationDestination(
                      icon: Icon(
                        controller.value.volume == 0.0
                            ? iOS
                                ? CupertinoIcons.volume_mute
                                : Icons.volume_mute
                            : iOS
                                ? CupertinoIcons.volume_up
                                : Icons.volume_up,
                        color: context.theme.colorScheme.primary,
                      ),
                      label: 'Mute'),
                  if (!kIsDesktop && !kIsWeb)
                    NavigationDestination(
                        icon: Icon(
                          iOS ? CupertinoIcons.share : Icons.share,
                          color: samsung ? Colors.white : context.theme.colorScheme.primary,
                        ),
                        label: 'Share'),
                ],
                onDestinationSelected: (value) async {
                  if (value == 0) {
                    await as.saveToDisk(widget.file);
                  } else if (value == 1) {
                    showMetadataDialog(widget.attachment, context);
                  } else if (value == 2) {
                    refreshAttachment();
                  } else if (value == 3) {
                    controller.setVolume(controller.value.volume != 0.0 ? 0.0 : 1.0);
                    setState(() {});
                  } else if (value == 4) {
                    if (widget.file.path == null) return;
                    Share.file(
                      "Shared ${widget.attachment.mimeType!.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                      widget.file.path!,
                    );
                  }
                },
              ),
            ),
      body: Listener(
        onPointerUp: (_) async {
          if (iOS) {
            togglePlayPauseOverlay(true);
            if (hideOverlayTimer?.isActive ?? false) hideOverlayTimer?.cancel();
            hideOverlayTimer = Timer(const Duration(seconds: 3), () {
              if (!controller.value.isPlaying) return;
              togglePlayPauseOverlay(false);
            });
          }
        },
        child: Obx(() {
          if (!isReloading.value) {
            return SafeArea(
              child: Center(
                child: Theme(
                  data: context.theme.copyWith(
                      platform: iOS ? TargetPlatform.iOS : TargetPlatform.android,
                      dialogBackgroundColor: context.theme.colorScheme.properSurface,
                      iconTheme: context.theme.iconTheme.copyWith(color: context.theme.textTheme.bodyMedium?.color)),
                  child: Chewie(controller: chewieController),
                ),
              ),
            );
          } else if (hasError) {
            return Center(child: Text("Failed to load video", style: context.theme.textTheme.bodyLarge));
          } else {
            return Center(
              child: buildProgressIndicator(context),
            );
          }
        }),
      ),
    );
  }
}

class _DesktopFullscreenVideoState extends OptimizedState<FullscreenVideo> with AutomaticKeepAliveClientMixin {
  Timer? hideOverlayTimer;

  late Player player;
  late VideoController videoController;

  bool hasListener = false;
  bool hasDisposed = false;
  final RxBool muted = ss.settings.startVideosMutedFullscreen.value.obs;
  final RxBool showPlayPauseOverlay = true.obs;
  final RxDouble aspectRatio = 1.0.obs;

  @override
  void initState() {
    super.initState();
    initControllers();
  }

  void initControllers() async {
    player = Player();
    videoController = VideoController(player);

    late final Media media;
    if (widget.file.path == null) {
      final blob = html.Blob([widget.file.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      media = Media(url);
    } else {
      media = Media(widget.file.path!);
    }
    
    await player.setPlaylistMode(PlaylistMode.none);
    await player.open(media, play: false);
    await player.setVolume(muted.value ? 0 : 100);
    createListener(videoController, player);
    showPlayPauseOverlay.value = true;
    setState(() {});
  }

  void createListener(VideoController controller, Player player) {
    if (hasListener) return;
    controller.rect.addListener(() {
      aspectRatio.value = controller.aspectRatio;
    });
    player.streams.completed.listen((completed) async {
      // If the status is ended, restart
      if (completed && !hasDisposed) {
        await player.pause();
        await player.seek(Duration.zero);
        showPlayPauseOverlay.value = true;
      }
    });
    hasListener = true;
  }

  @override
  void dispose() {
    hasDisposed = true;
    hideOverlayTimer?.cancel();
    player.dispose();
    super.dispose();
  }

  void refreshAttachment() {
    showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
    as.redownloadAttachment(widget.attachment, onComplete: (file) async {
      if (hasDisposed) return;
      hasListener = false;
      late final Media media;
      if (widget.file.path == null) {
        final blob = html.Blob([widget.file.bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        media = Media(url);
      } else {
        media = Media(widget.file.path!);
      }
      await player.open(media, play: false);
      await player.setVolume(muted.value ? 0 : 100);
      createListener(videoController, player);
      showPlayPauseOverlay.value = !player.state.playing;
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final RxBool _hover = false.obs;
    return Obx(
      () => Scaffold(
        backgroundColor: Colors.black,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        bottomNavigationBar: !iOS || !widget.showInteractions
            ? null
            : Theme(
                data: context.theme.copyWith(
                  navigationBarTheme: context.theme.navigationBarTheme.copyWith(
                    indicatorColor: samsung ? Colors.black : context.theme.colorScheme.properSurface,
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: 0,
                  backgroundColor: samsung ? Colors.black : context.theme.colorScheme.properSurface,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  elevation: 0,
                  height: 60,
                  destinations: [
                    NavigationDestination(
                        icon: Icon(
                          iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                          color: samsung ? Colors.white : context.theme.colorScheme.primary,
                        ),
                        label: 'Download'),
                    NavigationDestination(
                        icon: Icon(
                          iOS ? CupertinoIcons.info : Icons.info,
                          color: context.theme.colorScheme.primary,
                        ),
                        label: 'Metadata'),
                    NavigationDestination(
                        icon: Icon(
                          iOS ? CupertinoIcons.refresh : Icons.refresh,
                          color: context.theme.colorScheme.primary,
                        ),
                        label: 'Refresh'),
                    NavigationDestination(
                        icon: Icon(
                          player.state.volume == 0.0
                              ? iOS
                                  ? CupertinoIcons.volume_mute
                                  : Icons.volume_mute
                              : iOS
                                  ? CupertinoIcons.volume_up
                                  : Icons.volume_up,
                          color: context.theme.colorScheme.primary,
                        ),
                        label: 'Mute'),
                  ],
                  onDestinationSelected: (value) async {
                    if (value == 0) {
                      await as.saveToDisk(widget.file);
                    } else if (value == 1) {
                      showMetadataDialog(widget.attachment, context);
                    } else if (value == 2) {
                      refreshAttachment();
                    } else if (value == 3) {
                      await player.setVolume(player.state.volume != 0.0 ? 0.0 : 100.0);
                      setState(() {});
                    }
                  },
                ),
              ),
        body: MouseRegion(
          onEnter: (event) => showPlayPauseOverlay.value = true,
          onExit: (event) => showPlayPauseOverlay.value = !player.state.playing,
          child: Obx(() {
            return SafeArea(
              child: Center(
                child: Theme(
                  data: context.theme.copyWith(
                      platform: iOS ? TargetPlatform.iOS : TargetPlatform.android,
                      dialogBackgroundColor: context.theme.colorScheme.properSurface,
                      iconTheme: context.theme.iconTheme.copyWith(color: context.theme.textTheme.bodyMedium?.color)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Video(controller: videoController),
                      Obx(() {
                        return MouseRegion(
                          onEnter: (event) => _hover.value = true,
                          onExit: (event) => _hover.value = false,
                          child: AbsorbPointer(
                            absorbing: !showPlayPauseOverlay.value && !_hover.value,
                            child: AnimatedOpacity(
                              opacity: _hover.value
                                  ? 1
                                  : showPlayPauseOverlay.value
                                      ? 0.5
                                      : 0,
                              duration: const Duration(milliseconds: 100),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(40),
                                  onTap: () async {
                                    if (player.state.playing) {
                                      await player.pause();
                                      showPlayPauseOverlay.value = true;
                                    } else {
                                      await player.play();
                                      showPlayPauseOverlay.value = false;
                                    }
                                  },
                                  child: Container(
                                    height: 75,
                                    width: 75,
                                    decoration: BoxDecoration(
                                      color: context.theme.colorScheme.background.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: ss.settings.skin.value == Skins.iOS && !player.state.playing ? 17 : 10,
                                        top: ss.settings.skin.value == Skins.iOS ? 13 : 10,
                                        right: 10,
                                        bottom: 10,
                                      ),
                                      child: Obx(
                                        () => player.state.playing
                                            ? Icon(
                                                ss.settings.skin.value == Skins.iOS ? CupertinoIcons.pause : Icons.pause,
                                                color: context.iconColor,
                                                size: 45,
                                              )
                                            : Icon(
                                                ss.settings.skin.value == Skins.iOS ? CupertinoIcons.play : Icons.play_arrow,
                                                color: context.iconColor,
                                                size: 45,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
