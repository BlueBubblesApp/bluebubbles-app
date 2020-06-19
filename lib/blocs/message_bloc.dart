import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/helpers/attachment_helper.dart';
import 'package:bluebubble_messages/helpers/hex_color.dart';
import 'package:bluebubble_messages/helpers/message_helper.dart';
import 'package:bluebubble_messages/helpers/utils.dart';
import 'package:bluebubble_messages/managers/method_channel_interface.dart';
import 'package:bluebubble_messages/managers/new_message_manager.dart';
import 'package:bluebubble_messages/managers/settings_manager.dart';
import 'package:bluebubble_messages/repository/models/attachment.dart';
import 'package:bluebubble_messages/repository/models/chat.dart';
import 'package:bluebubble_messages/repository/models/message.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
import 'package:video_player/video_player.dart';
import 'package:latlong/latlong.dart';

import '../socket_manager.dart';

class MessageBloc {
  final _messageController = StreamController<List<Message>>.broadcast();

  Stream<List<Message>> get stream => _messageController.stream;

  List<Message> _messageCache = <Message>[];
  List<Message> _allMessages = <Message>[];
  Map<String, List<Widget>> _attachments = new Map();

  Map<String, List<Message>> _reactions = new Map();

  List<Message> get messages =>
      _allMessages.length > 0 ? _allMessages : _messageCache;

  Map<String, List<Message>> get reactions => _reactions;

  Map<String, List<Widget>> get attachments => _attachments;

  Chat _currentChat;

  MessageBloc(Chat chat) {
    _currentChat = chat;
    getMessages(chat);
    NewMessageManager().stream.listen((Map<String, Message> event) {
      if (event.containsKey(_currentChat.guid)) {
        //if there even is a chat specified in the newmessagemanager update
        if (event[_currentChat.guid] == null) {
          //if no message is specified in the newmessagemanager update
          getMessages(chat);
        } else {
          //if there is a specific message to insert
          insert(event[_currentChat.guid]);
          // _messageController.sink.add(_messageCache);
          // getMessages(chat);
        }
      } else if (event.keys.first == null) {
        //if there is no chat specified in the newmessagemanager update
        getMessages(_currentChat);
      }
    });
  }

  void insert(Message message) {
    if (_allMessages.length == 0) {
      //if messagebloc is in the background and we are only relying on the cache
      for (int i = 0; i < _messageCache.length; i++) {
        //if _messageCache[i] dateCreated is earlier than the new message, insert at that index
        if (_messageCache[i].dateCreated.compareTo(message.dateCreated) < 0) {
          _messageCache.insert(i, message);
          break;
        }
      }
      _messageController.sink.add(_messageCache);
    } else {
      //if messagebloc is currently active, as in the conversation view is open
      for (int i = 0; i < _allMessages.length; i++) {
        //if _allMessages[i] dateCreated is earlier than the new message, insert at that index
        if (_allMessages[i].dateCreated.compareTo(message.dateCreated) < 0) {
          _allMessages.insert(i, message);
          break;
        }
      }
      _messageController.sink.add(_allMessages);
    }
  }

  void getMessages(Chat chat) async {
    List<Message> messages = await Chat.getMessages(chat);
    messages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
    _allMessages = messages;
    _messageCache = [];
    for (int i = 0; i < (messages.length <= 25 ? messages.length : 25); i++) {
      _messageCache.add(messages[i]);
    }
    _messageController.sink.add(messages);
    for (int i = 0; i < messages.length; i++) {
      List<Widget> attachmentsForMessage = await getAttachments(messages[i]);
      if (attachmentsForMessage.length > 0) {
        _attachments[messages[i].guid] = attachmentsForMessage;
      }
      if (i == messages.length - 1) {
        _messageController.sink.add(messages);
      }
    }
    await getReactions(0);
  }

  Future<List<Widget>> getAttachments(Message message) async {
    // if (widget.message.hasAttachments) {
    List<Attachment> attachments = await Message.getAttachments(message);
    List chatAttachments = [];
    FlickManager _flickManager;
    // if (attachments.length == 0) return [];
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
        if (mimeType == "video") {
          _flickManager = FlickManager(
              autoPlay: false,
              videoPlayerController:
                  VideoPlayerController.file(File(pathName)));
        }
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
    List<Widget> content = <Widget>[];
    for (int i = 0; i < chatAttachments.length; i++) {
      // Pull the blurhash from the attachment, based on the class type
      String blurhash =
          chatAttachments[i] is Attachment ? chatAttachments[i].blurhash : null;
      blurhash = chatAttachments[i] is AttachmentDownloader
          ? chatAttachments[i].attachment.blurhash
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
        if ((mimeType == null || mimeType == "image")) {
          content.add(
            Stack(
              children: <Widget>[
                Image.file(chatAttachments[i]),
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
          // content.add(
          //   AudioWidget.file(
          //     child: Container(
          //       height: 100,
          //       width: 200,
          //       child: Column(
          //         children: <Widget>[
          //           Center(
          //             child: Text(
          //               basename(chatAttachments[i].path),
          //               style: TextStyle(
          //                 color: Colors.white,
          //               ),
          //             ),
          //           ),
          //           Spacer(
          //             flex: 1,
          //           ),
          //           Row(
          //             children: <Widget>[
          //               ButtonTheme(
          //                 minWidth: 1,
          //                 height: 30,
          //                 child: RaisedButton(
          //                   onPressed: () {
          //                     setState(() {
          //                       play = !play;
          //                     });
          //                   },
          //                   child: Icon(
          //                     play ? Icons.pause : Icons.play_arrow,
          //                     size: 15,
          //                   ),
          //                 ),
          //               ),
          //               Expanded(
          //                 child: Slider(
          //                   value: progress,
          //                   onChanged: (double value) {
          //                     setState(() {
          //                       progress = value;
          //                     });
          //                   },
          //                 ),
          //               )
          //             ],
          //           ),
          //         ],
          //       ),
          //     ),
          //     path: (chatAttachments[i] as File).path,
          //     play: play,
          //     onPositionChanged: (current, total) {
          //       debugPrint("${current.inMilliseconds / total.inMilliseconds}");
          //       setState(() {
          //         progress = current.inMilliseconds / total.inMilliseconds;
          //       });
          //     },
          //     onFinished: () {
          //       debugPrint("on finished");
          //       setState(() {
          //         play = false;
          //       });
          //     },
          //   ),
          // );
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
        }

        // If it's an attachment, then it needs to be manually downloaded
      } else if (chatAttachments[i] is Attachment) {
        content.add(
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CupertinoButton(
                padding:
                    EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
                onPressed: () async {
                  chatAttachments[i] =
                      new AttachmentDownloader(chatAttachments[i]);
                  //TODO figure out how to do this
                  // setState(() {});
                  _attachments[message.guid] = await getAttachments(message);
                },
                color: Colors.transparent,
                child: Column(children: <Widget>[
                  Text(chatAttachments[i].getFriendlySize(),
                      style: TextStyle(fontSize: 12)),
                  Icon(Icons.cloud_download, size: 28.0),
                  (chatAttachments[i].mimeType != null)
                      ? Text(chatAttachments[i].mimeType,
                          style: TextStyle(fontSize: 12))
                      : Container()
                ]),
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
                getAttachments(message)
                    .then((value) => _attachments[message.guid] = value);
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
                      child: Column(children: <Widget>[
                        CircularProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                        (chatAttachments[i].attachment.mimeType != null)
                            ? Container(height: 5.0)
                            : Container(),
                        (chatAttachments[i].attachment.mimeType != null)
                            ? Text(chatAttachments[i].attachment.mimeType,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white))
                            : Container()
                      ]),
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
    return content;
  }

  static String getMimeType(File attachment) {
    String mimeType = mime(basename(attachment.path));
    if (mimeType == null) return "";
    mimeType = mimeType.substring(0, mimeType.indexOf("/"));
    return mimeType;
  }

  Future loadMessageChunk(int offset) async {
    debugPrint("loading older messages");
    Completer completer = new Completer();
    if (_currentChat != null) {
      List<Message> messages =
          await Chat.getMessages(_currentChat, offset: offset);
      if (messages.length == 0) {
        debugPrint("messages length is 0, fetching from server");
        Map<String, dynamic> params = Map();
        params["identifier"] = _currentChat.guid;
        params["limit"] = 50;
        params["offset"] = offset;
        params["withBlurhash"] = true;

        SocketManager()
            .socket
            .sendMessage("get-chat-messages", jsonEncode(params), (data) async {
          List messages = jsonDecode(data)["data"];
          if (messages.length == 0) {
            completer.complete();
            return;
          }
          debugPrint("got messages");
          List<Message> _messages =
              await MessageHelper.bulkAddMessages(_currentChat, messages);
          _allMessages.addAll(_messages);
          _allMessages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
          _messageController.sink.add(_allMessages);
          for (int i = 0; i < messages.length; i++) {
            List<Widget> attachmentsForMessage =
                await getAttachments(messages[i]);
            if (attachmentsForMessage.length > 0) {
              _attachments[messages[i].guid] = attachmentsForMessage;
            }
            if (i == messages.length - 1) {
              _messageController.sink.add(_allMessages);
            }
          }
          completer.complete();
          await getReactions(offset);
        });
      } else {
        // debugPrint("loading more messages from sql " +);
        _allMessages.addAll(messages);
        _allMessages.sort((a, b) => -a.dateCreated.compareTo(b.dateCreated));
        _messageController.sink.add(_allMessages);
        for (int i = 0; i < messages.length; i++) {
          List<Widget> attachmentsForMessage =
              await getAttachments(messages[i]);
          if (attachmentsForMessage.length > 0) {
            _attachments[messages[i].guid] = attachmentsForMessage;
          }
          if (i == messages.length - 1) {
            _messageController.sink.add(_allMessages);
          }
        }
        completer.complete();
        await getReactions(offset);
      }
    } else {
      completer.completeError("chat not found");
    }
    return completer.future;
  }

  Future<void> getReactions(int offset) async {
    List<Message> reactionsResult = await Chat.getMessages(_currentChat,
        reactionsOnly: true, offset: offset);
    _reactions = new Map();
    reactionsResult.forEach((element) {
      if (element.associatedMessageGuid != null) {
        // debugPrint(element.handle.toString());
        String guid = element.associatedMessageGuid
            .substring(element.associatedMessageGuid.indexOf("/") + 1);

        if (!_reactions.containsKey(guid)) _reactions[guid] = <Message>[];
        _reactions[guid].add(element);
      }
    });
    _messageController.sink.add(_allMessages);
  }

  void dispose() {
    _allMessages = <Message>[];
  }
}
