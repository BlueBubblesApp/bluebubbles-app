import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/helpers/load_timer.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:bluebubbles/database/database.dart';

ChatsService chats = Get.isRegistered<ChatsService>() ? Get.find<ChatsService>() : Get.put(ChatsService());

class ChatsService extends GetxService {
  static const batchSize = 50;
  // Number of chat batches to fetch concurrently on web (network-bound)
  static const webFetchConcurrency = 6;
  int currentCount = 0;
  late final StreamSubscription countSub;

  final RxBool hasChats = false.obs;
  Completer<void> loadedAllChats = Completer();
  final RxBool loadedChatBatch = false.obs;
  final RxList<Chat> chats = <Chat>[].obs;

  final List<Handle> webCachedHandles = [];

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb) {
      // watch for new chats
      final countQuery = (Database.chats.query(Chat_.dateDeleted.isNull())..order(Chat_.id, flags: Order.descending))
          .watch();
      countSub = countQuery.listen((event) async {
        if (!ss.settings.finishedSetup.value) return;
        final newCount = event.count();
        if (newCount > currentCount && currentCount != 0) {
          final chat = event.findFirst()!;
          if (chat.latestMessage.dateCreated!.millisecondsSinceEpoch == 0) {
            // wait for the chat.addMessage to go through
            await Future.delayed(const Duration(milliseconds: 500));
            // refresh the latest message
            chat.dbLatestMessage;
          }
          await addChat(chat);
        }
        currentCount = newCount;
      });
    } else {
      countSub = WebListeners.newChat.listen((chat) async {
        if (!ss.settings.finishedSetup.value) return;
        await addChat(chat);
      });
    }
  }

  Future<void> init({bool force = false}) async {
    if (!force && !ss.settings.finishedSetup.value) return;
    LoadTimer.mark("Chats fetch started");
    Logger.info("Fetching chats...", tag: "ChatBloc");
    currentCount = Chat.count() ??
        (await http.chatCount().catchError((err) {
          Logger.info("Error when fetching chat count!", tag: "ChatBloc");
          return Response(requestOptions: RequestOptions(path: ''));
        }))
            .data['data']['total'] ??
        0;
    loadedAllChats = Completer();
    if (currentCount != 0) {
      hasChats.value = true;
    } else {
      loadedChatBatch.value = true;
      return;
    }

    // On web, start fetching contacts in parallel with chat loading so names
    // can be matched the instant chats finish loading (instead of waiting for
    // the contact fetch to start only after all chats are loaded).
    Future<List<Contact>>? contactsFuture;
    if (kIsWeb && cs.contacts.isEmpty) {
      contactsFuture = cs.fetchNetworkContacts();
    }

    // Track the background subsystems so we can log a single accurate
    // "Everything loaded" line once chats, contacts AND avatars are all ready.
    LoadTimer.expectSubsystems([
      'chats',
      if (contactsFuture != null) 'contacts',
      if (contactsFuture != null) 'avatars',
    ]);

    final newChats = <Chat>[];
    final batches = (currentCount / batchSize).ceil();

    // Optionally load only the most-recent N chats first (they are returned
    // sorted by last message), then load the rest in the background so the app
    // is usable immediately. 0 (or a value >= total) loads everything up front.
    final initialLoadCount = ss.settings.initialChatLoadCount.value;
    final stagedLoad = kIsWeb && initialLoadCount > 0 && initialLoadCount < currentCount;
    final initialBatches = stagedLoad ? (initialLoadCount / batchSize).ceil() : batches;

    if (kIsWeb) {
      await _fetchWebChatBatches(0, initialBatches, newChats);
    } else {
      for (int i = 0; i < batches; i++) {
        final temp = await Chat.getChats(limit: batchSize, offset: i * batchSize);
        for (Chat c in temp) {
          cm.createChatController(c, active: cm.activeChat?.chat.guid == c.guid);
        }
        newChats.addAll(temp);
        newChats.sort(Chat.sort);
        chats.value = newChats;
        loadedChatBatch.value = true;
      }
    }
    loadedAllChats.complete();
    sort();
    LoadTimer.mark("Chats loaded (${chats.length}${stagedLoad ? " of $currentCount, rest loading in background" : ""})");
    showSnackbar("Chats Loaded", "Finished loading ${chats.length} chats", durationMs: 2000);
    Logger.info("Finished fetching chats (${chats.length}).", tag: "ChatBloc");
    // If not staged, all chats are loaded now; otherwise the background task
    // marks 'chats' complete when it finishes.
    if (!stagedLoad) LoadTimer.completeSubsystem('chats');

    // On web, await the contacts fetched in parallel above and match to handles
    if (kIsWeb && contactsFuture != null) {
      try {
        final networkContacts = await contactsFuture;
        Logger.info("fetchNetworkContacts returned ${networkContacts.length} contacts, webCachedHandles: ${webCachedHandles.length}", tag: "ChatBloc");
        if (networkContacts.isNotEmpty) {
          cs.contacts = networkContacts;
          _matchWebContactsAndRefresh();
          LoadTimer.mark("Contact names matched & displayed (${cs.contacts.length} contacts)");
          Logger.info("Contacts loaded and matched: ${cs.contacts.length} contacts", tag: "ChatBloc");
        }
      } catch (e) {
        Logger.error("Failed to load contacts on web: $e", tag: "ChatBloc");
      } finally {
        LoadTimer.completeSubsystem('contacts');
      }
    }

    // Load any remaining chats in the background so the most-recent set is
    // usable immediately while the rest stream in.
    if (stagedLoad && initialBatches < batches) {
      _backgroundLoadRemainingChats(initialBatches, batches, newChats);
    }
    // update share targets
    if (Platform.isAndroid) {
      StartupTasks.waitForUI().then((_) async {
        for (Chat c in chats.where((e) => !isNullOrEmpty(e.title)).take(4)) {
          await mcs.invokeMethod("push-share-targets", {
            "title": c.title,
            "guid": c.guid,
            "icon": await avatarAsBytes(chat: c, quality: 256),
          });
        }
      });
    }

    if (kIsDesktop && Platform.isWindows) {
      /* ----- IMESSAGE:// HANDLER ----- */
      final _appLinks = AppLinks();
      _appLinks.stringLinkStream.listen((String string) async {
        if (!string.startsWith("imessage://")) return;
        final uri = Uri.tryParse(string
            .replaceFirst("imessage://", "imessage:")
            .replaceFirst("&body=", "?body=")
            .replaceFirst(RegExp(r'/$'), ''));
        if (uri == null) return;

        final address = uri.path;
        final handle = Handle.findOne(addressAndService: Tuple2(address, "iMessage"));
        ns.closeSettings(Get.context!);
        await ns.pushAndRemoveUntil(
          Get.context!,
          ChatCreator(
            initialSelected: [SelectedContact(displayName: handle?.displayName ?? address, address: address)],
            initialText: uri.queryParameters['body'],
          ),
          (route) => route.isFirst,
        );
      });
    }
  }

  /// Fetch chat batches in the range [startBatch, endBatch) on web, in
  /// concurrent waves of [webFetchConcurrency]. Appends results to
  /// [accumulator] and updates the visible list after each wave.
  Future<void> _fetchWebChatBatches(int startBatch, int endBatch, List<Chat> accumulator) async {
    for (int start = startBatch; start < endBatch; start += webFetchConcurrency) {
      final futures = <Future<List<Chat>>>[];
      for (int i = start; i < start + webFetchConcurrency && i < endBatch; i++) {
        futures.add(cm.getChats(withLastMessage: true, limit: batchSize, offset: i * batchSize));
      }
      final results = await Future.wait(futures);
      for (final temp in results) {
        webCachedHandles.addAll(temp.map((e) => e.participants).flattened.toList());
        for (Chat c in temp) {
          cm.createChatController(c, active: cm.activeChat?.chat.guid == c.guid);
        }
        accumulator.addAll(temp);
      }
      // De-dupe cached handles by address
      final ids = webCachedHandles.map((e) => e.address).toSet();
      webCachedHandles.retainWhere((element) => ids.remove(element.address));
      accumulator.sort(Chat.sort);
      chats.value = List<Chat>.from(accumulator);
      loadedChatBatch.value = true;
    }
  }

  /// Match the loaded contacts to cached handles and refresh chat tiles so
  /// contact names/avatars appear without user interaction (web only).
  void _matchWebContactsAndRefresh() {
    for (Contact c in cs.contacts) {
      final handles = cs.matchContactToHandles(c, webCachedHandles);
      for (Handle h in handles) {
        h.webContact = c;
      }
    }
    for (final chat in chats) {
      chat.title = null;
      chat.webSyncParticipants();
    }
    sort();
    for (final chat in chats) {
      WebListeners.notifyChatUpdate(chat);
    }
  }

  /// Load the remaining chat batches in the background (after the initial set),
  /// then re-match contacts so the newly loaded chats also show names.
  Future<void> _backgroundLoadRemainingChats(int startBatch, int endBatch, List<Chat> accumulator) async {
    try {
      LoadTimer.mark("Background chat load started (batches $startBatch-$endBatch)");
      await _fetchWebChatBatches(startBatch, endBatch, accumulator);
      if (cs.contacts.isNotEmpty) {
        _matchWebContactsAndRefresh();
      }
      LoadTimer.mark("All chats loaded (${chats.length})");
      Logger.info("Background chat load complete (${chats.length}).", tag: "ChatBloc");
    } catch (e, s) {
      Logger.error("Failed to background-load remaining chats", error: e, trace: s, tag: "ChatBloc");
    } finally {
      LoadTimer.completeSubsystem('chats');
    }
  }

  @override
  void onClose() {
    countSub.cancel();
    super.onClose();
  }

  void sort() {
    final ids = chats.map((e) => e.guid).toSet();
    chats.retainWhere((element) => ids.remove(element.guid));
    chats.sort(Chat.sort);
    chats.refresh();
  }

  bool updateChat(Chat updated, {bool shouldSort = false, bool override = false}) {
    final index = chats.indexWhere((e) => updated.guid == e.guid);
    if (index != -1) {
      final toUpdate = chats[index];
      // this is so the list doesn't re-render
      // ignore: invalid_use_of_protected_member
      chats.value[index] = override ? updated : updated.merge(toUpdate);
      if (shouldSort) sort();
    }

    return index != -1;
  }

  Future<void> addChat(Chat toAdd) async {
    final index = chats.indexWhere((e) => e.guid == toAdd.guid);
    if (index != -1) {
      chats[index] = toAdd;
    } else {
      chats.add(toAdd);
      cm.createChatController(toAdd);
    }
    sort();
  }

  void removeChat(Chat toRemove) {
    final index = chats.indexWhere((e) => toRemove.guid == e.guid);
    chats.removeAt(index);
  }

  void markAllAsRead() {
    final _chats = Database.chats.query(Chat_.hasUnreadMessage.equals(true)).build().find();
    for (Chat c in _chats) {
      c.hasUnreadMessage = false;
      mcs.invokeMethod(
        "delete-notification",
        {
          "notification_id": c.id,
          "tag": NotificationsService.NEW_MESSAGE_TAG
        }
      );
      if (ss.settings.enablePrivateAPI.value && ss.settings.privateMarkChatAsRead.value) {
        http.markChatRead(c.guid);
      }
    }
    Database.chats.putMany(_chats);
  }

  void updateChatPinIndex(int oldIndex, int newIndex) {
    final items = chats.bigPinHelper(true);
    final item = items[oldIndex];

    // Remove the item at the old index, and re-add it at the newIndex
    // We dynamically subtract 1 from the new index depending on if the newIndex is > the oldIndex
    items.removeAt(oldIndex);
    items.insert(newIndex + (oldIndex < newIndex ? -1 : 0), item);

    // Move the pinIndex for each of the chats, and save the pinIndex in the DB
    items.forEachIndexed((i, e) {
      e.pinIndex = i;
      e.save(updatePinIndex: true);
    });
    chats.sort(Chat.sort);
  }

  void removePinIndices() {
    chats.bigPinHelper(true).where((e) => e.pinIndex != null).forEach((element) {
      element.pinIndex = null;
      element.save(updatePinIndex: true);
    });
    chats.sort(Chat.sort);
  }
}
