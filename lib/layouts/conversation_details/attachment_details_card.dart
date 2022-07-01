import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/widgets/circle_progress_bar.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:universal_io/io.dart';

class AttachmentDetailsCard extends StatefulWidget {
  AttachmentDetailsCard({Key? key, required this.attachment}) : super(key: key);
  final Attachment attachment;

  @override
  State<AttachmentDetailsCard> createState() => _AttachmentDetailsCardState();
}

class _AttachmentDetailsCardState extends State<AttachmentDetailsCard> with AutomaticKeepAliveClientMixin {
  Uint8List? previewImage;
  double aspectRatio = 4 / 3;
  late PlatformFile attachmentFile;

  @override
  void initState() {
    super.initState();

    attachmentFile = PlatformFile(
      name: widget.attachment.transferName!,
      path: kIsWeb ? null : widget.attachment.getPath(),
      bytes: widget.attachment.bytes,
      size: widget.attachment.totalBytes!,
    );
    subscribeToDownloadStream();
  }

  void subscribeToDownloadStream() {
    if (Get.find<AttachmentDownloadService>().downloaders.contains(widget.attachment.guid)) {
      AttachmentDownloadController controller = Get.find<AttachmentDownloadController>(tag: widget.attachment.guid);
      ever<PlatformFile?>(controller.file,
          (file) {
        if (file != null && mounted) {
          Future.delayed(Duration(milliseconds: 500), () {
            if (!mounted) return;
            setState(() {});
          });
        }
      });
    }
  }

  void getCompressedImage() {
    String path = AttachmentHelper.getAttachmentPath(widget.attachment);
    AttachmentHelper.compressAttachment(widget.attachment, path).then((data) {
      if (!mounted) return;
      setState(() {
        previewImage = data;
      });
    });
  }

  Widget buildReadyToDownload(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
      onPressed: () async {
        Get.put(AttachmentDownloadController(attachment: widget.attachment), tag: widget.attachment.guid);
        subscribeToDownloadStream();
        if (mounted) setState(() {});
      },
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            widget.attachment.getFriendlySize(),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: 5),
          Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.cloud_download : Icons.cloud_download, size: 28.0, color: context.theme.colorScheme.properOnSurface,),
          SizedBox(height: 5),
          (widget.attachment.mimeType != null && attachmentFile.path != null)
              ? Text(
                  basename(attachmentFile.path!),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                )
              : Container()
        ],
      ),
    );
  }

  Widget buildPreview(BuildContext context) => SizedBox(
        width: CustomNavigator.width(context) / max(2, CustomNavigator.width(context) ~/ 200),
        child: _buildPreview(attachmentFile, context),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Attachment attachment = widget.attachment;
    final bool hideAttachments =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachments.value;
    final bool hideAttachmentTypes =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideAttachmentTypes.value;
    if (hideAttachments && !hideAttachmentTypes) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: Container(
          alignment: Alignment.center,
          color: context.theme.colorScheme.properSurface,
          child: Text(
            widget.attachment.mimeType ?? "Unknown",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (hideAttachments) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: context.theme.colorScheme.properSurface,
        ),
      );
    }
    if (kIsWeb) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: buildPreview(context)
      );
    }
    File file = File(
      "${SettingsManager().appDocDir.path}/attachments/${attachment.guid}/${attachment.transferName}",
    );
    if (!file.existsSync()) {
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: Container(
              color: context.theme.colorScheme.properSurface,
            ),
          ),
          Center(
            child: !Get.find<AttachmentDownloadService>().downloaders.contains(attachment.guid)
                ? buildReadyToDownload(context)
                : Builder(
                    builder: (context) {
                      bool attachmentExists = kIsWeb ? false : File(attachmentFile.path ?? "").existsSync();

                      // If the attachment exists, build the preview
                      if (attachmentExists) return buildPreview(context);

                      // If the attachment is not being downloaded, show the downloader
                      if (!Get.find<AttachmentDownloadService>().downloaders.contains(attachment.guid)) {
                        return buildReadyToDownload(context);
                      }

                      return Obx(() {
                        AttachmentDownloadController controller = Get.find<AttachmentDownloadController>(tag: attachment.guid);
                        // If the download is complete, show the preview
                        if (controller.file.value != null) return buildPreview(context);

                        // If all else fails, show the downloader
                        return Container(
                            height: 40,
                            width: 40,
                            child: CircleProgressBar(
                                foregroundColor: context.theme.colorScheme.primary,
                                backgroundColor: context.theme.colorScheme.outline,
                                value: controller.progress.value?.toDouble() ?? 0));
                      });
                    }),
          ),
        ],
      );
    } else {
      return buildPreview(context);
    }
  }

  Future<void> getVideoPreview(PlatformFile file) async {
    if (previewImage != null || kIsWeb || file.path == null) return;
    
    Size size;

    try {
      // If we already errored, throw an error to load the error logo
      if (widget.attachment.metadata?['thumbnail_status'] == 'error') {
        throw Exception('No video preview');
      }

      previewImage = await AttachmentHelper.getVideoThumbnail(file.path!);
      size = await AttachmentHelper.getImageSizing("${file.path}.thumbnail");
      widget.attachment.width = size.width.toInt();
      widget.attachment.height = size.height.toInt();
      aspectRatio = size.width / size.height;
    } catch (ex) {
      // If an error occurs, set the thumnail to the cached no preview image
      previewImage = ChatManager().noVideoPreviewIcon;
      widget.attachment.width = 800;
      widget.attachment.height = 800;
      aspectRatio = 1;

      if (widget.attachment.metadata?['thumbnail_status'] != 'error') {
          widget.attachment.metadata ??= {};
          widget.attachment.metadata!['thumbnail_status'] = 'error';
          widget.attachment.save(null);
        }
    }
    
    if (mounted) setState(() {});
  }

  Widget _buildPreview(PlatformFile file, BuildContext context) {
    if (widget.attachment.mimeType?.startsWith("image/") ?? false) {
      if (previewImage == null) {
        if (file.bytes != null) {
          previewImage = file.bytes;
        } else {
          getCompressedImage();
        }
      }

      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            ChatController? currentChat = ChatManager().activeChat;
            Navigator.of(Get.context!).push(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => AttachmentFullscreenViewer(
                  currentChat: currentChat,
                  attachment: widget.attachment,
                  showInteractions: true,
                ),
              ),
            );
          },
          child: SizedBox(
            child: Hero(
                tag: widget.attachment.guid!,
                child: (previewImage != null)
                    ? Image.memory(
                        previewImage!,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        alignment: Alignment.center,
                      )
                    : Container()),
            width: CustomNavigator.width(context) / max(2, CustomNavigator.width(context) ~/ 200),
            height: CustomNavigator.width(context) / max(2, CustomNavigator.width(context) ~/ 200),
          ),
        ),
      );
    } else if (!kIsDesktop && (widget.attachment.mimeType?.startsWith("video/") ?? false)) {
      getVideoPreview(file);

      return Stack(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.of(Get.context!).push(
                  ThemeSwitcher.buildPageRoute(
                    builder: (context) => AttachmentFullscreenViewer(
                      attachment: widget.attachment,
                      showInteractions: true,
                    ),
                  ),
                );
              },
              child: SizedBox(
                child: Hero(
                  tag: widget.attachment.guid!,
                  child: previewImage != null
                      ? Image.memory(
                          previewImage!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          alignment: Alignment.center,
                        )
                      : Container(),
                ),
                width: CustomNavigator.width(context) / max(2, CustomNavigator.width(context) ~/ 200),
                height: CustomNavigator.width(context) / max(2, CustomNavigator.width(context) ~/ 200),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(
              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.play : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        ],
      );
    } else {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: context.theme.colorScheme.properSurface,
          child: Center(
            child: RegularFileOpener(
              file: file,
              attachment: widget.attachment,
            ),
          ),
        ),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;
}
