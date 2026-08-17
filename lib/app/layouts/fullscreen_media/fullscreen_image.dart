import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/live_photo_mixin.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/dialogs/metadata_dialog.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/backend/interfaces/image_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:photo_view/photo_view.dart';
import 'dart:io';

class FullscreenImage extends StatefulWidget {
  const FullscreenImage({
    super.key,
    required this.file,
    required this.attachment,
    required this.showInteractions,
    required this.updatePhysics,
    this.onOverlayToggle,
    this.onJumpToMessage,
  });

  final PlatformFile file;
  final Attachment attachment;
  final bool showInteractions;
  final Function(ScrollPhysics) updatePhysics;
  final Function(bool)? onOverlayToggle;
  final VoidCallback? onJumpToMessage;

  @override
  State<FullscreenImage> createState() => _FullscreenImageState();
}

class _FullscreenImageState extends State<FullscreenImage>
    with AutomaticKeepAliveClientMixin, LivePhotoMixin, ThemeHelpers {
  final PhotoViewController controller = PhotoViewController();
  bool showOverlay = true;
  bool hasError = false;
  Uint8List? bytes;
  String? compatiblePath; // For converted HEIC/TIFF files

  PlatformFile get file => widget.file;
  Attachment get attachment => widget.attachment;
  Message? get message => attachment.message.target;

  // Implement required getter for LivePhotoMixin
  @override
  Attachment get livePhotoAttachment => attachment;

  @override
  void initState() {
    super.initState();
    _setFullscreen(true);
    initBytes();
  }

  void _setFullscreen(bool fullscreen) {
    if (fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> initBytes() async {
    // For web, we need bytes in memory
    if (kIsWeb || file.path == null) {
      if (attachment.mimeType?.contains("image/tif") ?? false) {
        bytes = await ImageInterface.convertToPng(file);
      } else {
        bytes = file.bytes;
      }
      setState(() {});
      return;
    }

    // For non-web platforms, ensure we have a compatible image path
    // but don't load bytes into memory - let Image.file handle it
    compatiblePath = await AttachmentsSvc.ensureImageCompatibility(attachment, actualPath: file.path!);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _setFullscreen(false);
    controller.dispose();
    super.dispose();
  }

  void refreshAttachment() {
    showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
    setState(() {
      bytes = null;
      compatiblePath = null;
      hasError = false;
    });
    AttachmentsSvc.redownloadAttachment(
      widget.attachment,
      onComplete: (newFile) {
        if (kIsWeb || newFile.path == null) {
          setState(() {
            bytes = newFile.bytes;
          });
        } else {
          initBytes();
        }
      },
      onError: () {
        setState(() {
          hasError = true;
        });
      },
    );
  }

  Widget _buildPhotoView(BuildContext context) {
    if (bytes == null && compatiblePath == null) {
      return hasError
          ? Center(child: Text("Failed to load image", style: context.theme.textTheme.bodyLarge))
          : Center(child: buildProgressIndicator(context));
    }

    // No orientation handling here: the decoder applies EXIF orientation
    // itself, so the provider's reported size is already display-space and
    // PhotoViewComputedScale.contained reads it correctly.
    return PhotoView(
      gaplessPlayback: true,
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.contained * 10,
      controller: controller,
      imageProvider: bytes != null
          ? MemoryImage(bytes!) as ImageProvider
          : FileImage(File(compatiblePath ?? file.path!)),
      loadingBuilder: (BuildContext context, ImageChunkEvent? ev) {
        return Center(child: buildProgressIndicator(context));
      },
      scaleStateChangedCallback: (scale) {
        if (scale == PhotoViewScaleState.zoomedIn ||
            scale == PhotoViewScaleState.covering ||
            scale == PhotoViewScaleState.originalSize) {
          widget.updatePhysics(const NeverScrollableScrollPhysics());
        } else {
          widget.updatePhysics(ThemeSwitcher.getScrollPhysics());
        }
      },
      errorBuilder: (context, object, stacktrace) =>
          Center(child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge)),
      filterQuality: FilterQuality.high,
    );
  }

  Widget _senderHeaderColumn({required bool jumpEnabled}) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(() {
          final msg = message;
          if (msg == null) return const SizedBox.shrink();
          final name = (msg.isFromMe ?? false)
              ? 'You'
              : (msg.handleRelation.target != null
                      ? HandleSvc.getOrCreateHandleState(msg.handleRelation.target!).displayName.value
                      : null) ??
                  'Unknown';
          return Text(name, style: context.theme.textTheme.titleLarge!.copyWith(color: Colors.white));
        }),
        if (message?.dateCreated != null)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Text(
              samsung
                  ? intl.DateFormat.jm().add_MMMd().format(message!.dateCreated!)
                  : intl.DateFormat('EEE').add_jm().format(message!.dateCreated!),
              style: context.theme.textTheme.bodyLarge!
                  .copyWith(color: samsung ? Colors.grey : Colors.white),
            ),
          ),
      ],
    );

    if (!jumpEnabled) return column;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onJumpToMessage,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: column,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: Colors.black,
      child: GestureDetector(
        onTap: () {
          if (!widget.showInteractions) return;
          bool newVal = !showOverlay;
          setState(() {
            showOverlay = newVal;
          });

          if (widget.onOverlayToggle != null) {
            widget.onOverlayToggle!(newVal);
          }

          // eventDispatcher.emit('overlay-toggle', newVal);
        },
        onLongPress: () {
          if (attachment.hasLivePhoto && !isDownloadingLivePhoto.value) {
            handleLivePhotoTap();
          }
        },
        child: Stack(
          children: [
            _buildPhotoView(context),
            // Live photo video overlay
            if (attachment.hasLivePhoto) buildLivePhotoOverlay(),
            if (!iOS)
              AnimatedOpacity(
                opacity: showOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 125),
                child: Container(
                  height: kIsDesktop ? 80 : 100.0,
                  width: NavigationSvc.width(context),
                  color: context.theme.colorScheme.shadow.withValues(alpha: samsung ? 1 : 0.65),
                  child: SafeArea(
                    left: false,
                    right: false,
                    bottom: false,
                    child: SizedBox(
                      height: kIsDesktop ? 80 : 50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  onPressed: () async {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Icon(Icons.close, color: Colors.white),
                                ),
                              ),
                              if (widget.showInteractions)
                                Padding(
                                  padding: const EdgeInsets.only(left: 5.0),
                                  child: _senderHeaderColumn(
                                    jumpEnabled: samsung && widget.onJumpToMessage != null,
                                  ),
                                ),
                            ],
                          ),
                          !widget.showInteractions
                              ? const SizedBox.shrink()
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 5),
                                        onPressed: () async {
                                          showMetadataDialog(widget.attachment, context);
                                        },
                                        child: const Icon(Icons.info_outlined, color: Colors.white),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: CupertinoButton(
                                        padding: const EdgeInsets.symmetric(horizontal: 5),
                                        onPressed: () async {
                                          refreshAttachment();
                                        },
                                        child: const Icon(Icons.refresh, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Bottom actions bar (iOS style)
            if (widget.showInteractions && iOS)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  opacity: showOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    top: false,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.cloud_download,
                              color: context.theme.colorScheme.primary,
                            ),
                            onPressed: () => AttachmentsSvc.saveToDisk(widget.file),
                          ),
                          if (!kIsWeb && !kIsDesktop)
                            IconButton(
                              icon: Icon(
                                CupertinoIcons.share,
                                color: context.theme.colorScheme.primary,
                              ),
                              onPressed: () {
                                if (widget.file.path != null) {
                                  Share.files([widget.file.path!]);
                                }
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.info,
                              color: context.theme.colorScheme.primary,
                            ),
                            onPressed: () => showMetadataDialog(widget.attachment, context),
                          ),
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.refresh,
                              color: context.theme.colorScheme.primary,
                            ),
                            onPressed: () => refreshAttachment(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Bottom FABs (Material style)
            if (widget.showInteractions && material)
              Positioned(
                left: 16,
                bottom: 16,
                child: AnimatedOpacity(
                  opacity: showOverlay ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        FloatingActionButton(
                          backgroundColor: context.theme.colorScheme.secondary,
                          child: Icon(Icons.file_download_outlined, color: context.theme.colorScheme.onSecondary),
                          onPressed: () => AttachmentsSvc.saveToDisk(widget.file),
                        ),
                        if (!kIsWeb && !kIsDesktop)
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: FloatingActionButton(
                              backgroundColor: context.theme.colorScheme.secondary,
                              child: Icon(Icons.share_outlined, color: context.theme.colorScheme.onSecondary),
                              onPressed: () {
                                if (widget.file.path != null) {
                                  Share.files([widget.file.path!]);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
