import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubbles/layouts/image_viewer/video_viewer.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/custom_dismissible.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/intents.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class AttachmentFullscreenViewer extends StatefulWidget {
  AttachmentFullscreenViewer({
    Key? key,
    required this.attachment,
    required this.showInteractions,
    this.currentChat,
  }) : super(key: key);
  final ChatController? currentChat;
  final Attachment attachment;
  final bool showInteractions;

  static AttachmentFullscreenViewerState? of(BuildContext context) {
    return context.findAncestorStateOfType<AttachmentFullscreenViewerState>();
  }

  @override
  AttachmentFullscreenViewerState createState() => AttachmentFullscreenViewerState();
}

class AttachmentFullscreenViewerState extends State<AttachmentFullscreenViewer> {
  PageController? controller;
  int? startingIndex;
  late int currentIndex;
  late Widget placeHolder;
  ScrollPhysics? physics;
  StreamSubscription<NewMessageEvent>? newMessageEventStream;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      currentIndex = 0;
      controller = PageController(initialPage: 0);
    } else {
      init();
    }
  }

  void init() async {
    getStartingIndex();

    // If the allAttachments is not updated
    if (startingIndex == null) {
      // Then fetch all of them and try again
      await widget.currentChat?.updateChatAttachments();
      getStartingIndex();
    }

    if (widget.currentChat != null) {
      newMessageEventStream = NewMessageManager().stream.listen((event) async {
        // We don't need to do anything if there isn't a new message
        if (event.type != NewMessageType.ADD) return;

        // If the new message event isn't for this particular chat, don't do anything
        if (event.chatGuid != widget.currentChat!.chat.guid) return;

        List<Attachment> older = widget.currentChat!.chatAttachments.sublist(0);

        // Update all of the attachments
        await widget.currentChat!.updateChatAttachments();
        List<Attachment> newer = widget.currentChat!.chatAttachments.sublist(0);
        if (newer.length > older.length) {
          Logger.info("Increasing currentIndex from " +
              currentIndex.toString() +
              " to " +
              (newer.length - older.length + currentIndex).toString());
          currentIndex += newer.length - older.length;
          controller!.animateToPage(currentIndex, duration: Duration(milliseconds: 0), curve: Curves.easeIn);
        }
      });
    }

    currentIndex = startingIndex ?? 0;
    controller = PageController(initialPage: startingIndex ?? 0);
    if (mounted) setState(() {});
  }

  void getStartingIndex() {
    if (widget.currentChat == null) return;
    for (int i = 0; i < widget.currentChat!.chatAttachments.length; i++) {
      if (widget.currentChat!.chatAttachments[i].guid == widget.attachment.guid) {
        startingIndex = i;
      }
    }
  }

  @override
  void dispose() {
    newMessageEventStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    placeHolder = ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        height: 150,
        width: 200,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
    return TitleBarWrapper(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: SettingsManager().settings.immersiveMode.value
              ? Colors.transparent
              : Theme.of(context).backgroundColor, // navigation bar color
          systemNavigationBarIconBrightness:
              Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
          statusBarColor: Colors.transparent, // status bar color
        ),
        child: Actions(
          actions: {
            GoBackIntent: GoBackAction(context),
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: controller != null
                ? FocusScope(
                    child: Focus(
                      focusNode: FocusNode(),
                      autofocus: true,
                      onKey: (node, event) {
                        Logger.info(
                            "Got key label ${event.data.keyLabel}, physical key ${event.data.physicalKey.toString()}, logical key ${event.data.logicalKey.toString()}",
                            tag: "RawKeyboardListener");
                        if (event.data.physicalKey.debugName == "Arrow Right") {
                          if (SettingsManager().settings.fullscreenViewerSwipeDir.value == SwipeDirection.RIGHT) {
                            controller!.previousPage(duration: Duration(milliseconds: 300), curve: Curves.easeIn);
                          } else {
                            controller!.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeIn);
                          }
                        } else if (event.data.physicalKey.debugName == "Arrow Left") {
                          if (SettingsManager().settings.fullscreenViewerSwipeDir.value == SwipeDirection.LEFT) {
                            controller!.previousPage(duration: Duration(milliseconds: 300), curve: Curves.easeIn);
                          } else {
                            controller!.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeIn);
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: PageView.builder(
                        physics: physics,
                        reverse: SettingsManager().settings.fullscreenViewerSwipeDir.value == SwipeDirection.RIGHT,
                        itemCount: kIsWeb ? 1 : widget.currentChat?.chatAttachments.length ?? 1,
                        itemBuilder: (BuildContext context, int index) {
                          return CustomDismissible(
                            direction: physics is NeverScrollableScrollPhysics
                                ? CustomDismissDirection.none
                                : CustomDismissDirection.vertical,
                            key: Key(
                                '${kIsWeb ? widget.attachment.guid : widget.currentChat != null ? widget.currentChat!.chatAttachments[index].guid : widget.attachment.guid}'),
                            onDismissed: (_) => Navigator.of(context).pop(),
                            child: Builder(builder: (_) {
                              Logger.info("Showing index: " + index.toString());
                              Attachment attachment = !kIsWeb && widget.currentChat != null
                                  ? widget.currentChat!.chatAttachments[index]
                                  : widget.attachment;
                              String mimeType = attachment.mimeType!;
                              mimeType = mimeType.substring(0, mimeType.indexOf("/"));
                              dynamic content = AttachmentHelper.getContent(attachment,
                                  path: attachment.guid == null ? attachment.transferName : null);

                              String viewerKey =
                                  attachment.guid ?? attachment.transferName ?? Random().nextInt(100).toString();

                              if (content is PlatformFile) {
                                content = content;
                                if (mimeType == "image") {
                                  return ImageViewer(
                                    key: Key(viewerKey),
                                    attachment: attachment,
                                    file: content,
                                    showInteractions: widget.showInteractions,
                                  );
                                } else if (mimeType == "video") {
                                  return VideoViewer(
                                    key: Key(viewerKey),
                                    file: content,
                                    attachment: attachment,
                                    showInteractions: widget.showInteractions,
                                  );
                                } else {
                                  return RegularFileOpener(
                                    attachment: attachment,
                                    file: content,
                                  );
                                }
                              } else if (content is Attachment) {
                                content = content;
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Center(
                                      child: AttachmentDownloaderWidget(
                                        key: Key(attachment.guid ??
                                            attachment.transferName ??
                                            Random().nextInt(100).toString()),
                                        attachment: attachment,
                                        onPressed: () {
                                          Get.put(AttachmentDownloadController(attachment: attachment),
                                              tag: attachment.guid);
                                          content = AttachmentHelper.getContent(attachment);
                                          if (mounted) setState(() {});
                                        },
                                        placeHolder: placeHolder,
                                      ),
                                    ),
                                  ],
                                );
                              } else if (content is AttachmentDownloadController) {
                                if (widget.attachment.mimeType == null) return Container();
                                ever<PlatformFile?>(content.file, (file) {
                                  if (file != null) {
                                    content = file;
                                    if (mounted) setState(() {});
                                  }
                                }, onError: (error) {
                                  content = widget.attachment;
                                  if (mounted) setState(() {});
                                });
                                return Obx(() {
                                  // don't remove!! needed to prevent Obx from exception
                                  // improper use of GetX
                                  // ignore: unused_local_variable
                                  final placeholderVar = null.obs.value;
                                  if (content.error.value = true) {
                                    return Text(
                                      "Error loading",
                                      style: Theme.of(context).textTheme.bodyText1,
                                    );
                                  }
                                  if (content.file.value != null) {
                                    content = content.file.value;
                                    return Container();
                                  } else {
                                    return KeyedSubtree(
                                      key: Key(viewerKey),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: <Widget>[
                                          placeHolder,
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: <Widget>[
                                                  CircularProgressIndicator(
                                                    value: content.progress.value?.toDouble() ?? 0,
                                                    backgroundColor: Colors.grey,
                                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                                  ),
                                                  ((content as AttachmentDownloadController).attachment.mimeType !=
                                                          null)
                                                      ? Container(height: 5.0)
                                                      : Container(),
                                                  (content.attachment.mimeType != null)
                                                      ? Text(
                                                          content.attachment.mimeType,
                                                          style: Theme.of(context).textTheme.bodyText1,
                                                        )
                                                      : Container()
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                });
                              } else {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Error loading",
                                      style: Theme.of(context).textTheme.bodyText1,
                                    ),
                                  ],
                                );
                              }
                            }),
                          );
                        },
                        onPageChanged: (int val) => currentIndex = val,
                        controller: controller,
                      ),
                    ),
                  )
                : Container(
                    child: Center(
                    child: CircularProgressIndicator(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                    ),
                  )),
          ),
        ),
      ),
    );
  }
}
