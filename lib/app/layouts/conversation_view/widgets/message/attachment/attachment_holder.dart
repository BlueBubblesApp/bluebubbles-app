import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/image_viewer.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/image_viewer/attachment_fullscreen_viewer.dart';
import 'package:bluebubbles/app/widgets/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AttachmentHolder extends CustomStateful<MessageWidgetController> {
  AttachmentHolder({
    Key? key,
    required super.parentController,
    required this.message,
  }) : super(key: key);

  final MessagePart message;

  @override
  _AttachmentHolderState createState() => _AttachmentHolderState();
}

class _AttachmentHolderState extends CustomState<AttachmentHolder, void, MessageWidgetController> {
  MessagePart get part => widget.message;
  Message get message => controller.message;
  Message? get olderMessage => controller.oldMwc?.message;
  Message? get newerMessage => controller.newMwc?.message;
  Attachment get attachment => part.attachments.first;
  late dynamic content;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
    updateContent();
  }


  void updateContent() async {
    content = as.getContent(attachment, onComplete: onComplete);
    // If we can download it, do so
    if (content is Attachment && await as.canAutoDownload()) {
      if (mounted) {
        setState(() {
          content = attachmentDownloader.startDownload(content, onComplete: onComplete);
        });
      }
    }
  }

  void onComplete(PlatformFile file) {
    setState(() {
      content = file;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TailClipper(
        isFromMe: message.isFromMe!,
        showTail: message.showTail(newerMessage) && part.part == controller.parts.length - 1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (content is Attachment) {
              setState(() {
                content = attachmentDownloader.startDownload(content, onComplete: onComplete);
              });
            } else if (content is AttachmentDownloadController) {
              final AttachmentDownloadController _content = content;
              if (!_content.error.value) return;
              Get.delete<AttachmentDownloadController>(tag: _content.attachment.guid);
              setState(() {
                content = attachmentDownloader.startDownload(_content.attachment, onComplete: onComplete);
              });
            } else if (content is PlatformFile) {
              if (attachment.mimeStart == "image" || attachment.mimeStart == "video") {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AttachmentFullscreenViewer(
                      currentChat: cm.activeChat,
                      attachment: attachment,
                      showInteractions: true,
                    ),
                  ),
                );
              }
            }
          },
          child: Ink(
            padding: content is PlatformFile
                ? null
                : const EdgeInsets.symmetric(vertical: 10, horizontal: 15)
                .add(EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
            color: context.theme.colorScheme.properSurface,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ns.width(context) * 0.5,
                maxHeight: context.height * 0.6,
                minHeight: 40,
                minWidth: 40,
              ),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 150),
                child: Center(
                  heightFactor: 1,
                  widthFactor: 1,
                  child: Opacity(
                    opacity: message.guid!.startsWith("temp") ? 0.5 : 1,
                    child: Builder(
                      builder: (context) {
                        if (content is Attachment) {
                          final Attachment _content = content;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              SizedBox(
                                height: 40,
                                width: 40,
                                child: Center(
                                  child: Icon(iOS ? CupertinoIcons.cloud_download : Icons.cloud_download_outlined, size: 30)
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                (_content.mimeType ?? ""),
                                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _content.getFriendlySize(),
                                style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                maxLines: 1,
                              ),
                            ],
                          );
                        } else if (content is AttachmentDownloadController) {
                          final AttachmentDownloadController _content = content;
                          return Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Obx(() {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SizedBox(
                                    height: 40,
                                    width: 40,
                                    child: Center(
                                      child: _content.error.value
                                          ? Icon(iOS ? CupertinoIcons.arrow_clockwise : Icons.refresh, size: 30) : CircleProgressBar(
                                              value: _content.progress.value?.toDouble() ?? 0,
                                              backgroundColor: context.theme.colorScheme.outline,
                                              foregroundColor: context.theme.colorScheme.properOnSurface,
                                          ),
                                    ),
                                  ),
                                  _content.error.value ? const SizedBox(height: 10) : const SizedBox(height: 5),
                                  Text(
                                    _content.error.value ? "Failed to download!" : (_content.attachment.mimeType ?? ""),
                                    style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                ],
                              );
                            }),
                          );
                        } else if (content is PlatformFile) {
                          final PlatformFile _content = content;
                          if (attachment.mimeStart == "image") {
                            return ImageViewer(
                              file: _content,
                              attachment: attachment,
                            );
                          }/* else if (attachment.mimeStart == "video" && !kIsDesktop) {
                            return MediaFile(
                              attachment: widget.attachment,
                              child: kIsDesktop
                                  ? DesktopVideoWidget(
                                attachment: widget.attachment,
                                file: content,
                              )
                                  : VideoWidget(
                                attachment: widget.attachment,
                                file: content,
                              ),
                            );
                          } else if (attachment.mimeStart == "audio" && !widget.attachment.mimeType!.contains("caf")) {
                            return MediaFile(
                              attachment: widget.attachment,
                              child: AudioPlayerWidget(
                                  file: content, context: context, width: kIsDesktop ? null : 250, isFromMe: widget.isFromMe),
                            );
                          } else if (attachment.mimeType == "text/x-vlocation" || attachment.uti == 'public.vlocation') {
                            return MediaFile(
                              attachment: widget.attachment,
                              child: UrlPreviewWidget(
                                linkPreviews: [],
                                mess
                              ),
                            );
                            return const SizedBox.shrink();
                          } else if (attachment.mimeType == "text/vcard") {
                            return MediaFile(
                              attachment: widget.attachment,
                              child: ContactWidget(
                                file: content,
                                attachment: widget.attachment,
                              ),
                            );
                          } else if (attachment.mimeType == null) {
                            return SizedBox(
                              height: 40,
                              width: 40,
                              child: Center(
                                child: Icon(iOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline)
                              ),
                            );
                          } else {
                            return MediaFile(
                              attachment: widget.attachment,
                              child: RegularFileOpener(
                                file: content,
                                attachment: widget.attachment,
                              ),
                            );
                          }*/
                          return SizedBox(
                            height: 40,
                            width: 40,
                            child: Icon(iOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline, size: 30),
                          );
                        } else {
                          return Text(
                            "Error loading",
                            style: context.theme.textTheme.bodyLarge,
                          );
                        }
                      }
                    )
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
