import 'dart:async';
import 'dart:io';

import 'package:bluebubbles/helpers/attachment_downloader.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/layouts/image_viewer/image_viewer.dart';
import 'package:bluebubbles/layouts/image_viewer/video_viewer.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/attachment_downloader_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import "package:flutter/material.dart";
import 'package:flutter/services.dart';

class AttachmentFullscreenViewer extends StatefulWidget {
  AttachmentFullscreenViewer({
    Key key,
    @required this.attachment,
    @required this.showInteractions,
    this.currentChat,
  }) : super(key: key);
  final CurrentChat currentChat;
  final Attachment attachment;
  final bool showInteractions;

  static AttachmentFullscreenViewerState of(BuildContext context) {
    if (context == null) return null;

    return context.findAncestorStateOfType<AttachmentFullscreenViewerState>() ??
        null;
  }

  @override
  AttachmentFullscreenViewerState createState() =>
      AttachmentFullscreenViewerState();
}

class AttachmentFullscreenViewerState
    extends State<AttachmentFullscreenViewer> {
  PageController controller;
  int startingIndex;
  int currentIndex;
  Widget placeHolder;
  ScrollPhysics physics;
  StreamSubscription<NewMessageEvent> newMessageEventStream;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    getStartingIndex();

    // If the allAttachments is not updated
    if (startingIndex == null) {
      // Then fetch all of them and try again
      await widget.currentChat?.updateChatAttachments();
      getStartingIndex();
    }

    if (widget.currentChat != null)
      newMessageEventStream = NewMessageManager().stream.listen((event) async {
        // We don't need to do anything if there isn't a new message
        if (event.type != NewMessageType.ADD) return;

        // If the new message event isn't for this particular chat, don't do anything
        if (event.chatGuid != widget.currentChat.chat.guid) return;

        List<Attachment> older = widget.currentChat.chatAttachments.sublist(0);

        // Update all of the attachments
        await widget.currentChat.updateChatAttachments();
        List<Attachment> newer = widget.currentChat.chatAttachments.sublist(0);
        if (newer.length > older.length) {
          debugPrint("Increasing currentIndex from " +
              currentIndex.toString() +
              " to " +
              (newer.length - older.length + currentIndex).toString());
          currentIndex += newer.length - older.length;
          controller.animateToPage(currentIndex,
              duration: Duration(milliseconds: 0), curve: Curves.easeIn);
        }
      });

    controller = new PageController(initialPage: startingIndex ?? 0);
    if (this.mounted) setState(() {});
  }

  void getStartingIndex() {
    if (widget.currentChat == null) return;
    for (int i = 0; i < widget.currentChat.chatAttachments.length; i++) {
      if (widget.currentChat.chatAttachments[i].guid ==
          widget.attachment.guid) {
        startingIndex = i;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    physics = ThemeSwitcher.getScrollPhysics();
    if (this.mounted) setState(() {});
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
        color: Theme.of(context).accentColor,
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: controller != null
            ? PageView.builder(
                physics: physics,
                itemCount: widget.currentChat?.chatAttachments?.length ?? 1,
                itemBuilder: (BuildContext context, int index) {
                  debugPrint("Showing index: " + index.toString());
                  Attachment attachment = widget.currentChat != null
                      ? widget.currentChat.chatAttachments[index]
                      : widget.attachment;
                  String mimeType = attachment.mimeType;
                  mimeType = mimeType.substring(0, mimeType.indexOf("/"));
                  dynamic content = AttachmentHelper.getContent(attachment,
                      path: attachment.guid == null
                          ? attachment.transferName
                          : null);

                  if (content is File) {
                    content = content as File;
                    if (mimeType == "image") {
                      return ImageViewer(
                        key: Key(attachment.guid),
                        attachment: attachment,
                        file: content,
                        showInteractions: widget.showInteractions,
                      );
                    } else if (mimeType == "video") {
                      return VideoViewer(
                        key: Key(attachment.guid),
                        file: content,
                        attachment: attachment,
                        showInteractions: widget.showInteractions,
                      );
                    }
                  } else if (content is Attachment) {
                    content = content as Attachment;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: AttachmentDownloaderWidget(
                            key: Key(attachment.guid),
                            attachment: attachment,
                            onPressed: () {
                              new AttachmentDownloader(attachment);
                              content = AttachmentHelper.getContent(attachment);
                              if (this.mounted) setState(() {});
                            },
                            placeHolder: placeHolder,
                          ),
                        ),
                      ],
                    );
                  } else if (content is AttachmentDownloader) {
                    content = content as AttachmentDownloader;
                    if (widget.attachment.mimeType == null) return Container();
                    (content as AttachmentDownloader).stream.listen((event) {
                      if (event is File) {
                        content = event;
                        if (this.mounted) setState(() {});
                      }
                    }, onError: (error) {
                      content = widget.attachment;
                      if (this.mounted) setState(() {});
                    });
                    return StreamBuilder(
                      stream: content.stream,
                      builder: (BuildContext context, AsyncSnapshot snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            "Error loading",
                            style: Theme.of(context).textTheme.bodyText1,
                          );
                        }
                        if (snapshot.data is File) {
                          content = snapshot.data;
                          return Container();
                        } else {
                          double progress = 0.0;
                          if (snapshot.hasData) {
                            progress = snapshot.data["Progress"];
                          } else {
                            progress = content.progress;
                          }

                          return KeyedSubtree(
                            key: Key(attachment.guid),
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                placeHolder,
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        CircularProgressIndicator(
                                          value: progress,
                                          backgroundColor: Colors.grey,
                                          valueColor: AlwaysStoppedAnimation(
                                              Colors.white),
                                        ),
                                        ((content as AttachmentDownloader)
                                                    .attachment
                                                    .mimeType !=
                                                null)
                                            ? Container(height: 5.0)
                                            : Container(),
                                        (content.attachment.mimeType != null)
                                            ? Text(
                                                content.attachment.mimeType,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText1,
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
                      },
                    );
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

                  return Container();
                },
                onPageChanged: (int val) => currentIndex = val,
                controller: controller,
              )
            : Container(),
      ),
    );
  }
}
