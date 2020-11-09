import 'dart:async';

import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/material.dart';

class SetupBloc {
  final _stream = StreamController<double>.broadcast();

  bool _finishedSetup = false;
  double _progress = 0.0;
  int _currentIndex = 0;
  List chats = [];
  bool isSyncing = false;
  double numberOfMessagesPerPage = 25;
  bool downloadAttachments = false;
  bool skipEmptyChats = true;

  Stream<double> get stream => _stream.stream;
  double get progress => _progress;
  bool get finishedSetup => false;
  int processId;

  Function onConnectionError;

  SetupBloc();

  void handleError({String error = ""}) {
    closeSync();

    if (onConnectionError != null) onConnectionError(error);
  }

  void startSync(Settings settings, Function _onConnectionError) {
    // Make sure we aren't already syncing
    if (isSyncing) return;

    // Setup syncing process
    processId =
        SocketManager().addSocketProcess(([bool finishWithError = false]) {});
    onConnectionError = _onConnectionError;
    isSyncing = true;

    // Set the last sync date (for incremental, even though this isn't incremental)
    // We won't try an incremental sync until the last (full) sync date is set
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.lastIncrementalSync = DateTime.now().millisecondsSinceEpoch;

    SettingsManager().saveSettings(_settingsCopy);

    // Get the chats to sync
    SocketManager().sendMessage("get-chats", {}, (data) {
      if (data['status'] == 200) {
        receivedChats(data);
      } else {
        handleError();
      }
    });
  }

  void receivedChats(data) async {
    debugPrint("(Setup) -> Received initial chat list");
    chats = data["data"];
    if (chats.isEmpty) {
      finishSetup();
    } else {
      getChatMessagesRecursive(chats, 0);
      _stream.sink.add(_progress);
    }
  }

  void getChatMessagesRecursive(List chats, int index) async {
    Chat chat = Chat.fromMap(chats[index]);
    await chat.save();

    Map<String, dynamic> params = Map();
    params["identifier"] = chat.guid;
    params["withBlurhash"] = false;
    params["limit"] = numberOfMessagesPerPage.round();
    params["where"] = [
      {"statement": "message.service = 'iMessage'", "args": null}
    ];

    SocketManager().sendMessage("get-chat-messages", params, (data) async {
      if (data['status'] != 200) {
        handleError();
        return;
      }

      await receivedMessagesForChat(chat, data);

      if (index + 1 < chats.length) {
        _currentIndex = index + 1;
        getChatMessagesRecursive(chats, index + 1);
      } else {
        finishSetup();
      }
    });
  }

  Future<void> receivedMessagesForChat(
      Chat chat, Map<String, dynamic> data) async {
    List messages = data["data"];

    // Since we got the messages in desc order, we want to reverse it.
    // Reversing it will add older messages before newer one. This should help fix
    // issues with associated message GUIDs
    if (!skipEmptyChats || (skipEmptyChats && messages.length > 0)) {
      MessageHelper.bulkAddMessages(chat, messages.reversed.toList(),
          notifyForNewMessage: false);

      // If we want to download the attachments, do it, and wait for them to finish before continuing
      if (downloadAttachments) {
        await MessageHelper.bulkDownloadAttachments(
            chat, messages.reversed.toList());
      }
    }

    _progress = (_currentIndex + 1) / chats.length;
    _stream.sink.add(_progress);
  }

  void finishSetup() async {
    isSyncing = false;
    if (processId != null) SocketManager().finishSocketProcess(processId);

    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.finishedSetup = true;
    _finishedSetup = true;
    ContactManager().contacts = [];
    await ContactManager().getContacts();
    SettingsManager().saveSettings(_settingsCopy);
    SocketManager().finishSetup();
  }

  void startIncrementalSync(Settings settings,
      {String chatGuid,
      bool saveDate = true,
      Function onConnectionError,
      Function onComplete}) {
    // If we are already syncing, don't sync again
    // If the last sync date is empty, then we've never synced, so don't.
    if (isSyncing ||
        settings.lastIncrementalSync == 0 ||
        SocketManager().state != SocketState.CONNECTED) return;

    // Setup the socket process and error handler
    processId =
        SocketManager().addSocketProcess(([bool finishWithError = false]) {});

    if (onConnectionError != null) this.onConnectionError = onConnectionError;
    isSyncing = true;

    // Store the time we started syncing
    debugPrint(
        "(SYNC) Starting incremental sync for messages since: ${settings.lastIncrementalSync}");
    int syncStart = DateTime.now().millisecondsSinceEpoch;

    // Build request params. We want all details on the messages
    Map<String, dynamic> params = Map();
    if (chatGuid != null) {
      params["chatGuid"] = chatGuid;
    }

    params["withBlurhash"] = false; // Maybe we want it?
    params["limit"] =
        1000; // This is arbitrary, hopefully there aren't more messages
    params["after"] =
        settings.lastIncrementalSync; // Get everything since the last sync
    params["withChats"] =
        true; // We want the chats too so we can save them correctly
    params["withAttachments"] = true; // We want the attachment data
    params["withHandle"] = true; // We want to know who sent it
    params["sort"] =
        "ASC"; // Sort my ASC so we receive the earliest messages first
    params["where"] = [
      {"statement": "message.service = 'iMessage'", "args": null}
    ];

    SocketManager().sendMessage("get-messages", params, (data) async {
      if (data['status'] != 200) {
        handleError(error: data['error']['message']);
        return;
      }

      // Get the messages and add them to the DB
      List messages = data["data"];
      if (messages.isEmpty) {
        debugPrint("(SYNC) No new messages found during incremental sync");
      } else {
        debugPrint(
            "(SYNC) Incremental sync found ${messages.length} messages. Syncing...");
      }

      if (messages.length > 0) {
        await MessageHelper.bulkAddMessages(null, messages,
            notifyForNewMessage: true);
      }

      // Once we have added everything, save the last sync date
      if (saveDate) {
        debugPrint(
            "(SYNC) Finished incremental sync. Saving last sync date: $syncStart");

        Settings _settingsCopy = SettingsManager().settings;
        _settingsCopy.lastIncrementalSync = syncStart;
        SettingsManager().saveSettings(_settingsCopy);
      }

      if (SettingsManager().settings.showIncrementalSync)
        // Show a nice lil toast/snackbar
        EventDispatcher()
            .emit("show-snackbar", {"text": "🔄 Incremental sync complete 🔄"});

      if (onComplete != null) {
        onComplete();
      }

      // End the sync
      closeSync();
    });
  }

  void closeSync() {
    isSyncing = false;
    if (processId != null) SocketManager().finishSocketProcess(processId);
  }

  void dispose() {
    _stream.close();
  }
}
