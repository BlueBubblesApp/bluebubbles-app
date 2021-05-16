import 'dart:async';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

enum SetupOutputType { ERROR, LOG }

class SetupData {
  double progress;
  List<SetupOutputData> output = [];

  SetupData(this.progress, this.output);
}

class SetupOutputData {
  String text;
  SetupOutputType type;

  SetupOutputData(this.text, this.type);
}

class SetupBloc {
  StreamController<SetupData> _stream = StreamController<SetupData>.broadcast();
  StreamController<SocketState> _connectionStatusStream = StreamController<SocketState>.broadcast();
  StreamSubscription connectionSubscription;

  Stream<SocketState> get conenctionStatus => _connectionStatusStream.stream;

  double _progress = 0.0;
  int _currentIndex = 0;
  List chats = [];
  bool isSyncing = false;
  double numberOfMessagesPerPage = 25;
  bool downloadAttachments = false;
  bool skipEmptyChats = true;

  Stream<SetupData> get stream => _stream.stream;

  double get progress => _progress;
  int processId;

  List<SetupOutputData> output = [];

  SetupBloc();

  Future<void> connectToServer(FCMData data, String serverURL, String password) async {
    Settings settingsCopy = SettingsManager().settings;
    settingsCopy.serverAddress = getServerAddress(address: serverURL);
    settingsCopy.guidAuthKey = password;

    await SettingsManager().saveSettings(settingsCopy);
    await SettingsManager().saveFCMData(data);
    await SocketManager().authFCM(catchException: false, force: true);
    await SocketManager().startSocketIO(forceNewConnection: true, catchException: false);
    connectionSubscription = SocketManager().connectionStateStream.listen((event) {
      if (_connectionStatusStream.isClosed) return;
      _connectionStatusStream.sink.add(event);
      if (isSyncing) {
        switch (event) {
          case SocketState.DISCONNECTED:
            addOutput("Disconnected from socket!", SetupOutputType.ERROR);
            break;
          case SocketState.ERROR:
            addOutput("Socket connection error!", SetupOutputType.ERROR);
            break;
          case SocketState.CONNECTING:
            addOutput("Reconnecting to socket...", SetupOutputType.LOG);
            break;
          case SocketState.FAILED:
            addOutput("Connection failed, cancelling download.", SetupOutputType.ERROR);
            closeSync();
            break;
          default:
            break;
        }
      }
    });
  }

  void handleError(String error) {
    if (!_stream.isClosed) {
      addOutput(error, SetupOutputType.ERROR);
      _stream.sink.add(SetupData(-1, output));
    }
    closeSync();
  }

  Future<void> startFullSync(Settings settings) async {
    // Make sure we aren't already syncing
    if (isSyncing) return;

    // Setup syncing process
    processId = SocketManager().addSocketProcess(([bool finishWithError = false]) {});
    isSyncing = true;

    // Set the last sync date (for incremental, even though this isn't incremental)
    // We won't try an incremental sync until the last (full) sync date is set
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.lastIncrementalSync = DateTime.now().millisecondsSinceEpoch;

    SettingsManager().saveSettings(_settingsCopy);

    // Some safetly logging
    Timer timer = Timer(Duration(seconds: 15), () {
      if (_progress == 0) {
        addOutput("This is taking a while! Please Ensure that System Disk Access is granted on the mac!",
            SetupOutputType.ERROR);
      }
    });

    try {
      addOutput("Getting Chats...", SetupOutputType.LOG);
      List<dynamic> chats = await SocketManager().getChats({});

      // If we got chats, cancel the timer
      timer.cancel();

      if (chats.isEmpty) {
        addOutput("Received no chats, finishing up...", SetupOutputType.LOG);
        finishSetup();
        return;
      }

      addOutput("Received initial chat list. Size: ${chats.length}", SetupOutputType.LOG);
      for (dynamic item in chats) {
        Chat chat = Chat.fromMap(item);
        await chat.save();

        try {
          await syncChat(chat);
          addOutput("Finished syncing chat, '${chat.chatIdentifier}'", SetupOutputType.LOG);
        } catch (ex) {
          addOutput("Failed to sync chat, '${chat.chatIdentifier}'", SetupOutputType.ERROR);
        }

        // Set the new progress
        _currentIndex += 1;
        _progress = (_currentIndex / chats.length) * 100;
      }

      // If everything passes, finish the setup
      _progress = 100;
    } catch (ex) {
      addOutput("Failed to sync chats!", SetupOutputType.ERROR);
      addOutput("Error: ${ex.toString()}", SetupOutputType.ERROR);
    } finally {
      finishSetup();
    }
  }

  Future<void> syncChat(Chat chat) async {
    Map<String, dynamic> params = Map();
    params["identifier"] = chat.guid;
    params["withBlurhash"] = false;
    params["limit"] = numberOfMessagesPerPage.round();
    params["where"] = [
      {"statement": "message.service = 'iMessage'", "args": null}
    ];

    List<dynamic> messages = await SocketManager().getChatMessages(params);
    addOutput("Received ${messages?.length} messages for chat, '${chat.chatIdentifier}'!", SetupOutputType.LOG);

    // Since we got the messages in desc order, we want to reverse it.
    // Reversing it will add older messages before newer one. This should help fix
    // issues with associated message GUIDs
    if (!skipEmptyChats || (skipEmptyChats && messages.length > 0)) {
      await MessageHelper.bulkAddMessages(chat, messages.reversed.toList(),
          notifyForNewMessage: false, checkForLatestMessageText: false);

      // If we want to download the attachments, do it, and wait for them to finish before continuing
      if (downloadAttachments) {
        await MessageHelper.bulkDownloadAttachments(chat, messages.reversed.toList());
      }
    }
  }

  void finishSetup() async {
    addOutput("Finished Setup! Cleaning up...", SetupOutputType.LOG);
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.finishedSetup = true;
    SettingsManager().saveSettings(_settingsCopy);

    isSyncing = false;
    if (processId != null) SocketManager().finishSocketProcess(processId);

    ContactManager().contacts = [];
    await ContactManager().getContacts(force: true);
    await ChatBloc().refreshChats(force: true);

    SocketManager().finishSetup();
    closeSync();
  }

  void addOutput(String _output, SetupOutputType type) {
    debugPrint('[Setup] -> $_output');
    output.add(SetupOutputData(_output, type));
    _stream.sink.add(SetupData(_progress, output));
  }

  Future<void> startIncrementalSync(Settings settings,
      {String chatGuid,
      bool saveDate = true,
      bool isIncremental = false,
      Function onConnectionError,
      Function onComplete}) async {
    // If we are already syncing, don't sync again
    // If the last sync date is empty, then we've never synced, so don't.
    if (isSyncing || settings.lastIncrementalSync == 0 || SocketManager().state != SocketState.CONNECTED) return;

    // Reset the progress
    _progress = 0;

    // Setup the socket process and error handler
    processId = SocketManager().addSocketProcess(([bool finishWithError = false]) {});

    // if (onConnectionError != null) this.onConnectionError = onConnectionError;
    isSyncing = true;
    _progress = 1;

    // Store the time we started syncing
    addOutput("Starting incremental sync for messages since: ${settings.lastIncrementalSync}", SetupOutputType.LOG);
    int syncStart = DateTime.now().millisecondsSinceEpoch;

    // Build request params. We want all details on the messages
    Map<String, dynamic> params = Map();
    if (chatGuid != null) {
      params["chatGuid"] = chatGuid;
    }

    params["withBlurhash"] = false; // Maybe we want it?
    params["limit"] = 1000; // This is arbitrary, hopefully there aren't more messages
    params["after"] = settings.lastIncrementalSync; // Get everything since the last sync
    params["withChats"] = true; // We want the chats too so we can save them correctly
    params["withAttachments"] = true; // We want the attachment data
    params["withHandle"] = true; // We want to know who sent it
    params["sort"] = "DESC"; // Sort my DESC so we receive the newest messages first
    params["where"] = [
      {"statement": "message.service = 'iMessage'", "args": null}
    ];

    List<dynamic> messages = await SocketManager().getMessages(params);
    if (messages.isEmpty) {
      addOutput("No new messages found during incremental sync", SetupOutputType.LOG);
    } else {
      addOutput("Incremental sync found ${messages.length} messages. Syncing...", SetupOutputType.LOG);
    }

    if (messages.length > 0) {
      await MessageHelper.bulkAddMessages(null, messages, notifyForNewMessage: !isIncremental,
          onProgress: (progress, total) {
        _progress = (progress / total) * 100;
        _stream.sink.add(SetupData(_progress, output));
      });

      // If we want to download the attachments, do it, and wait for them to finish before continuing
      if (downloadAttachments) {
        await MessageHelper.bulkDownloadAttachments(null, messages.reversed.toList());
      }
    }

    _progress = 100;
    addOutput("Finished incremental sync", SetupOutputType.LOG);

    // Once we have added everything, save the last sync date
    if (saveDate) {
      addOutput("Saving last sync date: $syncStart", SetupOutputType.LOG);

      Settings _settingsCopy = SettingsManager().settings;
      _settingsCopy.lastIncrementalSync = syncStart;
      SettingsManager().saveSettings(_settingsCopy);
    }

    if (SettingsManager().settings.showIncrementalSync)
      // Show a nice lil toast/snackbar
      EventDispatcher().emit("show-snackbar", {"text": "🔄 Incremental sync complete 🔄"});

    if (onComplete != null) {
      onComplete();
    }

    // End the sync
    closeSync();
  }

  void closeSync() {
    isSyncing = false;
    if (processId != null) SocketManager().finishSocketProcess(processId);
    _stream.close();
    _connectionStatusStream.close();
    _stream = StreamController<SetupData>.broadcast();
    _connectionStatusStream = StreamController<SocketState>.broadcast();

    _progress = 0.0;
    _currentIndex = 0;
    chats = [];
    isSyncing = false;
    numberOfMessagesPerPage = 25;
    downloadAttachments = false;
    skipEmptyChats = true;
    processId = null;

    output = [];
    connectionSubscription?.cancel();
  }

  void dispose() {
    _stream.close();
  }
}
