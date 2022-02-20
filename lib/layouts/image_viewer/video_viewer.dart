import 'dart:async';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:chewie/chewie.dart';
// (needed for custom back button)
//ignore: implementation_imports
import 'package:chewie/src/notifiers/index.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:video_player/video_player.dart';

class VideoViewer extends StatefulWidget {
  VideoViewer({Key? key, required this.file, required this.attachment, required this.showInteractions})
      : super(key: key);
  final PlatformFile file;
  final Attachment attachment;
  final bool showInteractions;

  @override
  _VideoViewerState createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  bool showPlayPauseOverlay = false;
  Timer? hideOverlayTimer;
  late VideoPlayerController controller;
  ChewieController? chewieController;
  PlayerStatus status = PlayerStatus.NONE;
  bool hasListener = false;
  final RxBool isReloading = false.obs;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    initControllers();
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
    controller.setVolume(SettingsManager().settings.startVideosMutedFullscreen.value ? 0 : 1);
    await controller.initialize();
    chewieController = ChewieController(
      videoPlayerController: controller,
      aspectRatio: controller.value.aspectRatio,
      allowFullScreen: false,
      allowMuting: false,
      materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).primaryColor,
          handleColor: Theme.of(context).primaryColor,
          bufferedColor: Theme.of(context).backgroundColor,
          backgroundColor: Theme.of(context).disabledColor),
      cupertinoProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).primaryColor,
          handleColor: Theme.of(context).primaryColor,
          bufferedColor: Theme.of(context).backgroundColor,
          backgroundColor: Theme.of(context).disabledColor),
      customControls: SettingsManager().settings.skin.value == Skins.iOS ? null : Stack(
        children: [
          Positioned.fill(child: MaterialControls()),
          Positioned(
            top: 0,
            left: 5,
            child: Consumer<PlayerNotifier>(
              builder: (
                  BuildContext context,
                  PlayerNotifier notifier,
                  Widget? widget,
                  ) =>
                  AnimatedOpacity(
                    opacity: notifier.hideStuff ? 0.0 : 0.8,
                    duration: const Duration(
                      milliseconds: 250,
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      onPressed: () async {
                        Navigator.pop(context);
                      },
                      child: Icon(
                        SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.back : Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                  ),
            ),
          ),
        ]
      ),
      additionalOptions: (context) => SettingsManager().settings.skin.value == Skins.iOS ? [] : [
        OptionItem(
          onTap: () async {
            List<Widget> metaWidgets = [];
            for (var entry in widget.attachment.metadata?.entries ?? {}.entries) {
              metaWidgets.add(RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: "${entry.key}: ",
                        style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2)),
                    TextSpan(text: entry.value.toString(), style: Theme.of(context).textTheme.bodyText1)
                  ])));
            }

            if (metaWidgets.isEmpty) {
              metaWidgets.add(Text(
                "No metadata available",
                style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2),
                textAlign: TextAlign.center,
              ));
            }

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  "Metadata",
                  style: Theme.of(context).textTheme.headline1,
                  textAlign: TextAlign.center,
                ),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                content: SizedBox(
                  width: CustomNavigator.width(context) * 3 / 5,
                  height: context.height * 1 / 4,
                  child: Container(
                    padding: EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                        color: Theme.of(context).backgroundColor,
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                    child: ListView(
                      physics: AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: metaWidgets,
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    child: Text(
                      "Close",
                      style: Theme.of(context).textTheme.bodyText1!.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            );
          },
          iconData: Icons.info,
          title: 'Metadata',
        ),
        OptionItem(
          onTap: () async {
            Navigator.pop(context);
            isReloading.value = true;
            ChatManager().activeChat?.clearImageData(widget.attachment);

            showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
            AttachmentHelper.redownloadAttachment(widget.attachment, onComplete: () async {
              controller.dispose();
              chewieController?.dispose();
              if (kIsWeb || widget.file.path == null) {
                final blob = html.Blob([widget.file.bytes]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                controller = VideoPlayerController.network(url);
              } else {
                dynamic file = File(widget.file.path!);
                controller = VideoPlayerController.file(file);
              }
              await controller.initialize();
              isReloading.value = false;
              controller.setVolume(SettingsManager().settings.startVideosMutedFullscreen.value ? 0 : 1);
              chewieController = ChewieController(
                videoPlayerController: controller,
                aspectRatio: controller.value.aspectRatio,
                allowFullScreen: false,
                allowMuting: false,
                materialProgressColors: ChewieProgressColors(
                    playedColor: Theme.of(context).primaryColor,
                    handleColor: Theme.of(context).primaryColor,
                    bufferedColor: Theme.of(context).backgroundColor,
                    backgroundColor: Theme.of(context).disabledColor),
                cupertinoProgressColors: ChewieProgressColors(
                    playedColor: Theme.of(context).primaryColor,
                    handleColor: Theme.of(context).primaryColor,
                    bufferedColor: Theme.of(context).backgroundColor,
                    backgroundColor: Theme.of(context).disabledColor),
              );
              createListener(controller);
              showPlayPauseOverlay = !controller.value.isPlaying;
            }, onError: () {
              Navigator.pop(context);
            });
            if (mounted) setState(() {});
          },
          iconData: Icons.refresh,
          title: 'Redownload attachment',
        ),
        OptionItem(
          onTap: () async {
            Navigator.pop(context);
            await AttachmentHelper.saveToGallery(widget.file);
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
          iconData: controller.value.volume == 0.0
              ? Icons.volume_up
              : Icons.volume_mute,
          title: controller.value.volume == 0.0 ? 'Unmute' : 'Mute',
        ),
      ]
    );
    createListener(controller);
    showPlayPauseOverlay = !controller.value.isPlaying;
    if (mounted) setState(() {});
  }

  void createListener(VideoPlayerController? controller) {
    if (controller == null || hasListener) return;

    controller.addListener(() async {
      // Get the current status
      PlayerStatus currentStatus = await getControllerStatus(controller);

      // If the status hasn't changed, don't do anything
      if (currentStatus == status) return;
      status = currentStatus;

      // If the status is ended, restart
      if (status == PlayerStatus.ENDED) {
        showPlayPauseOverlay = true;
        await controller.pause();
        await controller.seekTo(Duration());
      }

      if (mounted) setState(() {});
    });

    hasListener = true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget overlay = AnimatedOpacity(
      opacity: showPlayPauseOverlay ? 1.0 : 0.0,
      duration: Duration(milliseconds: 125),
      child: Container(
          height: 150.0,
          width: CustomNavigator.width(context),
          color: Colors.black.withOpacity(0.65),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Padding(
              padding: EdgeInsets.only(top: 40.0, left: 5),
              child: CupertinoButton(
                padding: EdgeInsets.symmetric(horizontal: 5),
                onPressed: () async {
                  Navigator.pop(context);
                },
                child: Icon(
                  SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.back : Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      List<Widget> metaWidgets = [];
                      for (var entry in widget.attachment.metadata?.entries ?? {}.entries) {
                        metaWidgets.add(RichText(
                            text: TextSpan(children: [
                          TextSpan(
                              text: "${entry.key}: ",
                              style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2)),
                          TextSpan(text: entry.value.toString(), style: Theme.of(context).textTheme.bodyText1)
                        ])));
                      }

                      if (metaWidgets.isEmpty) {
                        metaWidgets.add(Text(
                          "No metadata available",
                          style: Theme.of(context).textTheme.bodyText1!.apply(fontWeightDelta: 2),
                          textAlign: TextAlign.center,
                        ));
                      }

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            "Metadata",
                            style: Theme.of(context).textTheme.headline1,
                            textAlign: TextAlign.center,
                          ),
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          content: SizedBox(
                            width: CustomNavigator.width(context) * 3 / 5,
                            height: context.height * 1 / 4,
                            child: Container(
                              padding: EdgeInsets.all(10.0),
                              decoration: BoxDecoration(
                                  color: Theme.of(context).backgroundColor,
                                  borderRadius: BorderRadius.all(Radius.circular(10))),
                              child: ListView(
                                physics: AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                children: metaWidgets,
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: Text(
                                "Close",
                                style: Theme.of(context).textTheme.bodyText1!.copyWith(
                                      color: Theme.of(context).primaryColor,
                                    ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Icon(
                      SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.info : Icons.info,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      isReloading.value = true;
                      ChatManager().activeChat?.clearImageData(widget.attachment);

                      showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
                      AttachmentHelper.redownloadAttachment(widget.attachment, onComplete: () async {
                        controller.dispose();
                        chewieController?.dispose();
                        if (kIsWeb || widget.file.path == null) {
                          final blob = html.Blob([widget.file.bytes]);
                          final url = html.Url.createObjectUrlFromBlob(blob);
                          controller = VideoPlayerController.network(url);
                        } else {
                          dynamic file = File(widget.file.path!);
                          controller = VideoPlayerController.file(file);
                        }
                        await controller.initialize();
                        isReloading.value = false;
                        controller.setVolume(SettingsManager().settings.startVideosMutedFullscreen.value ? 0 : 1);
                        chewieController = ChewieController(
                          videoPlayerController: controller,
                          aspectRatio: controller.value.aspectRatio,
                          allowFullScreen: false,
                          allowMuting: false,
                          materialProgressColors: ChewieProgressColors(
                              playedColor: Theme.of(context).primaryColor,
                              handleColor: Theme.of(context).primaryColor,
                              bufferedColor: Theme.of(context).backgroundColor,
                              backgroundColor: Theme.of(context).disabledColor),
                          cupertinoProgressColors: ChewieProgressColors(
                              playedColor: Theme.of(context).primaryColor,
                              handleColor: Theme.of(context).primaryColor,
                              bufferedColor: Theme.of(context).backgroundColor,
                              backgroundColor: Theme.of(context).disabledColor),
                        );
                        createListener(controller);
                        showPlayPauseOverlay = !controller.value.isPlaying;
                      }, onError: () {
                        Navigator.pop(context);
                      });
                      if (mounted) setState(() {});
                    },
                    child: Icon(
                      SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.refresh : Icons.refresh,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      await AttachmentHelper.saveToGallery(widget.file);
                    },
                    child: Icon(
                      SettingsManager().settings.skin.value == Skins.iOS
                          ? CupertinoIcons.cloud_download
                          : Icons.file_download,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!kIsWeb && !kIsDesktop)
                  Padding(
                    padding: EdgeInsets.only(top: 40.0),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      onPressed: () async {
                        if (widget.file.path == null) return;
                        Share.file(
                          "Shared ${widget.attachment.mimeType!.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                          widget.file.path!,
                        );
                      },
                      child: Icon(
                        SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.share : Icons.share,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: CupertinoButton(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    onPressed: () async {
                      controller.setVolume(controller.value.volume != 0.0 ? 0.0 : 1.0);
                    },
                    child: Icon(
                      controller.value.volume == 0.0
                          ? SettingsManager().settings.skin.value == Skins.iOS
                              ? CupertinoIcons.volume_mute
                              : Icons.volume_mute
                          : SettingsManager().settings.skin.value == Skins.iOS
                              ? CupertinoIcons.volume_up
                              : Icons.volume_up,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ])),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        body: Listener(
            onPointerUp: (_) async {
              if (SettingsManager().settings.skin.value == Skins.iOS) {
                setState(() {
                  showPlayPauseOverlay = true;
                });
                debounceOverlay();
              }
            },
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                Obx(() {
                  if (!isReloading.value && chewieController != null) {
                    return SafeArea(
                      child: Center(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                              platform: SettingsManager().settings.skin.value == Skins.iOS
                                  ? TargetPlatform.iOS
                                  : TargetPlatform.android,
                              dialogBackgroundColor: Theme.of(context).colorScheme.secondary,
                              iconTheme: Theme.of(context)
                                  .iconTheme
                                  .copyWith(color: Theme.of(context).textTheme.bodyText1?.color)),
                          child: Chewie(
                                  controller: chewieController!,
                                ),
                        ),
                      ),
                    );
                  } else {
                    return Center(
                      child: CircularProgressIndicator(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                      ),
                    );
                  }
                }),
                if (widget.showInteractions && SettingsManager().settings.skin.value == Skins.iOS)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: AbsorbPointer(absorbing: !showPlayPauseOverlay, child: overlay),
                  ),
              ],
            )),
      ),
    );
  }

  debounceOverlay() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      setState(() {
        showPlayPauseOverlay = false;
      });
    });
  }
}
