import 'dart:async';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:photo_view/photo_view.dart';
import 'package:universal_io/io.dart';

class ImageViewer extends StatefulWidget {
  ImageViewer({
    Key? key,
    required this.file,
    required this.attachment,
    required this.showInteractions,
  }) : super(key: key);
  final PlatformFile file;
  final Attachment attachment;
  final bool showInteractions;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> with AutomaticKeepAliveClientMixin {
  double top = 0;
  int duration = 0;
  late PhotoViewController controller;
  bool showOverlay = true;
  Uint8List? bytes;

  @override
  void initState() {
    super.initState();
    controller = PhotoViewController();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    initBytes();
  }

  Future<void> initBytes() async {
    if (kIsWeb || widget.file.path == null) {
      bytes = widget.file.bytes;
    } else if (widget.attachment.mimeType == "image/heic"
        || widget.attachment.mimeType == "image/heif"
        || widget.attachment.mimeType == "image/tif"
        || widget.attachment.mimeType == "image/tiff") {
      bytes =
          await AttachmentHelper.compressAttachment(widget.attachment, widget.file.path!, qualityOverride: 100);
    } else {
      bytes = await File(widget.file.path!).readAsBytes();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Widget overlay = AnimatedOpacity(
      opacity: showOverlay ? 1.0 : 0.0,
      duration: Duration(milliseconds: 125),
      child: Container(
        height: kIsDesktop ? 50 : 100.0,
        width: navigatorService.width(context),
        color: context.theme.colorScheme.shadow.withOpacity(settings.settings.skin.value == Skins.Samsung ? 1 : 0.65),
        child: SafeArea(
          left: false,
          right: false,
          bottom: false,
          child: Container(
            height: 50,
            child: Row(mainAxisAlignment: kIsDesktop ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween, children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 5),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      onPressed: () async {
                        Navigator.pop(context);
                      },
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (widget.showInteractions)
                    Padding(
                      padding: const EdgeInsets.only(left: 5.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.attachment.message.target?.handle?.displayName ?? "", style: context.theme.textTheme.titleLarge!.copyWith(color: Colors.white)),
                          if (widget.attachment.message.target?.dateCreated != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(settings.settings.skin.value == Skins.Samsung ? intl.DateFormat.jm().add_MMMd().format(widget.attachment.message.target!.dateCreated!) : intl.DateFormat('EEE').add_jm().format(widget.attachment.message.target!.dateCreated!),
                                  style: context.theme.textTheme.bodyLarge!.copyWith(color: settings.settings.skin.value == Skins.Samsung ? Colors.grey : Colors.white)),
                            ),
                        ],
                      ),
                    )
                ],
              ),
              !widget.showInteractions ? SizedBox.shrink() : Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      onPressed: () async {
                        showMetadataDialog();
                      },
                      child: Icon(
                        Icons.info_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      onPressed: () async {
                        refreshAttachment();
                      },
                      child: Icon(
                        Icons.refresh,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );

    var loader = Center(
      child: CircularProgressIndicator(
        backgroundColor: context.theme.colorScheme.properSurface,
        valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: settings.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: settings.settings.skin.value != Skins.iOS ? Brightness.light : context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: widget.showInteractions && showOverlay && settings.settings.skin.value == Skins.Material ? Row(
          children: [
            FloatingActionButton(
              backgroundColor: context.theme.colorScheme.secondary,
              child: Icon(
                Icons.file_download_outlined,
                color: context.theme.colorScheme.onSecondary,
              ),
              onPressed: () async {
                await AttachmentHelper.saveToGallery(widget.file);
              },
            ),
            if (!kIsWeb && !kIsDesktop)
              Padding(
                padding: const EdgeInsets.only(left: 20.0),
                child: FloatingActionButton(
                  backgroundColor: context.theme.colorScheme.secondary,
                  child: Icon(
                    Icons.share_outlined,
                    color: context.theme.colorScheme.onSecondary,
                  ),
                  onPressed: () async {
                    if (widget.file.path == null) return showSnackbar("Error", "Failed to find a path to share attachment!");
                    Share.file(
                      "Shared ${widget.attachment.mimeType!.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                      widget.file.path!,
                    );
                  },
                ),
              ),
          ],
        ) : null,
        bottomNavigationBar: !widget.showInteractions || settings.settings.skin.value == Skins.Material
            || (settings.settings.skin.value == Skins.Samsung && !showOverlay) ? null : Theme(
          data: context.theme.copyWith(navigationBarTheme: context.theme.navigationBarTheme.copyWith(
              indicatorColor: settings.settings.skin.value == Skins.Samsung ? Colors.black : context.theme.colorScheme.properSurface,
          )),
          child: NavigationBar(
            selectedIndex: 0,
            backgroundColor: settings.settings.skin.value == Skins.Samsung ? Colors.black : context.theme.colorScheme.properSurface,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            height: 60,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  settings.settings.skin.value == Skins.iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                  color: settings.settings.skin.value == Skins.Samsung ? Colors.white : context.theme.colorScheme.primary,
                ),
                label: 'Download'
              ),
              if (!kIsWeb && !kIsDesktop)
                NavigationDestination(
                  icon: Icon(
                    settings.settings.skin.value == Skins.iOS ? CupertinoIcons.share : Icons.share,
                    color: settings.settings.skin.value == Skins.Samsung ? Colors.white : context.theme.colorScheme.primary,
                  ),
                  label: 'Share'
                ),
              if (settings.settings.skin.value == Skins.iOS)
                NavigationDestination(
                    icon: Icon(
                      settings.settings.skin.value == Skins.iOS ? CupertinoIcons.info : Icons.info,
                      color: context.theme.colorScheme.primary,
                    ),
                    label: 'Metadata'
                ),
              if (settings.settings.skin.value == Skins.iOS)
                NavigationDestination(
                    icon: Icon(
                      settings.settings.skin.value == Skins.iOS ? CupertinoIcons.refresh : Icons.refresh,
                      color: context.theme.colorScheme.primary,
                    ),
                    label: 'Refresh'
                ),
            ],
            onDestinationSelected: (value) async {
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
              }
            },
          ),
        ),
        body: GestureDetector(
          onTap: () {
            if (!mounted || !widget.showInteractions) return;

            setState(() {
              showOverlay = !showOverlay;
            });
          },
          child: Stack(
            children: [
              bytes != null
                  ? PhotoView(
                  gaplessPlayback: true,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.contained * 13,
                  controller: controller,
                  imageProvider: MemoryImage(bytes!),
                  loadingBuilder: (BuildContext context, ImageChunkEvent? ev) {
                    return loader;
                  },
                  scaleStateChangedCallback: (scale) {
                    if (AttachmentFullscreenViewer.of(context) == null) return;
                    if (mounted) {
                      AttachmentFullscreenViewerState? state = AttachmentFullscreenViewer.of(context);
                      if (scale == PhotoViewScaleState.zoomedIn
                          || scale == PhotoViewScaleState.covering
                          || scale == PhotoViewScaleState.originalSize) {
                        if (state!.physics != NeverScrollableScrollPhysics()) {
                          AttachmentFullscreenViewer.of(context)!.setState(() {
                            AttachmentFullscreenViewer.of(context)!.physics = NeverScrollableScrollPhysics();
                          });
                        }
                      } else {
                        if (state!.physics != ThemeSwitcher.getScrollPhysics()) {
                          AttachmentFullscreenViewer.of(context)!.setState(() {
                            AttachmentFullscreenViewer.of(context)!.physics = ThemeSwitcher.getScrollPhysics();
                          });
                        }
                      }
                    }
                  },
                  errorBuilder: (context, object, stacktrace) => Center(
                      child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge)))
                  : loader,
              if (settings.settings.skin.value != Skins.iOS) overlay
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

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
          width: navigatorService.width(context) * 3 / 5,
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
    ChatManager().activeChat?.clearImageData(widget.attachment);

    showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
    AttachmentHelper.redownloadAttachment(widget.attachment, onComplete: () {
      initBytes();
    }, onError: () {
      Navigator.pop(context);
    });

    bytes = null;
    if (mounted) setState(() {});
  }
}
