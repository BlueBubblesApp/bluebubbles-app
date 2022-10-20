import 'dart:async';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
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
  State<VideoViewer> createState() => _VideoViewerState();
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
    controller.setVolume(ss.settings.startVideosMutedFullscreen.value ? 0 : 1);
    await controller.initialize();
    chewieController = ChewieController(
      videoPlayerController: controller,
      aspectRatio: controller.value.aspectRatio,
      allowFullScreen: false,
      allowMuting: false,
      materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundColor: Theme.of(context).colorScheme.properSurface),
      cupertinoProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
          bufferedColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundColor: Theme.of(context).colorScheme.properSurface),
      customControls: ss.settings.skin.value == Skins.iOS ? null : Stack(
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
                        ss.settings.skin.value == Skins.iOS ? CupertinoIcons.back : Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                  ),
            ),
          ),
        ]
      ),
      additionalOptions: (context) => ss.settings.skin.value == Skins.iOS || !widget.showInteractions ? [] : [
        OptionItem(
          onTap: () async {
            showMetadataDialog();
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: ss.settings.skin.value != Skins.iOS ? Brightness.light : context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        bottomNavigationBar: ss.settings.skin.value != Skins.iOS || !widget.showInteractions ? null : Theme(
          data: context.theme.copyWith(navigationBarTheme: context.theme.navigationBarTheme.copyWith(
            indicatorColor: ss.settings.skin.value == Skins.Samsung ? Colors.black : context.theme.colorScheme.properSurface,
          )),
          child: NavigationBar(
            selectedIndex: 0,
            backgroundColor: ss.settings.skin.value == Skins.Samsung ? Colors.black : context.theme.colorScheme.properSurface,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            height: 60,
            destinations: [
              NavigationDestination(
                  icon: Icon(
                    ss.settings.skin.value == Skins.iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                    color: ss.settings.skin.value == Skins.Samsung ? Colors.white : context.theme.colorScheme.primary,
                  ),
                  label: 'Download'
              ),
              if (!kIsDesktop && !kIsWeb)
                NavigationDestination(
                    icon: Icon(
                      ss.settings.skin.value == Skins.iOS ? CupertinoIcons.share : Icons.share,
                      color: ss.settings.skin.value == Skins.Samsung ? Colors.white : context.theme.colorScheme.primary,
                    ),
                    label: 'Share'
                ),
              NavigationDestination(
                  icon: Icon(
                    ss.settings.skin.value == Skins.iOS ? CupertinoIcons.info : Icons.info,
                    color: context.theme.colorScheme.primary,
                  ),
                  label: 'Metadata'
              ),
              NavigationDestination(
                  icon: Icon(
                    ss.settings.skin.value == Skins.iOS ? CupertinoIcons.refresh : Icons.refresh,
                    color: context.theme.colorScheme.primary,
                  ),
                  label: 'Refresh'
              ),
              NavigationDestination(
                  icon: Icon(
                    controller.value.volume == 0.0
                        ? ss.settings.skin.value == Skins.iOS
                        ? CupertinoIcons.volume_mute
                        : Icons.volume_mute
                        : ss.settings.skin.value == Skins.iOS
                        ? CupertinoIcons.volume_up
                        : Icons.volume_up,
                    color: context.theme.colorScheme.primary,
                  ),
                  label: 'Mute'
              ),
            ],
            onDestinationSelected: (value) async {
              if ((kIsDesktop || kIsWeb) && value > 0) value += 1;
              if (value == 0) {
                await AttachmentHelper.saveToGallery(widget.file);
              } else if (value == 1) {
                if (widget.file.path == null) return;
                Share.file(
                  "Shared ${widget.attachment.mimeType!.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                  widget.file.path!,
                );
              } else if (value == 2) {
                showMetadataDialog();
              } else if (value == 3) {
                refreshAttachment();
              } else if (value == 4) {
                controller.setVolume(controller.value.volume != 0.0 ? 0.0 : 1.0);
                setState(() {});
              }
            },
          ),
        ),
        body: Listener(
            onPointerUp: (_) async {
              if (ss.settings.skin.value == Skins.iOS) {
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
                          data: context.theme.copyWith(
                              platform: ss.settings.skin.value == Skins.iOS
                                  ? TargetPlatform.iOS
                                  : TargetPlatform.android,
                              dialogBackgroundColor: context.theme.colorScheme.properSurface,
                              iconTheme: context.theme
                                  .iconTheme
                                  .copyWith(color: context.theme.textTheme.bodyMedium?.color)),
                          child: Chewie(
                                  controller: chewieController!,
                                ),
                        ),
                      ),
                    );
                  } else {
                    return Center(
                      child: CircularProgressIndicator(
                        backgroundColor: context.theme.colorScheme.properSurface,
                        valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                      ),
                    );
                  }
                }),
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

  void showMetadataDialog() {
    List<Widget> metaWidgets = [];
    final metadataMap = <String, dynamic>{
      'filename': widget.attachment.transferName,
      'mime': widget.attachment.mimeType,
    }..addAll(widget.attachment.metadata ?? {});
    for (var entry in metadataMap.entries.where((element) => element.value != null)) {
      metaWidgets.add(RichText(
          text: TextSpan(children: [
            TextSpan(
                text: "${entry.key}: ",
                style: Theme.of(context).textTheme.bodyLarge!.apply(fontWeightDelta: 2)),
            TextSpan(text: entry.value.toString(), style: Theme.of(context).textTheme.bodyLarge)
          ])));
    }

    if (metaWidgets.isEmpty) {
      metaWidgets.add(Text(
        "No metadata available",
        style: context.theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ));
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Metadata",
          style: context.theme.textTheme.titleLarge,
        ),
        backgroundColor: context.theme.colorScheme.properSurface,
        content: SizedBox(
          width: ns.width(context) * 3 / 5,
          height: context.height * 1 / 4,
          child: Container(
            padding: EdgeInsets.all(10.0),
            decoration: BoxDecoration(
                color: context.theme.backgroundColor,
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
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void refreshAttachment() {
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
      controller.setVolume(ss.settings.startVideosMutedFullscreen.value ? 0 : 1);
      chewieController = ChewieController(
        videoPlayerController: controller,
        aspectRatio: controller.value.aspectRatio,
        allowFullScreen: false,
        allowMuting: false,
        materialProgressColors: ChewieProgressColors(
            playedColor: Theme.of(context).colorScheme.primary,
            handleColor: Theme.of(context).colorScheme.primary,
            bufferedColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundColor: Theme.of(context).colorScheme.properSurface),
        cupertinoProgressColors: ChewieProgressColors(
            playedColor: Theme.of(context).colorScheme.primary,
            handleColor: Theme.of(context).colorScheme.primary,
            bufferedColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundColor: Theme.of(context).colorScheme.properSurface),
      );
      createListener(controller);
      showPlayPauseOverlay = !controller.value.isPlaying;
    }, onError: () {
      Navigator.pop(context);
    });
    if (mounted) setState(() {});
  }
}
