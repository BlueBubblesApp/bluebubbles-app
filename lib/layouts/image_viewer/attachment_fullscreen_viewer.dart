import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubbles/layouts/image_viewer/video_viewer.dart';
import 'package:bluebubbles/layouts/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/intents.dart';
import 'package:bluebubbles/repository/models/dart_vlc.dart';
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
    if (kIsWeb || !widget.showInteractions) {
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
      newMessageEventStream = MessageManager().stream.listen((event) async {
        // We don't need to do anything if there isn't a new message
        if (event.type != NewMessageType.ADD) return;

        // If the new message event isn't for this particular chat, don't do anything
        if (event.chatGuid != widget.currentChat!.chat.guid) return;

        List<Attachment> older = widget.currentChat!.chatAttachments.sublist(0);

        // Update all of the attachments
        await widget.currentChat!.updateChatAttachments();
        List<Attachment> newer = widget.currentChat!.chatAttachments.sublist(0);
        if (newer.length > older.length) {
          Logger.info("Increasing currentIndex from $currentIndex to ${newer.length - older.length + currentIndex}");
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
    controller?.dispose();
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
        color: context.theme.colorScheme.properSurface,
      ),
    );
    return TitleBarWrapper(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
          systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
          statusBarColor: Colors.transparent, // status bar color
          statusBarIconBrightness: SettingsManager().settings.skin.value != Skins.iOS ? Brightness.light : context.theme.colorScheme.brightness.opposite,
        ),
        child: Actions(
          actions: {
            GoBackIntent: GoBackAction(context),
          },
          child: Scaffold(
            appBar: SettingsManager().settings.skin.value != Skins.iOS ? null : AppBar(
              leading: TextButton(
                child: Text("Done", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              leadingWidth: 75,
              title: Text(kIsWeb || !widget.showInteractions ? "Media" : "${currentIndex + 1} of ${widget.currentChat?.chatAttachments.length}", style: context.theme.textTheme.titleLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)),
              centerTitle: SettingsManager().settings.skin.value == Skins.iOS,
              iconTheme: IconThemeData(color: context.theme.colorScheme.primary),
              backgroundColor: context.theme.colorScheme.properSurface,
              systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
            ),
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
                        physics: physics ?? ThemeSwitcher.getScrollPhysics(),
                        reverse: SettingsManager().settings.fullscreenViewerSwipeDir.value == SwipeDirection.RIGHT,
                        itemCount: kIsWeb ? 1 : widget.currentChat?.chatAttachments.length ?? 1,
                        itemBuilder: (BuildContext context, int index) {
                          Logger.info("Showing index: $index");
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
                            } else if (!kIsDesktop && mimeType == "video") {
                              if (kIsDesktop) {
                                Player player = Player(id: attachment.hashCode)
                                  ..add(Media.file(File(content.path!)));
                                player.play();
                                Future.delayed(Duration.zero, () async => await player.playbackStream.first)
                                    .then((state) {
                                  player.pause();
                                  player.seek(Duration.zero);
                                });
                                return Video(player: player);
                              }
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
                                  style: context.theme.textTheme.bodyLarge,
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
                                                backgroundColor: context.theme.colorScheme.properSurface,
                                                valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                              ),
                                              ((content as AttachmentDownloadController).attachment.mimeType !=
                                                  null)
                                                  ? Container(height: 5.0)
                                                  : Container(),
                                              (content.attachment.mimeType != null)
                                                  ? Text(
                                                content.attachment.mimeType,
                                                style: context.theme.textTheme.bodyLarge,
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
                                  style: context.theme.textTheme.bodyLarge,
                                ),
                              ],
                            );
                          }
                        },
                        onPageChanged: (int val) {
                          currentIndex = val;
                          setState(() {});
                        },
                        controller: controller,
                      ),
                    ),
                  )
                : Container(
                    child: Center(
                    child: CircularProgressIndicator(
                      backgroundColor: context.theme.colorScheme.properSurface,
                      valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                    ),
                  )),
          ),
        ),
      ),
    );
  }
}
