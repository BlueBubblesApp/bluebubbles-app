import 'dart:io';
import 'dart:ui';

import 'package:android_intent/android_intent.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:bluebubble_messages/blocs/message_bloc.dart';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/attachment_helper.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/audio_player_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/contact_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/image_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/loaction_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/regular_file_opener.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_players/video_widget.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/message_content/media_file.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:latlong/latlong.dart';
import 'package:link_previewer/link_previewer.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../helpers/hex_color.dart';
import '../../../helpers/utils.dart';
import '../../../repository/models/message.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({
    Key key,
    this.fromSelf,
    this.message,
    this.olderMessage,
    this.newerMessage,
    this.reactions,
    this.showHandle,
    this.customContent,
    this.shouldFadeIn,
  }) : super(key: key);

  final fromSelf;
  final Message message;
  final Message newerMessage;
  final Message olderMessage;
  final List<Message> reactions;
  final bool showHandle;
  final bool shouldFadeIn;

  final List<Widget> customContent;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget>
    with AutomaticKeepAliveClientMixin {
  List<Attachment> attachments = <Attachment>[];
  String body;
  List chatAttachments = [];
  bool showTail = true;
  final String like = "like";
  final String love = "love";
  final String dislike = "dislike";
  final String question = "question";
  final String emphasize = "emphasize";
  final String laugh = "laugh";
  Map<String, List<Message>> reactions = new Map();
  Widget blurredImage;
  bool _hasLinks = false;

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    reactions[like] = [];
    reactions[love] = [];
    reactions[dislike] = [];
    reactions[question] = [];
    reactions[emphasize] = [];
    reactions[laugh] = [];

    widget.reactions.forEach((reaction) {
      reactions[reaction.associatedMessageType].add(reaction);
    });
    setState(() {});
  }

  void getAttachments() {
    if (widget.customContent != null) return;
    chatAttachments = [];
    Message.getAttachments(widget.message).then((value) {
      attachments = [];
      for (Attachment attachment in value) {
        if (attachment.mimeType != null) {
          attachments.add(attachment);
        } else {
          _hasLinks = true;
        }
      }
      body = "";
      for (int i = 0; i < attachments.length; i++) {
        if (attachments[i] == null) continue;

        String appDocPath = SettingsManager().appDocDir.path;
        String pathName =
            "$appDocPath/attachments/${attachments[i].guid}/${attachments[i].transferName}";

        /**
           * Case 1: If the file exists (we can get the type), add the file to the chat's attachments
           * Case 2: If the attachment is currently being downloaded, get the AttachmentDownloader object and add it to the chat's attachments
           * Case 3: If the attachment is a text-based one, automatically auto-download
           * Case 4: Otherwise, add the attachment, as is, meaning it needs to be downloaded
           */

        if (FileSystemEntity.typeSync(pathName) !=
            FileSystemEntityType.notFound) {
          chatAttachments.add(File(pathName));
          String mimeType = getMimeType(File(pathName));
          if (mimeType == "video") {}
        } else if (SocketManager()
            .attachmentDownloaders
            .containsKey(attachments[i].guid)) {
          chatAttachments
              .add(SocketManager().attachmentDownloaders[attachments[i].guid]);
        } else if (attachments[i].mimeType == null ||
            attachments[i].mimeType.startsWith("text/")) {
          AttachmentDownloader downloader =
              new AttachmentDownloader(attachments[i]);
          chatAttachments.add(downloader);
        } else {
          chatAttachments.add(attachments[i]);
        }
      }
      if (this.mounted) setState(() {});
    });
  }

  String getMimeType(File attachment) {
    String mimeType = mime(basename(attachment.path));
    if (mimeType == null) return "";
    mimeType = mimeType.substring(0, mimeType.indexOf("/"));
    return mimeType;
  }

  @override
  void initState() {
    super.initState();
    if (widget.newerMessage != null) {
      showTail = withinTimeThreshold(widget.message, widget.newerMessage,
              threshold: 1) ||
          !sameSender(widget.message, widget.newerMessage);
    }
    getAttachments();
  }

  bool withinTimeThreshold(Message first, Message second, {threshold: 5}) {
    if (first == null || second == null) return false;
    return first.dateCreated.difference(second.dateCreated).inMinutes >
        threshold;
  }

  List<Widget> _buildContent(BuildContext context) {
    if (widget.customContent != null) {
      return widget.customContent;
    }
    List<Widget> content = <Widget>[];
    for (int i = 0; i < chatAttachments.length; i++) {
      // Pull the blurhash from the attachment, based on the class type
      String blurhash = chatAttachments[i] is AttachmentDownloader
          ? chatAttachments[i].attachment.blurhash
          : chatAttachments[i] is Attachment
              ? chatAttachments[i].blurhash
              : null;

      // Skip over unnecessary hyperlink images
      if (chatAttachments[i] is File &&
          attachments[i].mimeType == null &&
          i + 1 < attachments.length &&
          attachments[i + 1].mimeType == null) {
        continue;
      }

      // Convert the placeholder to a Widget
      Widget placeholder = (blurhash == null)
          ? Container()
          : FutureBuilder(
              future: blurHashDecode(blurhash),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: AspectRatio(
                      aspectRatio: attachments[i].width / attachments[i].height,
                      child: Image.memory(
                        snapshot.data,
                        width: 300,
                        // height: 300,
                        fit: BoxFit.fill,
                      ),
                    ),
                  );
                } else {
                  return Container();
                }
              },
            );

      // If it's a file, it's already been downlaoded, so just display it
      if (chatAttachments[i] is File) {
        String mimeType = attachments[i].mimeType;
        if (mimeType != null)
          mimeType = mimeType.substring(0, mimeType.indexOf("/"));
        if (mimeType == null || mimeType == "image") {
          content.add(
            MediaFile(
              child: ImageWidget(
                attachment: attachments[i],
                file: chatAttachments[i],
              ),
              attachment: attachments[i],
            ),
          );
        } else if (mimeType == "video") {
          content.add(
            MediaFile(
              attachment: attachments[i],
              child: VideoWidget(
                attachment: attachments[i],
                file: chatAttachments[i],
              ),
            ),
          );
        } else if (mimeType == "audio") {
          //TODO fix this stuff
          content.add(
            MediaFile(
              attachment: attachments[i],
              child: AudioPlayerWiget(
                attachment: attachments[i],
                file: chatAttachments[i],
              ),
            ),
          );
        } else if (attachments[i].mimeType == "text/x-vlocation") {
          content.add(
            MediaFile(
              attachment: attachments[i],
              child: LocationWidget(
                file: chatAttachments[i],
                attachment: attachments[i],
              ),
            ),
          );
        } else if (attachments[i].mimeType == "text/vcard") {
          content.add(
            MediaFile(
              attachment: attachments[i],
              child: ContactWidget(
                file: chatAttachments[i],
                attachment: attachments[i],
              ),
            ),
          );
        } else {
          content.add(
            MediaFile(
              attachment: attachments[i],
              child: RegularFileOpener(
                file: chatAttachments[i],
                attachment: attachments[i],
              ),
            ),
          );
        }

        // If it's an attachment, then it needs to be manually downloaded
      } else if (chatAttachments[i] is Attachment) {
        content.add(
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              placeholder,
              CupertinoButton(
                padding:
                    EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
                onPressed: () {
                  chatAttachments[i] =
                      new AttachmentDownloader(chatAttachments[i]);
                  setState(() {});
                },
                color: Colors.transparent,
                child: Column(
                  children: <Widget>[
                    Text(
                      chatAttachments[i].getFriendlySize(),
                      style: TextStyle(fontSize: 12),
                    ),
                    Icon(Icons.cloud_download, size: 28.0),
                    (chatAttachments[i].mimeType != null)
                        ? Text(
                            chatAttachments[i].mimeType,
                            style: TextStyle(fontSize: 12),
                          )
                        : Container()
                  ],
                ),
              ),
            ],
          ),
        );

        // If it's an AttachmentDownloader, it is currently being downloaded
      } else if (chatAttachments[i] is AttachmentDownloader) {
        content.add(
          StreamBuilder(
            stream: chatAttachments[i].stream,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.hasError) {
                return Text(
                  "Error loading",
                  style: TextStyle(color: Colors.white),
                );
              }
              if (snapshot.data is File) {
                getAttachments();
                return Container();
              } else {
                double progress = 0.0;
                if (snapshot.hasData) {
                  progress = snapshot.data["Progress"];
                } else {
                  progress = chatAttachments[i].progress;
                }

                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    placeholder,
                    Padding(
                      padding: EdgeInsets.all(5.0),
                      child: Column(
                        children: <Widget>[
                          CircularProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                          ((chatAttachments[i] as AttachmentDownloader)
                                      .attachment
                                      .mimeType !=
                                  null)
                              ? Container(height: 5.0)
                              : Container(),
                          (chatAttachments[i].attachment.mimeType != null)
                              ? Text(chatAttachments[i].attachment.mimeType,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white))
                              : Container()
                        ],
                      ),
                    )
                  ],
                );
              }
            },
          ),
        );
      } else {
        content.add(
          Text(
            "Error loading",
            style: TextStyle(color: Colors.white),
          ),
        );
      }
    }

    if (_hasLinks) {
      String link = widget.message.text;
      if (!Uri.parse(widget.message.text).isAbsolute) {
        link = "https://" + widget.message.text;
      }
      content.add(
        LinkPreviewer(
          link: link,
        ),
      );
    } else if (!isEmptyString(widget.message.text) && attachments.length > 0) {
      content.add(
        Padding(
          padding: EdgeInsets.only(left: 20, right: 10),
          child: Text(
            widget.message.text,
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    } else if (!isEmptyString(widget.message.text) && attachments.length == 0) {
      content.add(
        Text(
          widget.message.text,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }

    // Add spacing to items in a message
    List<Widget> output = [];
    for (int i = 0; i < content.length; i++) {
      output.add(content[i]);
      if (i != content.length - 1) {
        output.add(Container(height: 8.0));
      }
    }

    return output;
  }

  Widget _buildTimeStamp() {
    if (widget.olderMessage != null &&
        withinTimeThreshold(widget.message, widget.olderMessage,
            threshold: 30)) {
      DateTime timeOfolderMessage = widget.olderMessage.dateCreated;
      String time = new DateFormat.jm().format(timeOfolderMessage);
      String date;
      if (widget.olderMessage.dateCreated.isToday()) {
        date = "Today";
      } else if (widget.olderMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${timeOfolderMessage.month.toString()}/${timeOfolderMessage.day.toString()}/${timeOfolderMessage.year.toString()}";
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "$date, $time",
              style: TextStyle(
                color: Colors.white,
              ),
            )
          ],
        ),
      );
    }
    return Container();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fromSelf) {
      List<Widget> content = _buildContent(context);
      return SentMessage(
        content: content,
        deliveredReceipt: widget.customContent != null
            ? Container()
            : _buildDelieveredReceipt(),
        message: widget.message,
        overlayEntry: _createOverlayEntry(),
        showTail: showTail,
        limited: widget.customContent == null,
        shouldFadeIn: widget.shouldFadeIn,
      );
    } else {
      return ReceivedMessage(
          timeStamp: _buildTimeStamp(),
          reactions: _buildReactions(),
          content: _buildContent(context),
          showTail: showTail,
          olderMessage: widget.olderMessage,
          message: widget.message,
          overlayEntry: _createOverlayEntry(),
          showHandle: widget.showHandle);
    }
  }

  Widget _buildDelieveredReceipt() {
    if (!showTail) return Container();
    if (widget.message.dateRead == null && widget.message.dateDelivered == null)
      return Container();

    String text = "Delivered";
    if (widget.message.dateRead != null) text = "Read";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withAlpha(80),
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildReactions() {
    if (widget.reactions.length == 0) return Container();
    List<Widget> reactionIcon = <Widget>[];
    reactions.keys.forEach((String key) {
      if (reactions[key].length != 0) {
        reactionIcon.add(
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              'assets/reactions/$key-black.svg',
              color: key == love ? Colors.pink : Colors.white,
            ),
          ),
        );
      }
    });
    // return Stack(
    //   alignment: widget.message.isFromMe
    //       ? Alignment.bottomRight
    //       : Alignment.bottomLeft,
    //   children: <Widget>[
    //     for (int i = 0; i < reactionIcon.length; i++)
    //       Padding(
    //         padding: EdgeInsets.fromLTRB(i.toDouble() * 20.0, 0, 0, 0),
    //         child: Container(
    //           height: 30,
    //           width: 30,
    //           decoration: BoxDecoration(
    //             borderRadius: BorderRadius.circular(100),
    //             color: HexColor('26262a'),
    //             boxShadow: [
    //               new BoxShadow(
    //                 blurRadius: 5.0,
    //                 offset:
    //                     Offset(3.0 * (widget.message.isFromMe ? 1 : -1), 0.0),
    //                 color: Colors.black,
    //               )
    //             ],
    //           ),
    //           child: reactionIcon[i],
    //         ),
    //       ),
    //   ],
    // );
    return Container();
  }

  OverlayEntry _createOverlayEntry() {
    List<Widget> reactioners = <Widget>[];
    reactions.keys.forEach(
      (element) {
        List<Widget> reactionGroup = <Widget>[];
        List<String> names = [];
        reactions[element].forEach(
          (message) async {
            if (message.handle == null) return;

            String name = "You";
            if (!message.isFromMe) {
              name = getContactTitle(
                  ContactManager().contacts, message.handle.address);
            }

            names.add(name);
          },
        );

        if (reactions[element].length > 0) {
          reactionGroup.add(Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              'assets/reactions/$element-black.svg',
              height: 24.0,
              width: 24.0,
              color: element == love ? Colors.pink : Colors.white,
            ),
          ));

          reactionGroup.add(
            Text(
              names.join(", "),
              softWrap: true,
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          );

          reactioners.add(Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: reactionGroup));
        }
      },
    );

    OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  debugPrint("remove entry");
                  entry.remove();
                },
                child: Container(
                  color: Colors.black.withAlpha(200),
                  child: Column(
                    children: <Widget>[
                      Spacer(
                        flex: 3,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            height: 120,
                            width: MediaQuery.of(context).size.width * 9 / 5,
                            color: HexColor('26262a').withAlpha(200),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: reactioners,
                            ),
                          ),
                        ),
                      ),
                      Spacer(
                        flex: 20,
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
    return entry;
  }

  @override
  bool get wantKeepAlive => true;
}
