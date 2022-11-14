import 'dart:math';

import 'package:animations/animations.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/audio_player.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/contact_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/image_viewer.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/other_file.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/video_player.dart';
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
import 'package:tuple/tuple.dart';

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
    final bool showTail = message.showTail(newerMessage) && part.part == controller.parts.length - 1;
    return ClipPath(
      clipper: TailClipper(
        isFromMe: message.isFromMe!,
        showTail: showTail,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: content is PlatformFile ? null : () async {
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
            }
          },
          child: Ink(
            color: context.theme.colorScheme.properSurface,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ns.width(context) * 0.5,
                maxHeight: context.height * 0.6,
                minHeight: 40,
                minWidth: 40,
              ),
              child: Padding(
                padding: content is PlatformFile
                    ? (showTail ? EdgeInsets.zero : EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0))
                    : const EdgeInsets.symmetric(vertical: 10, horizontal: 15)
                    .add(EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 150),
                  child: Center(
                    heightFactor: 1,
                    widthFactor: 1,
                    child: Opacity(
                      opacity: message.guid!.startsWith("temp") ? 0.5 : 1,
                      child: Builder(
                        builder: (context) {
                          if (content is Tuple2<String, RxDouble>) {
                            final Tuple2<String, RxDouble> _content = content;
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
                                        child: CircleProgressBar(
                                          value: _content.item2.value,
                                          backgroundColor: context.theme.colorScheme.outline,
                                          foregroundColor: context.theme.colorScheme.properOnSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "${(attachment.totalBytes! * min(_content.item2.value, 1.0)).toDouble().getFriendlySize()} / ${attachment.getFriendlySize()}",
                                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  ],
                                );
                              }),
                            );
                          } else if (content is Attachment) {
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
                              return OpenContainer(
                                tappable: false,
                                openColor: Colors.black,
                                closedColor: context.theme.colorScheme.properSurface,
                                closedShape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(20.0)),
                                ),
                                useRootNavigator: true,
                                openBuilder: (context, closeContainer) {
                                  return AttachmentFullscreenViewer(
                                    currentChat: cm.activeChat,
                                    attachment: attachment,
                                    showInteractions: true,
                                  );
                                },
                                closedBuilder: (context, openContainer) {
                                  return GestureDetector(
                                    onTap: () {
                                      final _controller = cvc(cm.activeChat!.chat);
                                      _controller.focusNode.unfocus();
                                      _controller.subjectFocusNode.unfocus();
                                      openContainer();
                                    },
                                    child: ImageViewer(
                                      file: _content,
                                      attachment: attachment,
                                    ),
                                  );
                                }
                              );
                            } else if (attachment.mimeStart == "video" && !kIsDesktop) {
                              return VideoPlayer(
                                attachment: attachment,
                                file: _content,
                              );
                            } else if (attachment.mimeStart == "audio") {
                              return AudioPlayer(
                                attachment: attachment,
                                file: _content,
                              );
                            } /*else if (attachment.mimeType == "text/x-vlocation" || attachment.uti == 'public.vlocation') {
                              return MediaFile(
                                attachment: widget.attachment,
                                child: UrlPreviewWidget(
                                  linkPreviews: [],
                                  mess
                                ),
                              );
                              return const SizedBox.shrink();
                            }*/ else if (attachment.mimeType?.contains("vcard") ?? false) {
                              return ContactCard(
                                attachment: attachment,
                                file: _content,
                              );
                            } else if (attachment.mimeType == null) {
                              return Padding(
                                padding: showTail ? EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0) : EdgeInsets.zero,
                                child: SizedBox(
                                  height: 80,
                                  width: 80,
                                  child: Icon(iOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline, size: 30),
                                ),
                              );
                            } else {
                              return Padding(
                                padding: showTail ? EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0) : EdgeInsets.zero,
                                child: OtherFile(
                                  attachment: attachment,
                                  file: _content,
                                ),
                              );
                            }
                          } else {
                            return Text(
                              "Error loading attachment",
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
      ),
    );
  }
}
