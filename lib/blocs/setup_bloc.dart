import 'dart:async';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

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
  // Setup as a Singleton
  static final SetupBloc _setupBloc = SetupBloc._internal();
  SetupBloc._internal();
  factory SetupBloc() {
    return _setupBloc;
  }

  final Rxn<SetupData> data = Rxn<SetupData>();
  final Rxn<SocketState> connectionStatus = Rxn<SocketState>();
  final RxBool isSyncing = false.obs;
  final RxBool isIncrementalSyncing = false.obs;
  Worker? connectionSubscription;

  double _progress = 0.0;
  int _currentIndex = 0;
  List chats = [];
  double numberOfMessagesPerPage = 25;
  bool downloadAttachments = false;
  bool skipEmptyChats = true;

  double get progress => _progress;
  int? processId;

  List<SetupOutputData> output = [];

  Future<void> connectToServer(FCMData data, String serverURL, String password) async {
    Settings settingsCopy = SettingsManager().settings;
    if (SocketManager().state.value == SocketState.CONNECTED && settingsCopy.serverAddress.value == serverURL) {
      Logger.warn("Not reconnecting to server we are already connected to!");
      return;
    }

    settingsCopy.serverAddress.value = getServerAddress(address: serverURL) ?? settingsCopy.serverAddress.value;
    settingsCopy.guidAuthKey.value = password;

    await SettingsManager().saveSettings(settingsCopy);
    SettingsManager().saveFCMData(data);
    await SocketManager().registerFcmDevice(catchException: false, force: true);
    SocketManager().startSocketIO(forceNewConnection: true, catchException: false);
    connectionSubscription = ever<SocketState>(SocketManager().state, (event) {
      connectionStatus.value = event;

      if (isSyncing.value) {
        switch (event) {
          case SocketState.DISCONNECTED:
            addOutput("Disconnected from socket!", SetupOutputType.ERROR);
            break;
          case SocketState.CONNECTED:
            addOutput("Connected to socket!", SetupOutputType.LOG);
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
    addOutput(error, SetupOutputType.ERROR);
    data.value = SetupData(-1, output);
    closeSync();
  }

  Future<void> startFullSync(Settings settings) async {
    // Make sure we aren't already syncing
    if (isSyncing.value) return;

    // Setup syncing process
    processId = SocketManager().addSocketProcess(([bool finishWithError = false]) {});
    isSyncing.value = true;

    // Set the last sync date (for incremental, even though this isn't incremental)
    // We won't try an incremental sync until the last (full) sync date is set
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.lastIncrementalSync.value = DateTime.now().millisecondsSinceEpoch;
    await SettingsManager().saveSettings(_settingsCopy);

    // Some safetly logging
    Timer timer = Timer(Duration(seconds: 15), () {
      if (_progress == 0) {
        addOutput("This is taking a while! Please Ensure that System Disk Access is granted on the mac!",
            SetupOutputType.ERROR);
      }
    });

    try {
      addOutput("Getting contacts...", SetupOutputType.LOG);
      Stopwatch s = Stopwatch();
      s.start();
      await ContactManager().loadContacts(force: true);
      s.stop();
      addOutput("Received contacts list. Size: ${ContactManager().contacts.length}, speed: ${s.elapsedMilliseconds} ms", SetupOutputType.LOG);
      addOutput("Getting Chats...", SetupOutputType.LOG);
      List<Chat> chats = await SocketManager().getChats({"withLastMessage": kIsWeb});

      // If we got chats, cancel the timerCo
      timer.cancel();

      if (chats.isEmpty) {
        addOutput("Received no chats, finishing up...", SetupOutputType.LOG);
        finishSetup();
        return;
      }

      addOutput("Received initial chat list. Size: ${chats.length}", SetupOutputType.LOG);
      if (kIsWeb) {
        ChatBloc().chats.clear();
        ChatBloc().chats.addAll(chats);
        ChatBloc().hasChats.value = true;
        ChatBloc().loadedChatBatch.value = true;
        for (Chat chat in chats) {
          for (Handle element in chat.participants) {
            if (ChatBloc().cachedHandles.firstWhereOrNull((e) => e.address == element.address) == null) {
              ChatBloc().cachedHandles.add(element);
            }
            addOutput("Finished syncing chat, '${chat.chatIdentifier}'", SetupOutputType.LOG);
          }
          _currentIndex += 1;
          _progress = (_currentIndex / chats.length) * 100;
        }
        addOutput("Fetching contacts from server...", SetupOutputType.LOG);
        await ContactManager().loadContacts(force: true);
        addOutput("Received contacts list. Size: ${ContactManager().contacts.length}", SetupOutputType.LOG);
        addOutput("Matching contacts to chats...", SetupOutputType.LOG);
        _progress = 100;
        finishSetup();
        startIncrementalSync(settings);
        return;
      }

      for (Chat chat in chats) {
        if (chat.guid == "ERROR") {
          addOutput("Failed to save chat data, '${chat.displayName}'", SetupOutputType.ERROR);
        } else {
          try {
            if (!(chat.chatIdentifier ?? "").startsWith("urn:biz")) {
              Map<String, dynamic> params = {};
              params["identifier"] = chat.guid;
              params["withBlurhash"] = false;
              params["limit"] = numberOfMessagesPerPage.round();
              List<dynamic> messages = await SocketManager().getChatMessages(params)!;
              addOutput("Received ${messages.length} messages for chat, '${chat.chatIdentifier}'!", SetupOutputType.LOG);
              if (!skipEmptyChats || (skipEmptyChats && messages.isNotEmpty)) {
                chat.save();
                await syncChat(chat, messages);
                addOutput("Finished syncing chat, '${chat.chatIdentifier}'", SetupOutputType.LOG);
              } else {
                addOutput("Skipping syncing chat (empty chat), '${chat.chatIdentifier}'", SetupOutputType.LOG);
              }
            } else {
              addOutput("Skipping syncing chat, '${chat.chatIdentifier}'", SetupOutputType.LOG);
            }
          } catch (ex, stacktrace) {
            addOutput("Failed to sync chat, '${chat.chatIdentifier}'", SetupOutputType.ERROR);
            addOutput(stacktrace.toString(), SetupOutputType.ERROR);
          } finally {
            // This artificial wait is here so that syncing doesn't completely freeze the sync screen.
            // Eventually, we just need to move syncing to the isolate so it gets handled asyncronously
            await Future.delayed(Duration(milliseconds: 250));
          }
        }

        // If we have no chats, we can't divide by 0
        // Also means there are not chats to sync
        // It should never be 0... but still want to check to be safe.
        if (chats.isEmpty) {
          break;
        } else {
          // Set the new progress
          _currentIndex += 1;
          _progress = (_currentIndex / chats.length) * 100;
        }
      }

      // If everything passes, finish the setup
      _progress = 100;
    } catch (ex) {
      addOutput("Failed to sync chats!", SetupOutputType.ERROR);
      addOutput("Error: ${ex.toString()}", SetupOutputType.ERROR);
    } finally {
      finishSetup();
    }

    // Start an incremental sync to catch any messages we missed during setup
    startIncrementalSync(settings);
  }

  Future<void> syncChat(Chat chat, List<dynamic> messages) async {
    // Since we got the messages in desc order, we want to reverse it.
    // Reversing it will add older messages before newer one. This should help fix
    // issues with associated message GUIDs
    if (!skipEmptyChats || (skipEmptyChats && messages.isNotEmpty)) {
      await MessageHelper.bulkAddMessages(chat, messages.reversed.toList(),
          notifyForNewMessage: false, checkForLatestMessageText: true);

      // If we want to download the attachments, do it, and wait for them to finish before continuing
      // Commented out because I think this negatively effects sync performance and causes disconnects
      // todo
      // if (downloadAttachments) {
      //   await MessageHelper.bulkDownloadAttachments(chat, messages.reversed.toList());
      // }
    }
  }

  void finishSetup() async {
    addOutput("Finished Setup! Cleaning up...", SetupOutputType.LOG);
    Settings _settingsCopy = SettingsManager().settings;
    _settingsCopy.finishedSetup.value = true;
    await SettingsManager().saveSettings(_settingsCopy);
    if (!kIsWeb) await ChatBloc().refreshChats(force: true);
    await SocketManager().registerFcmDevice(force: true);
    closeSync();
  }

  void addOutput(String _output, SetupOutputType type) {
    Logger.info(_output, tag: "Setup");
    output.add(SetupOutputData(_output, type));
    data.value = SetupData(_progress, output);
  }

  Future<void> startIncrementalSync(Settings settings,
      {String? chatGuid, bool saveDate = true, Function? onConnectionError, Function? onComplete}) async {
    // If we are already syncing, don't sync again
    // Or, if we haven't finished setup, or we aren't connected, don't sync
    if (isIncrementalSyncing.value || !settings.finishedSetup.value || SocketManager().state.value != SocketState.CONNECTED) {
      return;
    }

    // Reset the progress
    _progress = 0;

    // Setup the socket process and error handler
    processId = SocketManager().addSocketProcess(([bool finishWithError = false]) {});

    // if (onConnectionError != null) this.onConnectionError = onConnectionError;
    isIncrementalSyncing.value = true;
    _progress = 1;

    // Store the time we started syncing
    addOutput("Starting incremental sync for messages since: ${settings.lastIncrementalSync}", SetupOutputType.LOG);
    int syncStart = DateTime.now().millisecondsSinceEpoch;

    // only get up to 1000 messages (arbitrary limit)
    int batches = 10;
    for (int i = 0; i < batches; i++) {
      // Build request params. We want all details on the messages
      Map<String, dynamic> params = {};
      if (chatGuid != null) {
        params["chatGuid"] = chatGuid;
      }

      params["withBlurhash"] = false; // Maybe we want it?
      params["limit"] = 100;
      params["offset"] = i * batches;
      params["after"] = settings.lastIncrementalSync.value; // Get everything since the last sync
      params["withChats"] = true; // We want the chats too so we can save them correctly
      params["withChatParticipants"] = true; // We want participants on web only
      params["withAttachments"] = true; // We want the attachment data
      params["withHandle"] = true; // We want to know who sent it
      params["sort"] = "DESC"; // Sort my DESC so we receive the newest messages first

      List<dynamic> messages = await SocketManager().getMessages(params)!;
      if (messages.isEmpty) {
        addOutput("No more new messages found during incremental sync", SetupOutputType.LOG);
        break;
      } else {
        addOutput("Incremental sync found ${messages.length} messages. Syncing...", SetupOutputType.LOG);
      }

      if (messages.isNotEmpty) {
        await MessageHelper.bulkAddMessages(null, messages, onProgress: (progress, total) {
          _progress = (progress / total) * 100;
          data.value = SetupData(_progress, output);
        }, notifyForNewMessage: !kIsWeb);

        // If we want to download the attachments, do it, and wait for them to finish before continuing
        if (downloadAttachments) {
          await MessageHelper.bulkDownloadAttachments(null, messages.reversed.toList());
        }
      }
    }

    _progress = 100;
    addOutput("Finished incremental sync", SetupOutputType.LOG);

    // Once we have added everything, save the last sync date
    if (saveDate) {
      addOutput("Saving last sync date: $syncStart", SetupOutputType.LOG);

      Settings _settingsCopy = SettingsManager().settings;
      _settingsCopy.lastIncrementalSync.value = syncStart;
      SettingsManager().saveSettings(_settingsCopy);
    }

    if (SettingsManager().settings.showIncrementalSync.value) {
      showSnackbar('Success', '🔄 Incremental sync complete 🔄');
    }

    if (onComplete != null) {
      onComplete();
    }

    // End the sync
    closeSync();
  }

  void closeSync() {
    if (isSyncing.value) isSyncing.value = false;
    if (isIncrementalSyncing.value) isIncrementalSyncing.value = false;
    if (processId != null) SocketManager().finishSocketProcess(processId);
    data.value = null;
    connectionStatus.value = null;

    _progress = 0.0;
    _currentIndex = 0;
    chats = [];
    numberOfMessagesPerPage = 25;
    downloadAttachments = false;
    skipEmptyChats = true;
    processId = null;

    output = [];
    connectionSubscription?.dispose();
  }
}
