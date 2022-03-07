import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/circle_progress_bar.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_file.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/contact_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/image_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/location_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MessageAttachment extends StatefulWidget {
  MessageAttachment({
    Key? key,
    required this.attachment,
    required this.updateAttachment,
    required this.isFromMe,
  }) : super(key: key);
  final Attachment attachment;
  final Function() updateAttachment;
  final bool isFromMe;

  @override
  MessageAttachmentState createState() => MessageAttachmentState();
}

class MessageAttachmentState extends State<MessageAttachment> with AutomaticKeepAliveClientMixin {
  Widget? attachmentWidget;
  dynamic content;

  @override
  void initState() {
    super.initState();
    updateContent();

    ever(Get.find<AttachmentDownloadService>().downloaders, (List<String> downloaders) {
      if (downloaders.contains(widget.attachment.guid)) {
        if (mounted) setState(() {});
      }
    });
  }

  void updateContent() async {
    // Ge the current attachment content (status)
    content = AttachmentHelper.getContent(widget.attachment,
        path: widget.attachment.guid == "redacted-mode-demo-attachment" ||
                widget.attachment.guid!.contains("theme-selector")
            ? widget.attachment.transferName
            : null);

    // If we can download it, do so
    if (await AttachmentHelper.canAutoDownload() && content is Attachment) {
      if (mounted) {
        setState(() {
          content = Get.put(AttachmentDownloadController(attachment: content), tag: content.guid);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    updateContent();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: CustomNavigator.width(context) * 0.5,
          maxHeight: context.height * 0.6,
        ),
        child: _buildAttachmentWidget(),
      ),
    );
  }

  Widget _buildAttachmentWidget() {
    // If it's a file, it's already been downlaoded, so just display it
    if (content is PlatformFile) {
      String? mimeType = widget.attachment.mimeType;
      if (mimeType != null) mimeType = mimeType.substring(0, mimeType.indexOf("/"));
      if (mimeType == "image") {
        return MediaFile(
          attachment: widget.attachment,
          child: ImageWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (mimeType == "video") {
        if (kIsDesktop) {
          return MediaFile(
            attachment: widget.attachment,
            child: RegularFileOpener(
              file: content,
              attachment: widget.attachment,
            ),
          );
        }
        return MediaFile(
          attachment: widget.attachment,
          child: VideoWidget(
            attachment: widget.attachment,
            file: content,
          ),
        );
      } else if (mimeType == "audio" && !widget.attachment.mimeType!.contains("caf")) {
        return MediaFile(
          attachment: widget.attachment,
          child: AudioPlayerWidget(file: content, context: context, width: kIsDesktop ? null : 250, isFromMe: widget.isFromMe),
        );
      } else if (widget.attachment.mimeType == "text/x-vlocation" || widget.attachment.uti == 'public.vlocation') {
        return MediaFile(
          attachment: widget.attachment,
          child: LocationWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (widget.attachment.mimeType == "text/vcard") {
        return MediaFile(
          attachment: widget.attachment,
          child: ContactWidget(
            file: content,
            attachment: widget.attachment,
          ),
        );
      } else if (widget.attachment.mimeType == null) {
        return Container();
      } else {
        return MediaFile(
          attachment: widget.attachment,
          child: RegularFileOpener(
            file: content,
            attachment: widget.attachment,
          ),
        );
      }

      // If it's an attachment, then it needs to be manually downloaded
    } else if (content is Attachment) {
      return AttachmentDownloaderWidget(
        onPressed: () {
          content = Get.put(AttachmentDownloadController(attachment: content), tag: content.guid);
          if (mounted) setState(() {});
        },
        attachment: content,
        placeHolder: buildPlaceHolder(widget),
      );

      // If it's an AttachmentDownloader, it is currently being downloaded
    } else if (content is AttachmentDownloadController) {
      if (widget.attachment.mimeType == null) return Container();
      return Obx(() {
        // If there is an error, return an error text
        if (content.error.value) {
          content = widget.attachment;
          return AttachmentDownloaderWidget(
            onPressed: () {
              content = Get.put(AttachmentDownloadController(attachment: content), tag: content.guid);
              if (mounted) setState(() {});
            },
            attachment: content,
            placeHolder: buildPlaceHolder(widget),
          );
        }

        // If the snapshot data is a file, we have finished downloading
        if (content.file.value != null) {
          content = content.file.value;
          return _buildAttachmentWidget();
        }

        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            buildPlaceHolder(widget),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Center(
                      child: Container(
                        height: 40,
                        width: 40,
                        child: CircleProgressBar(
                          value: content.progress.value?.toDouble() ?? 0,
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    ((content as AttachmentDownloadController).attachment.mimeType != null)
                        ? Container(height: 5.0)
                        : Container(),
                    (content.attachment.mimeType != null)
                        ? Container(
                          height: 50,
                          alignment: Alignment.center,
                          child: Text(
                            content.attachment.mimeType,
                            style: Theme.of(context).textTheme.bodyText1,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                        : Container()
                  ],
                ),
              ],
            ),
          ],
        );
      });
    } else {
      return Text(
        "Error loading",
        style: Theme.of(context).textTheme.bodyText1,
      );
      //     return Container();
    }
  }

  Widget buildPlaceHolder(MessageAttachment parent) {
    return buildImagePlaceholder(context, widget.attachment, Container());
  }

  @override
  bool get wantKeepAlive => true;
}
