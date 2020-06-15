import 'dart:io';
import 'dart:ui';

import 'package:android_intent/android_intent.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/attachment_helper.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubble_messages/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubble_messages/managers/contact_manager.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/socket_manager.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:latlong/latlong.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
// import 'package:photo_manager/photo_manager.dart';
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
  }) : super(key: key);

  final fromSelf;
  final Message message;
  final Message newerMessage;
  final Message olderMessage;
  final List<Message> reactions;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> {
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

  FlickManager _flickManager;

  bool play = false;
  double progress = 0.0;

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
    // if (widget.message.hasAttachments) {
    chatAttachments = [];
    Message.getAttachments(widget.message).then((data) {
      attachments = data;
      body = "";
      for (int i = 0; i < attachments.length; i++) {
        String appDocPath = SettingsManager().appDocDir.path;
        String pathName =
            "$appDocPath/attachments/${attachments[i].guid}/${attachments[i].transferName}";

        /**
           * Case 1: If the file exists (we can get the type), add the file to the chat's attachments
           * Case 2: If the attachment is currently being downloaded, get the AttachmentDownloader object and add it to the chat's attachments
           * Case 3: Otherwise, add the attachment, as is, meaning it needs to be downloaded
           */

        if (FileSystemEntity.typeSync(pathName) !=
            FileSystemEntityType.notFound) {
          chatAttachments.add(File(pathName));
          String mimeType = getMimeType(File(pathName));
          if (mimeType == "video") {
            _flickManager = FlickManager(
                videoPlayerController:
                    VideoPlayerController.file(File(pathName)));
          }
        } else if (SocketManager()
            .attachmentDownloaders
            .containsKey(attachments[i].guid)) {
          chatAttachments
              .add(SocketManager().attachmentDownloaders[attachments[i].guid]);
        } else {
          chatAttachments.add(attachments[i]);
        }
      }
      if (this.mounted) setState(() {});
    });
    // }
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

  List<Widget> _buildContent() {
    List<Widget> content = <Widget>[];
    for (int i = 0; i < chatAttachments.length; i++) {
      // Pull the blurhash from the attachment, based on the class type
      String blurhash =
          chatAttachments[i] is Attachment ? chatAttachments[i].blurhash : null;
      blurhash = chatAttachments[i] is AttachmentDownloader
          ? chatAttachments[i].attachment.blurhash
          : null;

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
                    child: Image.memory(
                      snapshot.data,
                      width: 300,
                      // height: 300,
                      fit: BoxFit.fitWidth,
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
        if (mimeType == "image") {
          content.add(
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.file(chatAttachments[i]),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (mimeType == "video") {
          content.add(
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: FlickVideoPlayer(
                flickManager: _flickManager,
              ),
            ),
          );
        } else if (mimeType == "audio") {
          //TODO fix this stuff
          content.add(
            AudioWidget.file(
              child: Container(
                height: 100,
                width: 200,
                child: Column(
                  children: <Widget>[
                    Center(
                      child: Text(
                        basename(chatAttachments[i].path),
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Spacer(
                      flex: 1,
                    ),
                    Row(
                      children: <Widget>[
                        ButtonTheme(
                          minWidth: 1,
                          height: 30,
                          child: RaisedButton(
                            onPressed: () {
                              setState(() {
                                play = !play;
                              });
                            },
                            child: Icon(
                              play ? Icons.pause : Icons.play_arrow,
                              size: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: progress,
                            onChanged: (double value) {
                              setState(() {
                                progress = value;
                              });
                            },
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              path: (chatAttachments[i] as File).path,
              play: play,
              onPositionChanged: (current, total) {
                debugPrint("${current.inMilliseconds / total.inMilliseconds}");
                setState(() {
                  progress = current.inMilliseconds / total.inMilliseconds;
                });
              },
              onFinished: () {
                debugPrint("on finished");
                setState(() {
                  play = false;
                });
              },
            ),
          );
        } else if (attachments[i].mimeType == "text/x-vlocation") {
          String _location = chatAttachments[i].readAsStringSync();
          Map<String, dynamic> location =
              AttachmentHelper.parseAppleLocation(_location);
          if (location["longitude"] != null &&
              location["longitude"].abs() < 90 &&
              location["latitude"] != null) {
            content.add(
              SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    center: LatLng(location["longitude"], location["latitude"]),
                    zoom: 14.0,
                  ),
                  layers: [
                    new TileLayerOptions(
                      urlTemplate:
                          "http://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
                      subdomains: ['0', '1', '2', '3'],
                      tileSize: 256,
                    ),
                    new MarkerLayerOptions(
                      markers: [
                        new Marker(
                          width: 40.0,
                          height: 40.0,
                          point: new LatLng(
                              location["longitude"], location["latitude"]),
                          builder: (ctx) => new Container(
                            child: new FlutterLogo(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        } else if (attachments[i].mimeType == "text/vcard") {
          String appleContact = chatAttachments[i].readAsStringSync();
          Contact contact = AttachmentHelper.parseAppleContact(appleContact);
          final initials = getInitials(contact.displayName, " ");
          content.add(
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 60,
                width: 250,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      // AndroidIntent intent = AndroidIntent(
                      //   action: 'action_view',
                      //   type: 'text/v-card',
                      //   data: Uri.file(chatAttachments[i].path).toString(),
                      // );
                      // await intent.launch();
                      MethodChannelInterface().invokeMethod("CreateContact", {
                        // "phone":
                        //     contact.phones != null && contact.phones.length > 0
                        //         ? contact.phones.first.value
                        //         : "",
                        // "email":
                        //     contact.emails != null && contact.emails.length > 0
                        //         ? contact.emails.first.value
                        //         : "",
                        // "displayName": contact.displayName
                        "path": "/attachments/" +
                            attachments[i].guid +
                            "/" +
                            basename((chatAttachments[i] as File).path)
                      });
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Text(
                            contact.displayName,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(
                            flex: 1,
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.topStart,
                                colors: [
                                  HexColor('a0a4af'),
                                  HexColor('848894')
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Container(
                              // child: Text("${widget.chat.title[0]}"),
                              child: (initials is Icon)
                                  ? initials
                                  : Text(
                                      initials,
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                              alignment: AlignmentDirectional.center,
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          debugPrint(mimeType);
        }

        // If it's an attachment, then it needs to be manually downloaded
      } else if (chatAttachments[i] is Attachment) {
        content.add(
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              placeholder,
              RaisedButton(
                onPressed: () {
                  chatAttachments[i] =
                      new AttachmentDownloader(chatAttachments[i]);
                  setState(() {});
                },
                color: HexColor('26262a').withAlpha(100),
                child: Text(
                  "Download",
                  style: TextStyle(color: Colors.white),
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
                    CircularProgressIndicator(
                      value: progress,
                    ),
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
    if (widget.message.text != null &&
        widget.message.text.length > 0 &&
        widget.message.text.substring(attachments.length).length > 0) {
      content.add(
        Text(
          widget.message.text.substring(attachments.length),
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }
    return content;
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
      return SentMessage(
        content: _buildContent(),
        deliveredReceipt: _buildDelieveredReceipt(),
        message: widget.message,
        olderMessage: widget.olderMessage,
        overlayEntry: _createOverlayEntry(),
        showTail: showTail,
      );
    } else {
      return ReceivedMessage(
        timeStamp: _buildTimeStamp(),
        reactions: _buildReactions(),
        content: _buildContent(),
        showTail: showTail,
        olderMessage: widget.olderMessage,
        message: widget.message,
        overlayEntry: _createOverlayEntry(),
      );
    }
  }

  Widget _buildDelieveredReceipt() {
    if (!showTail) return Container();
    if (widget.message.dateRead != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              "Read",
              style: TextStyle(
                color: Colors.white,
              ),
            )
          ],
        ),
      );
    } else if (widget.message.dateDelivered != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              "Delivered",
              style: TextStyle(
                color: Colors.white,
              ),
            )
          ],
        ),
      );
    } else {
      return Container();
    }
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
    return Stack(
      alignment: widget.message.isFromMe
          ? Alignment.bottomRight
          : Alignment.bottomLeft,
      children: <Widget>[
        for (int i = 0; i < reactionIcon.length; i++)
          Padding(
            padding: EdgeInsets.fromLTRB(i.toDouble() * 20.0, 0, 0, 0),
            child: Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: HexColor('26262a'),
                  boxShadow: [
                    new BoxShadow(
                      blurRadius: 5.0,
                      offset:
                          Offset(3.0 * (widget.message.isFromMe ? 1 : -1), 0.0),
                      color: Colors.black,
                    )
                  ]),
              child: reactionIcon[i],
            ),
          ),
      ],
    );
  }

  OverlayEntry _createOverlayEntry() {
    attachments.forEach((element) {
      debugPrint(element.mimeType);
    });
    List<Widget> reactioners = <Widget>[];
    reactions.keys.forEach(
      (element) {
        reactions[element].forEach(
          (reaction) async {
            if (reaction.handle != null) {
              reactioners.add(
                Text(
                  getContactTitle(
                      ContactManager().contacts, reaction.handle.address),
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              );
            }
          },
        );
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
  void dispose() {
    if (_flickManager != null) _flickManager.dispose();
    super.dispose();
  }
}
