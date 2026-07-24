import 'package:bluebubbles/app/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_image.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_video.dart';
import 'package:bluebubbles/models/models.dart' show MessageReplyContext;
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import "package:flutter/material.dart";
import 'package:gesture_x_detector/gesture_x_detector.dart';
import 'package:get/get.dart';

class ConversationFullscreenHolder extends StatefulWidget {
  const ConversationFullscreenHolder(
      {super.key,
      required this.attachment,
      required this.showInteractions,
      this.currentChat,
      this.videoController,
      this.mute,
      this.initialAttachmentGuid,
      this.replyMessage,
      this.replyPartIndex,
      this.galleryAttachments});

  final Chat? currentChat;
  final Attachment attachment;
  final bool showInteractions;
  final VideoController? videoController;
  final RxBool? mute;
  final String? initialAttachmentGuid;
  final Message? replyMessage;
  final int? replyPartIndex;

  /// When non-null, the fullscreen carousel is limited to these attachments
  /// instead of all images in the chat. Used when opening from a gallery card.
  final List<Attachment>? galleryAttachments;

  @override
  ConversationFullscreenHolderState createState() => ConversationFullscreenHolderState();
}

class ConversationFullscreenHolderState extends State<ConversationFullscreenHolder> with ThemeHelpers {
  final focusNode = FocusNode();
  late final PageController controller;
  late final messageService = widget.currentChat == null ? null : maybeFindMessagesSvc(widget.currentChat!.guid);
  late List<Attachment> attachments = widget.galleryAttachments != null
      ? List<Attachment>.from(widget.galleryAttachments!)
      : (widget.currentChat == null
          ? [attachment]
          : (messageService?.struct.attachments.where((e) => e.mimeStart == "image").toList() ?? [attachment]));

  int currentIndex = 0;
  ScrollPhysics? physics;

  // media_kit_video_controls' seek/volume/brightness GestureDetector always registers a
  // non-null onHorizontalDragUpdate regardless of the `seekGesture` theme flag (only its
  // callback body checks the flag, not whether the recognizer is attached). As a descendant
  // of the PageView, that recognizer wins the gesture arena's "eager winner" race before
  // PageView's own drag recognizer ever gets a chance, permanently blocking swipe on any
  // video page. Since that's vendored package behavior we can't patch, drive paging
  // independently via raw pointer tracking (which never enters the arena) whenever the
  // current page is a video. Excludes touches starting in the bottom quarter of the screen
  // so dragging the video's own seek bar isn't misread as a page-swipe attempt.
  int? _videoSwipePointer;
  double _videoSwipeDragDx = 0;
  VelocityTracker? _videoSwipeVelocityTracker;
  static const double _videoSwipeCommitThreshold = 60;

  Attachment get attachment => widget.attachment;
  // Start hidden for video (video auto-plays and manages its own overlay); show for images
  bool get _isVideoAttachment => attachment.mimeStart == "video";
  late bool showAppBar = kIsDesktop || kIsWeb || !_isVideoAttachment;
  bool get _canReply => widget.replyMessage != null && widget.replyPartIndex != null && widget.currentChat != null;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !widget.showInteractions) {
      controller = PageController(initialPage: 0);
    } else {
      if (widget.currentChat != null || widget.galleryAttachments != null) {
        final targetGuid = widget.initialAttachmentGuid ?? attachment.guid;
        currentIndex = attachments.indexWhere((e) => e.guid == targetGuid);
        if (currentIndex == -1 && widget.currentChat != null) {
          attachments.add(attachment);
          currentIndex = attachments.indexWhere((e) => e.guid == attachment.guid);
        }
        if (currentIndex == -1) currentIndex = 0;
      }
      controller = PageController(initialPage: currentIndex);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void triggerReply() {
      if (!_canReply) return;
      final selectedAttachment = attachments[currentIndex];
      cvc(widget.currentChat!).replyToMessage = MessageReplyContext(
        widget.replyMessage!,
        widget.replyPartIndex!,
        attachmentGuid: selectedAttachment.guid,
      );
      Navigator.of(context).pop();
    }

    return TitleBarWrapper(
      child: Actions(
        actions: {
          GoBackIntent: GoBackAction(context),
        },
        child: BBScaffold(
          safeAreaLeft: false,
          safeAreaRight: false,
          extendBodyBehindAppBar: true,
          extendBodyBehindBottomPill: true,
          appBar: !iOS || !showAppBar
              ? null
              : BBAppBar(
                  leading: XGestureDetector(
                    supportTouch: true,
                    onTap: !kIsDesktop
                        ? null
                        : (details) {
                            Navigator.of(context).pop();
                          },
                    child: TextButton(
                      child: Text("Done",
                          style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                      onPressed: () {
                        if (kIsDesktop) return;
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  leadingWidth: 75,
                  titleText: kIsWeb || !widget.showInteractions || widget.currentChat == null
                      ? "Media"
                      : "${currentIndex + 1} of ${attachments.length}",
                  titleStyle:
                      context.theme.textTheme.titleLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                  iconTheme: IconThemeData(color: context.theme.colorScheme.primary),
                  actions: [
                    if (_canReply)
                      IconButton(
                        onPressed: triggerReply,
                        icon: const Icon(CupertinoIcons.reply),
                      ),
                  ],
                  backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                ),
          backgroundColor: Colors.black,
          body: FocusScope(
            child: Focus(
              focusNode: focusNode,
              autofocus: true,
              onKeyEvent: (node, event) {
                Logger.info(
                    "Got device label ${event.deviceType.label}, physical key ${event.physicalKey.toString()}, logical key ${event.logicalKey.toString()}",
                    tag: "RawKeyboardListener");
                if (event.physicalKey.debugName == "Arrow Right") {
                  if (SettingsSvc.settings.fullscreenViewerSwipeDir.value == SwipeDirection.RIGHT) {
                    controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                  } else {
                    controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                  }
                } else if (event.physicalKey.debugName == "Arrow Left") {
                  if (SettingsSvc.settings.fullscreenViewerSwipeDir.value == SwipeDirection.LEFT) {
                    controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                  } else {
                    controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
                  }
                } else if (event.physicalKey.debugName == "Escape") {
                  Navigator.of(context).pop();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  if (attachments.isEmpty || attachments[currentIndex].mimeStart != "video") return;
                  // Leave the bottom quarter (seek bar / controls) alone.
                  if (event.position.dy > MediaQuery.sizeOf(context).height * 0.75) return;
                  _videoSwipePointer = event.pointer;
                  _videoSwipeDragDx = 0;
                  _videoSwipeVelocityTracker = VelocityTracker.withKind(event.kind);
                  _videoSwipeVelocityTracker!.addPosition(event.timeStamp, event.position);
                },
                onPointerMove: (event) {
                  if (_videoSwipePointer != event.pointer) return;
                  _videoSwipeDragDx += event.delta.dx;
                  _videoSwipeVelocityTracker?.addPosition(event.timeStamp, event.position);
                },
                onPointerUp: (event) {
                  if (_videoSwipePointer != event.pointer) return;
                  _videoSwipePointer = null;
                  final velocity = _videoSwipeVelocityTracker?.getVelocity().pixelsPerSecond.dx ?? 0;
                  _videoSwipeVelocityTracker = null;
                  final dx = _videoSwipeDragDx;
                  _videoSwipeDragDx = 0;
                  final bool commit = dx.abs() >= _videoSwipeCommitThreshold || velocity.abs() > 700;
                  if (!commit) return;
                  final reverseSwipe = SettingsSvc.settings.fullscreenViewerSwipeDir.value == SwipeDirection.RIGHT;
                  final goForward = reverseSwipe ? dx > 0 : dx < 0;
                  if (goForward) {
                    if (currentIndex < attachments.length - 1) {
                      controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                    }
                  } else {
                    if (currentIndex > 0) {
                      controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                    }
                  }
                },
                onPointerCancel: (event) {
                  if (_videoSwipePointer != event.pointer) return;
                  _videoSwipePointer = null;
                  _videoSwipeVelocityTracker = null;
                  _videoSwipeDragDx = 0;
                },
                child: PageView.builder(
                physics: physics ??
                    (attachments.length == 1 ? const NeverScrollableScrollPhysics() : ThemeSwitcher.getScrollPhysics()),
                reverse: SettingsSvc.settings.fullscreenViewerSwipeDir.value == SwipeDirection.RIGHT,
                itemCount: attachments.length,
                onPageChanged: (int val) {
                  widget.videoController?.player.pause();
                  setState(() {
                    currentIndex = val;
                    // Reset a zoom-lock (NeverScrollableScrollPhysics) set by the page we're
                    // leaving — FullscreenImage's PhotoView reports its own scale state via
                    // updatePhysics, but `physics` lives on this shared holder, not per-page.
                    // Without this reset, landing on a video (which never calls updatePhysics)
                    // after a zoomed image permanently locks the PageView from then on.
                    physics = null;
                  });
                },
                controller: controller,
                itemBuilder: (BuildContext context, int index) {
                  final attachment = attachments[index];
                  dynamic content = AttachmentsSvc.getContent(attachment,
                      path: attachment.guid == null ? attachment.transferName : null);
                  final key = attachment.guid ?? attachment.transferName ?? randomString(8);

                  if (content is PlatformFile) {
                    if (attachment.mimeStart == "image") {
                      return FullscreenImage(
                        key: Key(key),
                        attachment: attachment,
                        file: content,
                        showInteractions: widget.showInteractions,
                        updatePhysics: (ScrollPhysics p) {
                          if (physics != p) {
                            setState(() {
                              physics = p;
                            });
                          }
                        },
                        onOverlayToggle: (show) {
                          if (showAppBar != show) {
                            setState(() {
                              showAppBar = show;
                            });
                          }
                        },
                      );
                    } else if (attachment.mimeStart == "video") {
                      return FullscreenVideo(
                        key: Key(key),
                        file: content,
                        attachment: attachment,
                        showInteractions: widget.showInteractions,
                        videoController: widget.videoController,
                        mute: widget.mute,
                        onOverlayToggle: (show) {
                          if (showAppBar != show) {
                            setState(() {
                              showAppBar = show;
                            });
                          }
                        },
                      );
                    } else {
                      return const SizedBox.shrink();
                    }
                  } else if (content is Attachment) {
                    final Attachment _content = content;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          content = AttachmentDownloader.startDownload(content, onComplete: (file) {
                            setState(() {
                              content = file;
                            });
                          });
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            height: 40,
                            width: 40,
                            child: Center(
                                child: Icon(iOS ? CupertinoIcons.cloud_download : Icons.cloud_download_outlined,
                                    size: 30)),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            (_content.mimeType ?? ""),
                            style: context.theme.textTheme.bodyLarge!
                                .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _content.getFriendlySize(),
                            style: context.theme.textTheme.bodyMedium!
                                .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    );
                  } else if (content is AttachmentDownloadController) {
                    final AttachmentDownloadController _content = content;
                    return InkWell(
                      onTap: () {
                        final AttachmentDownloadController _content = content;
                        if (_content.state.value != AttachmentDownloadState.error) return;
                        Get.delete<AttachmentDownloadController>(tag: _content.attachment.guid);
                        content = AttachmentDownloader.startDownload(_content.attachment, onComplete: (file) {
                          setState(() {
                            content = file;
                          });
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Obx(() {
                          final isError = _content.state.value == AttachmentDownloadState.error;
                          final isProcessing = _content.state.value == AttachmentDownloadState.processing;
                          final isQueued = _content.state.value == AttachmentDownloadState.queued;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              SizedBox(
                                height: 40,
                                width: 40,
                                child: Center(
                                  child: isError
                                      ? Icon(iOS ? CupertinoIcons.arrow_clockwise : Icons.refresh, size: 30)
                                      : isProcessing
                                          ? (iOS
                                              ? const CupertinoActivityIndicator(radius: 14)
                                              : const CircularProgressIndicator())
                                          : isQueued
                                              ? Icon(iOS ? CupertinoIcons.clock : Icons.schedule, size: 30)
                                              : CircleProgressBar(
                                                  value: _content.progress.value?.toDouble() ?? 0,
                                                  backgroundColor: context.theme.colorScheme.outline,
                                                  foregroundColor: context.theme.colorScheme.onSurfaceVariant,
                                                ),
                                ),
                              ),
                              isError ? const SizedBox(height: 10) : const SizedBox(height: 5),
                              Text(
                                isError
                                    ? "Failed to download!"
                                    : isProcessing
                                        ? "Processing"
                                        : isQueued
                                            ? "Queued"
                                            : (_content.attachment.mimeType ?? ""),
                                style: context.theme.textTheme.bodyLarge!
                                    .copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            ],
                          );
                        }),
                      ),
                    );
                  } else {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Error loading attachment",
                          style: context.theme.textTheme.bodyLarge,
                        ),
                      ],
                    );
                  }
                },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
