import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_socket_io/socket_io_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_socket_io/flutter_socket_io.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'repository/models/attachment.dart';
import 'repository/models/message.dart';
import 'settings.dart';
import './repository/blocs/chat.dart';
import './repository/models/chat.dart';

class Singleton {
  factory Singleton() {
    return _singleton;
  }

  static final Singleton _singleton = Singleton._internal();

  Singleton._internal();

  Directory appDocDir;

  // Chat repo
  ChatBloc chatContext = new ChatBloc();
  List<Chat> chats = [];

  List<Contact> contacts = <Contact>[];
  //interface with native code
  final platform = const MethodChannel('samples.flutter.dev/fcm');

  List<String> processedGUIDS = [];
  //settings
  Settings settings;

  //for setup, when the user has no saved db
  Completer setupProgress = new Completer();

  SharedPreferences sharedPreferences;
  //Socket io
  // SocketIOManager manager;
  SocketIO socket;

  //setstate for these widgets
  List<Function> subscribers = <Function>[];

  String token;

  Future setup() {
    return setupProgress.future;
  }

  void subscribe(Function cb) {
    _singleton.subscribers.add(cb);
  }

  void notify() {
    for (int i = 0; i < _singleton.subscribers.length; i++) {
      _singleton.subscribers[i]();
    }
  }

  void getSavedSettings() async {
    appDocDir = await getApplicationDocumentsDirectory();
    _singleton.sharedPreferences = await SharedPreferences.getInstance();
    var result = _singleton.sharedPreferences.getString('Settings');
    if (result != null) {
      Map resultMap = jsonDecode(result);
      _singleton.settings = Settings.fromJson(resultMap);
    }
    _singleton.startSocketIO();
    _singleton.authFCM();
  }

  void saveSettings(Settings settings) async {
    if (_singleton.sharedPreferences == null) {
      _singleton.sharedPreferences = await SharedPreferences.getInstance();
    }
    _singleton.sharedPreferences.setString('Settings', jsonEncode(settings));
    await _singleton.authFCM();
    _singleton.startSocketIO();
  }

  void socketStatusUpdate(data) {
    switch (data) {
      case "connect":
        debugPrint("connected");
        authFCM();
        syncChats();
        return;
      case "disconnect":
        debugPrint("disconnected");
        return;
      default:
        return;
    }
    // debugPrint("update status: ${data.toString()}");
  }

  startSocketIO() async {
    // If we have no chats, loads chats from database
    if (_singleton.chats.length == 0) {
      List<Chat> _chats = await Chat.find();
      if (_chats.length != 0) {
        _singleton.chats = _chats;
        setupProgress.complete();
      }
    }

    // If we already have a socket connection, kill it
    if (_singleton.socket != null) {
      _singleton.socket.destroy();
    }

    debugPrint(
        "Starting socket io with the server: ${_singleton.settings.serverAddress}");

    try {
      // Create a new socket connection
      _singleton.socket = SocketIOManager().createSocketIO(
          _singleton.settings.serverAddress, "/",
          query: "guid=${_singleton.settings.guidAuthKey}",
          socketStatusCallback: socketStatusUpdate);
      _singleton.socket.init();
      _singleton.socket.connect();

      // Let us know when our device was added
      _singleton.socket.subscribe("fcm-device-id-added", (data) {
        debugPrint("fcm device added: " + data.toString());
      });

      // Let us know when there is an error
      _singleton.socket.subscribe("error", (data) {
        debugPrint("An error occurred: " + data.toString());
      });

      _singleton.socket.subscribe("new-message", (_data) async {
        // debugPrint(data.toString());
        debugPrint("found new message");
        Map<String, dynamic> data = jsonDecode(_data);
        if (Singleton().processedGUIDS.contains(data["guid"])) {
          return new Future.value("");
        } else {
          Singleton().processedGUIDS.add(data["guid"]);
        }
        if (data["chats"].length == 0) return new Future.value("");
        Chat chat = await Chat.findOne({"guid": data["chats"][0]["guid"]});
        if (chat == null) return new Future.value("");
        String title = await chatTitle(chat);
        debugPrint("found chat: " + title);
        Singleton().handleNewMessage(data, chat);
        if (data["isFromMe"]) {
          return new Future.value("");
        }

        // String message = data["text"].toString();

        // await _showNotificationWithDefaultSound(0, title, message);

        return new Future.value("");
      });
    } catch (e) {
      debugPrint("FAILED TO CONNECT");
    }
  }

  void syncChats() async {
    if (!_singleton.settings.finishedSetup) {
      debugPrint("Syncing chats from the server");
      _singleton.socket.sendMessage("get-chats", '{}', (data) async {
        List chats = jsonDecode(data)["data"];

        for (int i = 0; i < chats.length; i++) {
          // Get the chat and add it to the DB
          debugPrint(chats[i].toString());
          Chat chat = Chat.fromMap(chats[i]);
          // This will check for an existing chat as well
          await chat.save();

          Map<String, dynamic> params = Map();
          params["identifier"] = chat.guid;
          params["limit"] = 100;
          _singleton.socket.sendMessage("get-chat-messages", jsonEncode(params),
              (data) async {
            List messages = jsonDecode(data)["data"];

            messages.forEach((item) {
              Message message = Message.fromMap(item);
              chat.addMessage(message).then((value) {
                // Create the attachments
                List<dynamic> attachments = item['attachments'];

                attachments.forEach((attachmentItem) {
                  Attachment file = Attachment.fromMap(attachmentItem);
                  file.save(message);
                });
              });
            });
            if (i == chats.length - 1) {
              Settings _settings = _singleton.settings;
              _settings.finishedSetup = true;
              _singleton.saveSettings(_singleton.settings);
              List<Chat> _chats = await Chat.find();
              _singleton.chats = _chats;
              notify();
            }
          });
        }
      });
    }
  }

  void closeSocket() {
    _singleton.socket.destroy();
    _singleton.socket = null;
  }

  Future<void> authFCM() async {
    try {
      final String result =
          await platform.invokeMethod('auth', _singleton.settings.fcmAuthData);
      token = result;
      if (_singleton.socket != null) {
        _singleton.socket.sendMessage(
            "add-fcm-device",
            jsonEncode({"deviceId": token, "deviceName": "android-client"}),
            () {});
        debugPrint(token);
      }
    } on PlatformException catch (e) {
      token = "Failed to get token: " + e.toString();
      debugPrint(token);
    }
  }

  void handleNewMessage(Map<String, dynamic> data, Chat chat) {
    Message message = new Message.fromMap(data);
    if (message.isFromMe) {
      chat.addMessage(message).then((value) {
        // Create the attachments
        List<dynamic> attachments = data['attachments'];

        attachments.forEach((attachmentItem) {
          Attachment file = Attachment.fromMap(attachmentItem);
          file.save(message);
        });
        notify();
      });
    } else {
      chat.addMessage(message).then((value) {
        // Create the attachments
        List<dynamic> attachments = data['attachments'];

        attachments.forEach((attachmentItem) {
          Attachment file = Attachment.fromMap(attachmentItem);
          file.save(message);
        });
        notify();
      });
    }
    // if (_singleton.socket != null) {
    //   syncMessages();
    // } else {
    //   debugPrint("not syncing, socket is null");
    // }
    // sortChats();
  }

  // void sortChats() async {
  //   Map<String, Message> guidToMessage = new Map<String, Message>();
  //   int counter = 0;
  //   for (int i = 0; i < _singleton.chats.length; i++) {
  //     RepositoryServiceMessage.getMessagesFromChat(_singleton.chats[i].guid)
  //         .then((List<Message> messages) {
  //       counter++;
  //       if (messages.length > 0) {
  //         RepositoryServiceChats.updateChatTime(
  //                 _singleton.chats[i].guid, messages.first.dateCreated)
  //             .then((int n) {
  //           if (counter == _singleton.chats.length - 1) {
  //             RepositoryServiceChats.getAllChats().then((List<Chat> chats) {
  //               _singleton.chats = chats;
  //               notify();
  //             });
  //           }
  //         });
  //       } else {
  //         if (counter == _singleton.chats.length - 1) {
  //           RepositoryServiceChats.getAllChats().then((List<Chat> chats) {
  //             _singleton.chats = chats;
  //             notify();
  //           });
  //         }
  //       }
  //     });
  //   }

  //   updatedChats.sort(
  //       (a, b) => a.lastMessageTimeStamp.compareTo(b.lastMessageTimeStamp));
  //   _singleton.chats = updatedChats;
  //   notify();
  // }

  // void sendMessage(String text) {
  //   Map params = Map();
  //   params["guid"] = message.chatGuid;
  //   params["message"] = message.text;
  //   _singleton.socket.sendMessage("send-message", jsonEncode(params));
  // }

  // void syncMessages() {
  //   debugPrint("sync messages");
  //   for (int i = 0; i < _singleton.chats.length; i++) {
  //     Map<String, dynamic> params = new Map();
  //     params["identifier"] = _singleton.chats[i].guid;
  //     params["limit"] = 100;
  //     _singleton.socket.sendMessage("get-chat-messages", jsonEncode(params),
  //         (_messages) {
  //       List dataMessages = _messages["data"];
  //       List<Message> messages = <Message>[];
  //       for (int i = 0; i < dataMessages.length; i++) {
  //         messages.add(new Message(dataMessages[i]));
  //       }
  //       RepositoryServiceMessage.addMessagesToChat(messages)
  //           .then((void newMessages) {
  //         notify();
  //       });
  //     });
  //   }
  // }

  getChunkRecursive(String guid, int index, int total, List<int> currentBytes,
      int chunkSize, Function cb) {
    if (index <= total) {
      Map<String, dynamic> params = new Map();
      params["identifier"] = guid;
      params["start"] = index * chunkSize;
      params["chunkSize"] = chunkSize;
      params["compress"] = false;
      _singleton.socket.sendMessage("get-attachment-chunk", jsonEncode(params),
          (chunk) async {
        Map<String, dynamic> attachmentResponse = jsonDecode(chunk);
        if (!attachmentResponse.containsKey("data") || attachmentResponse["data"] == null) {
          await cb(currentBytes);
        }

        Uint8List bytes = base64Decode(attachmentResponse["data"]);
        currentBytes.addAll(bytes.toList());
        if (index < total) {
          debugPrint("${index / total * 100}% of the image");
          debugPrint("next start is ${index + 1} out of $total");
          getChunkRecursive(
              guid, index + 1, total, currentBytes, chunkSize, cb);
        } else {
          debugPrint("finished getting image");
          await cb(currentBytes);
        }
      });
    }
  }

  Future getImage(Attachment attachment) {
    int chunkSize = 1024 * 1000;
    Completer completer = new Completer();
    debugPrint("getting attachment");
    int numOfChunks = (attachment.totalBytes / chunkSize).ceil();
    debugPrint("num Of Chunks is $numOfChunks");
    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();
    getChunkRecursive(attachment.guid, 0, numOfChunks, [], chunkSize,
        (List<int> data) async {
      stopwatch.stop();
      debugPrint("time elapsed is ${stopwatch.elapsedMilliseconds}");

      if (data.length == 0) {
        completer.completeError("Unable to fetch attachment from server");
        return;
      }

      String fileName = attachment.transferName;
      String appDocPath = _singleton.appDocDir.path;
      String pathName = "$appDocPath/${attachment.guid}/$fileName";
      debugPrint(
          "length of array is ${data.length} / ${attachment.totalBytes}");
      Uint8List bytes = Uint8List.fromList(data);

      File file = await writeToFile(bytes, pathName);
      completer.complete(file);
    });

    return completer.future;
  }

  Future<File> writeToFile(Uint8List data, String path) async {
    File file = await new File(path).create(recursive: true);
    return file.writeAsBytes(data);
  }
}
