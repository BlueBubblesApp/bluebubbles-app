import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bluebubble_messages/helpers/attachment_downloader.dart';
import 'package:bluebubble_messages/repository/database.dart';
import 'package:flutter_socket_io/socket_io_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_socket_io/flutter_socket_io.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'repository/models/attachment.dart';
import 'repository/models/message.dart';
import 'settings.dart';
import './repository/blocs/chat_bloc.dart';
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

  List<Chat> chatsWithNotifications = <Chat>[];

  void removeChatNotification(Chat chat) {
    for (int i = 0; i < chatsWithNotifications.length; i++) {
      debugPrint(i.toString());
      if (chatsWithNotifications[i].guid == chat.guid) {
        chatsWithNotifications.removeAt(i);
        break;
      }
    }
    notify();
  }

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

  bool alreadyStartedSetup = false;

  //setstate for these widgets
  Map<String, Function> subscribers = new Map();

  Map<String, AttachmentDownloader> attachmentDownloaders = Map();
  void addAttachmentDownloader(String guid, AttachmentDownloader downloader) {
    attachmentDownloaders[guid] = downloader;
  }

  void finishDownloader(String guid) {
    attachmentDownloaders.remove(guid);
  }

  Map<String, Function> disconnectSubscribers = new Map();

  String token;

  Future setup() {
    return setupProgress.future;
  }

  void subscribe(String guid, Function cb) {
    _singleton.subscribers[guid] = cb;
  }

  void unsubscribe(String guid) {
    _singleton.subscribers.remove(guid);
  }

  void disconnectCallback(Function cb, String guid) {
    _singleton.disconnectSubscribers[guid] = cb;
  }

  void unSubscribeDisconnectCallback(String guid) {
    _singleton.disconnectSubscribers.remove(guid);
  }

  void notify() {
    for (Function cb in _singleton.subscribers.values) {
      cb();
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
        debugPrint("CONNECTED");
        authFCM();
        syncChats();
        alreadyStartedSetup = true;
        _singleton.disconnectSubscribers.values.forEach((f) {
          f();
        });
        return;
      case "disconnect":
        _singleton.disconnectSubscribers.values.forEach((f) {
          f();
        });
        debugPrint("disconnected");
        return;
      default:
        return;
    }
    // debugPrint("update status: ${data.toString()}");
  }

  void deleteDB() async {
    Database db = await DBProvider.db.database;
    await db.execute("DELETE FROM handle");
    await db.execute("DELETE FROM chat");
    await db.execute("DELETE FROM message");
    await db.execute("DELETE FROM attachment");
    await db.execute("DELETE FROM chat_handle_join");
    await db.execute("DELETE FROM chat_message_join");
    await db.execute("DELETE FROM attachment_message_join");

    await DBProvider.db.createHandleTable(db);
    await DBProvider.db.createChatTable(db);
    await DBProvider.db.createMessageTable(db);
    await DBProvider.db.createAttachmentTable(db);
    await DBProvider.db.createAttachmentMessageJoinTable(db);
    await DBProvider.db.createChatHandleJoinTable(db);
    await DBProvider.db.createChatMessageJoinTable(db);
  }

  startSocketIO() async {
    // If we have no chats, loads chats from database
    if (_singleton.settings.finishedSetup) {
      if (!setupProgress.isCompleted) setupProgress.complete();
    } else {
      if (alreadyStartedSetup && !_singleton.settings.finishedSetup) {
        deleteDB();
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
      _singleton.socket.unSubscribesAll();

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
        debugPrint("new-message");
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
        Singleton().handleNewMessage(data, chat);
        if (data["isFromMe"]) {
          return new Future.value("");
        }

        // String message = data["text"].toString();

        // await _showNotificationWithDefaultSound(0, title, message);

        return new Future.value("");
      });

      _singleton.socket.subscribe("updated-message", (_data) async {
        debugPrint("updated-message");
        // Map<String, dynamic> data = jsonDecode(_data);
        // debugPrint("updated message: " + data.toString());
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
        if (value == null) {
          return;
        }

        debugPrint("new message");
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
        if (value == null) return;
        // Create the attachments
        debugPrint("new message");
        List<dynamic> attachments = data['attachments'];

        attachments.forEach((attachmentItem) {
          Attachment file = Attachment.fromMap(attachmentItem);
          file.save(message);
        });
        chatsWithNotifications.add(chat);
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

  void deleteDupMessages() {
    Message.cleanMessages();
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

}
