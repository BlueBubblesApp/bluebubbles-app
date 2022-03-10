import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
  _ImageViewerState createState() => _ImageViewerState();
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
        height: 115.0,
        width: CustomNavigator.width(context),
        color: Colors.black.withOpacity(0.65),
        child: SafeArea(
          left: false,
          right: false,
          bottom: false,
          child: Container(
            height: 50,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Padding(
                padding: EdgeInsets.only(top: 10.0, left: 5),
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
                    padding: EdgeInsets.only(top: 10.0),
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
                    padding: EdgeInsets.only(top: 10.0),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      onPressed: () async {
                        ChatManager().activeChat?.clearImageData(widget.attachment);

                        showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
                        AttachmentHelper.redownloadAttachment(widget.attachment, onComplete: () {
                          initBytes();
                        }, onError: () {
                          Navigator.pop(context);
                        });

                        bytes = null;
                        if (mounted) setState(() {});
                      },
                      child: Icon(
                        SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.refresh : Icons.refresh,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: CupertinoButton(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      onPressed: () async {
                        await AttachmentHelper.saveToGallery(widget.file);
                      },
                      child: Icon(
                        SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!kIsWeb && !kIsDesktop)
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
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
                ],
              ),
            ]),
          ),
        ),
      ),
    );

    var loader = Center(
      child: CircularProgressIndicator(
        backgroundColor: Theme.of(context).colorScheme.secondary,
        valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            if (!mounted || !widget.showInteractions) return;

            setState(() {
              showOverlay = !showOverlay;
            });
          },
          child: Stack(
            children: <Widget>[
              bytes != null
                  ? PhotoView(
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
                          child: Text("Failed to display image", style: TextStyle(fontSize: 16, color: Colors.white))))
                  : loader,
              overlay
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
