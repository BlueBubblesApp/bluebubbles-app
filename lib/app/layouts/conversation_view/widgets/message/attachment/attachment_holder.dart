import 'dart:math';

import 'package:animations/animations.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/audio_player.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/contact_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/image_viewer.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/other_file.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/video_player.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_holder.dart';
import 'package:bluebubbles/app/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:tuple/tuple.dart';

class AttachmentHolder extends CustomStateful<MessageWidgetController> {
  AttachmentHolder({
    Key? key,
    required super.parentController,
    required this.message,
  }) : super(key: key);

  final MessagePart message;

  @override
  CustomState createState() => _AttachmentHolderState();
}

class _AttachmentHolderState extends CustomState<AttachmentHolder, void, MessageWidgetController> {
  MessagePart get part => widget.message;
  Message get message => controller.message;
  Message? get newerMessage => controller.newMessage;
  Attachment get attachment => message.attachments.firstWhereOrNull((e) => e?.id == part.attachments.first.id)
      ?? ms(controller.cvController?.chat.guid ?? cm.activeChat!.chat.guid).struct.attachments.firstWhereOrNull((e) => e.id == part.attachments.first.id)
      ?? part.attachments.first;
  late dynamic content;
  late bool selected = controller.cvController?.isSelected(message.guid!) ?? false;

  @override
  void initState() {
    forceDelete = false;
    if (controller.cvController != null && !iOS) {
      ever<List<Message>>(controller.cvController!.selected, (event) {
        if (controller.cvController!.isSelected(message.guid!) && !selected) {
          setState(() {
            selected = true;
          });
        } else if (!controller.cvController!.isSelected(message.guid!) && selected) {
          setState(() {
            selected = false;
          });
        }
      });
    }
    super.initState();
    updateContent();
  }


  void updateContent() async {
    content = as.getContent(attachment, onComplete: onComplete);
    // If we can download it, do so
    if (content is Attachment && message.error == 0 && !message.guid!.contains("temp") && await as.canAutoDownload()) {
      if (mounted) {
        setState(() {
          content = attachmentDownloader.startDownload(content, onComplete: onComplete);
        });
      }
    }
  }

  @override
  void updateWidget(void _) {
    updateContent();
    super.updateWidget(_);
  }

  void onComplete(PlatformFile file) {
    setState(() {
      content = file;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showTail = message.showTail(newerMessage) && part.part == controller.parts.length - 1;
    final bool hideAttachments = ss.settings.redactedMode.value && ss.settings.hideAttachments.value;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(context.theme.colorScheme.tertiaryContainer.withOpacity(0.5), selected ? BlendMode.srcOver : BlendMode.dstOver),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: content is PlatformFile ? null : () async {
            if (content is Attachment && message.error == 0 && !message.guid!.contains("temp")) {
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
                minWidth: 100,
              ),
              child: Padding(
                padding: content is PlatformFile && !hideAttachments
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
                              padding: EdgeInsets.only(left: 10.0, top: 10.0, right: 10.0, bottom: _content.item2.value < 1 && message.error == 0 ? 0 : 10.0),
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
                                    const SizedBox(height: 10),
                                    Text(
                                      "${(attachment.totalBytes! * min(_content.item2.value, 1.0)).toDouble().getFriendlySize(withPostfix: false)} / ${attachment.getFriendlySize()}",
                                      style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    if (message.error == 0)
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: _content.item2.value < 1
                                            ? Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary))
                                            : Text("Waiting for iMessage...", style: context.theme.textTheme.bodyLarge!, textAlign: TextAlign.center),
                                        onPressed: _content.item2.value < 1 ? () {
                                          ah.latestCancelToken?.cancel("User cancelled send.");
                                        } : null,
                                      ),
                                  ],
                                );
                              }),
                            );
                          } else if (content is Attachment || hideAttachments) {
                            final Attachment _content = hideAttachments ? attachment : content;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (!hideAttachments)
                                  SizedBox(
                                    height: 40,
                                    width: 40,
                                    child: Center(
                                      child: Obx(() => Icon(message.error > 0 || message.guid!.startsWith("error-")
                                          ? (iOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline)
                                          : (iOS ? CupertinoIcons.cloud_download : Icons.cloud_download_outlined), size: 30))
                                    ),
                                  ),
                                const SizedBox(height: 5),
                                Obx(() => Text(
                                  message.error > 0 || message.guid!.startsWith("error-") ? "Send Failed!" : (_content.mimeType ?? ""),
                                  style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )),
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
                                if (_content.progress.value == 1) {
                                  updateContent();
                                }
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
                                      textAlign: TextAlign.center,
                                    )
                                  ],
                                );
                              }),
                            );
                          } else if (content is PlatformFile) {
                            final PlatformFile _content = content;
                            if (attachment.mimeStart == "image" && !ss.settings.highPerfMode.value) {
                              return OpenContainer(
                                tappable: false,
                                openColor: Colors.black,
                                closedColor: context.theme.colorScheme.properSurface,
                                closedShape: iOS ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20.0),
                                    topRight: const Radius.circular(20.0),
                                    bottomLeft: message.isFromMe! ? const Radius.circular(20.0) : Radius.zero,
                                    bottomRight: !message.isFromMe! ? const Radius.circular(20.0) : Radius.zero,
                                  ),
                                ) : const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(5.0)),
                                ),
                                useRootNavigator: true,
                                openBuilder: (context, closeContainer) {
                                  return FullscreenMediaHolder(
                                    currentChat: cm.activeChat,
                                    attachment: attachment,
                                    showInteractions: true,
                                  );
                                },
                                closedBuilder: (context, openContainer) {
                                  return GestureDetector(
                                    onTap: () {
                                      final _controller = controller.cvController ?? cvc(cm.activeChat!.chat);
                                      _controller.focusNode.unfocus();
                                      _controller.subjectFocusNode.unfocus();
                                      openContainer();
                                    },
                                    child: ImageViewer(
                                      file: _content,
                                      attachment: attachment,
                                      isFromMe: message.isFromMe!,
                                      controller: controller.cvController,
                                    ),
                                  );
                                }
                              );
                            } else if ((attachment.mimeStart == "video" || attachment.mimeType == "audio/mp4") && !ss.settings.highPerfMode.value) {
                              return VideoPlayer(
                                attachment: attachment,
                                file: _content,
                                controller: controller.cvController,
                                isFromMe: message.isFromMe!,
                              );
                            } else if (attachment.mimeStart == "audio") {
                              return Padding(
                                padding: showTail ? EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0) : EdgeInsets.zero,
                                child: AudioPlayer(
                                  attachment: attachment,
                                  file: _content,
                                  controller: controller.cvController,
                                ),
                              );
                            } else if (attachment.mimeType == "text/x-vlocation" || attachment.uti == 'public.vlocation') {
                              return Padding(
                                padding: showTail ? EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0) : EdgeInsets.zero,
                                child: UrlPreview(
                                  data: UrlPreviewData(
                                    title: "Location from ${DateFormat.yMd().format(message.dateCreated!)}",
                                    siteName: "Tap to open",
                                  ),
                                  message: message,
                                  file: _content,
                                ),
                              );
                            } else if (attachment.mimeType?.contains("vcard") ?? false) {
                              return Padding(
                                padding: showTail ? EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0) : EdgeInsets.zero,
                                child: ContactCard(
                                  attachment: attachment,
                                  file: _content,
                                ),
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
