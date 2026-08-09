import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';

class SyncActions {
  // ---------------------------------------------------------------------------
  // Unified sync entrypoint
  // ---------------------------------------------------------------------------

  /// Syncs handles, chats, messages, and attachments from raw API maps in one
  /// atomic write transaction.
  ///
  /// [data] keys:
  ///   - `chatData`               Map<String,dynamic>?  — top-level chat (optional)
  ///   - `messagesData`           List<Map<String,dynamic>> — raw server message maps
  ///
  /// Returns a map with `messageIds` (List<int>) and `chatIds` (List<int>) of updated chats.
  static Future<Map<String, dynamic>> bulkSyncData(dynamic data) async {
    if (kIsWeb) return {'messageIds': <int>[], 'chatIds': <int>[]};

    final chatData = data['chatData'] as Map<String, dynamic>?;
    final messagesData = (data['messagesData'] as List).cast<Map<String, dynamic>>();

    // -------------------------------------------------------------------------
    // Pre-transaction: collect all unique handle maps and format addresses.
    // (async I/O cannot happen inside a DB transaction)
    // -------------------------------------------------------------------------
    final Map<String, Map<String, dynamic>> uniqueHandleMapsByKey = {};

    void collectParticipants(List<dynamic>? participants) {
      for (final raw in (participants ?? const []).whereType<Map>()) {
        final h = raw.cast<String, dynamic>();
        final key = _handleKey(h);
        uniqueHandleMapsByKey[key] ??= h;
      }
    }

    if (chatData != null) {
      collectParticipants(chatData['participants'] as List?);
    }

    for (final msgData in messagesData) {
      // Persist each message's own sender handle. For multi-handle iMessage
      // contacts (e.g. phone + email both registered), a received message can
      // come from a handle that is not a chat participant; without saving it,
      // the message's handle is unresolvable and it gets culled at display
      // time by the participant-match filter in ChatActions.getMessagesAsync.
      collectParticipants([msgData['handle']]);
      for (final chat in (msgData['chats'] as List? ?? const []).whereType<Map>()) {
        collectParticipants(chat.cast<String, dynamic>()['participants'] as List?);
      }
    }

    // Build a guid→map for all unique chats so we can look them up inside the tx.
    final Map<String, Map<String, dynamic>> chatDataByGuid = {};
    if (chatData != null) {
      chatDataByGuid[chatData['guid'] as String] = chatData;
    }
    for (final msgData in messagesData) {
      for (final raw in (msgData['chats'] as List? ?? const []).whereType<Map>()) {
        final c = raw.cast<String, dynamic>();
        final guid = c['guid'] as String?;
        if (guid != null) chatDataByGuid[guid] ??= c;
      }
    }

    // Sync handles (async: address formatting cannot run inside a DB transaction).
    final handlesMap = await _syncHandles(uniqueHandleMapsByKey.values.toList());

    // -------------------------------------------------------------------------
    // Single write transaction
    // -------------------------------------------------------------------------
    return Database.runInTransaction(TxMode.write, () {
      final handleBox = Database.handles;
      final chatBox = Database.chats;
      final messageBox = Database.messages;
      final attachmentBox = Database.attachments;

      // Build lookup for message→handle wiring (by originalROWID).
      // Fetch all DB handles so we don't miss handles from previous syncs.
      final allHandles = handleBox.getAll();
      final handlesByRowId = <int, Handle>{};
      for (final h in allHandles) {
        if (h.originalROWID != null) handlesByRowId[h.originalROWID!] = h;
      }

      // Step 1 – Sync chats → Map<chatGuid, Chat>
      final chatsMap = _syncChatsInTx(chatDataByGuid, handlesMap, chatBox);

      // Step 2 – Sync messages → (savedMessages, messagesByGuid)
      final (savedMessages, messagesByGuid) =
          _syncMessagesInTx(messagesData, chatData, chatsMap, handlesByRowId, messageBox);

      // Step 3 – Sync attachments (via Attachment.message.target — no applyToDb needed)
      _syncAttachmentsInTx(messagesData, messagesByGuid, attachmentBox, messageBox);

      // Step 4 – Update each chat's latestMessage
      final updatedChatIds = _updateLatestMessages(chatsMap, chatBox);

      return {
        'messageIds': savedMessages.map((m) => m.id!).toList(),
        'chatIds': updatedChatIds,
      };
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers (all run inside the transaction)
  // ---------------------------------------------------------------------------

  static String _handleKey(Map<String, dynamic> h) {
    final addr = (h['address'] as String?) ?? '';
    final svc = (h['service'] as String?) ?? 'iMessage';
    return '$addr/$svc';
  }

  /// Upsert handles.  Returns a map keyed by `uniqueAddressAndService`.
  /// Converts raw maps → Handle objects, formats addresses (async), then
  /// upserts in its own write transaction.
  static Future<Map<String, Handle>> _syncHandles(
    List<Map<String, dynamic>> rawHandleMaps,
  ) async {
    if (rawHandleMaps.isEmpty) return {};

    final inputHandles = rawHandleMaps.map((h) => Handle.fromMap(h)).toList();
    for (final h in inputHandles) {
      await h.updateFormattedAddress();
    }

    return Database.runInTransaction(TxMode.write, () {
      final handleBox = Database.handles;
      final inputKeys = inputHandles.map((h) => h.uniqueAddressAndService).toList();
      final existingQuery = handleBox.query(Handle_.uniqueAddressAndService.oneOf(inputKeys)).build();
      final existingHandles = existingQuery.find();
      existingQuery.close();

      final existingMap = <String, Handle>{
        for (final h in existingHandles) h.uniqueAddressAndService: h,
      };

      final newHandles = inputHandles.where((h) => !existingMap.containsKey(h.uniqueAddressAndService)).toList();
      if (newHandles.isNotEmpty) {
        handleBox.putMany(newHandles);
      }

      return {
        ...existingMap,
        for (final h in newHandles) h.uniqueAddressAndService: h,
      };
    });
  }

  /// Upsert chats and link their participants.  Returns a map keyed by chat GUID.
  static Map<String, Chat> _syncChatsInTx(
    Map<String, Map<String, dynamic>> chatDataByGuid,
    Map<String, Handle> handlesMap,
    Box<Chat> chatBox,
  ) {
    if (chatDataByGuid.isEmpty) return {};

    final inputChats = chatDataByGuid.values.map((c) => Chat.fromMap(c)).toList();
    final inputGuids = inputChats.map((c) => c.guid).toList();

    final existingQuery = chatBox.query(Chat_.guid.oneOf(inputGuids)).build();
    final existingChats = existingQuery.find();
    existingQuery.close();

    final existingMap = <String, Chat>{
      for (final c in existingChats) c.guid: c,
    };

    final chatsToSave = <Chat>[];
    final chatHandlesMap = <String, List<Handle>>{};

    for (final inputChat in inputChats) {
      final existing = existingMap[inputChat.guid];
      final chatToSave = existing ?? inputChat;

      if (existing != null) {
        if (inputChat.displayName != null && inputChat.displayName!.isNotEmpty) {
          chatToSave.displayName = inputChat.displayName;
        }
        chatToSave.chatIdentifier ??= inputChat.chatIdentifier;
        chatToSave.style ??= inputChat.style;
        if (inputChat.isArchived == true) chatToSave.isArchived = true;
      }

      // Collect handles to link from the raw participants list.
      final rawChat = chatDataByGuid[inputChat.guid]!;
      final participantMaps =
          ((rawChat['participants'] as List?) ?? const []).whereType<Map>().map((p) => p.cast<String, dynamic>());
      final handlesToLink = <Handle>[];
      for (final pm in participantMaps) {
        final h = handlesMap[_handleKey(pm)];
        if (h != null && h.id != null) handlesToLink.add(h);
      }

      chatHandlesMap[inputChat.guid] = handlesToLink;
      chatsToSave.add(chatToSave);
    }

    chatBox.putMany(chatsToSave);

    // Link handles after put so the chat has a valid id.
    for (final chat in chatsToSave) {
      final handles = chatHandlesMap[chat.guid];
      if (handles != null && handles.isNotEmpty) {
        chat.handles.clear();
        chat.handles.addAll(handles);
        chat.handles.applyToDb();
      }
    }

    return {for (final c in chatsToSave) c.guid: c};
  }

  /// Upsert messages, wire them to chats and handles, and update hasReactions.
  /// Returns the saved message list and a guid→Message map.
  static (List<Message>, Map<String, Message>) _syncMessagesInTx(
    List<Map<String, dynamic>> messagesData,
    Map<String, dynamic>? topLevelChatData,
    Map<String, Chat> chatsMap,
    Map<int, Handle> handlesByRowId,
    Box<Message> messageBox,
  ) {
    if (messagesData.isEmpty) return ([], {});

    final inputMessages = messagesData.map((m) {
      final msg = Message.fromMap(m);
      if (msg.error > 0) msg.errorMessage = serverErrorMessage(msg.error);
      return msg;
    }).toList();

    final inputGuids = inputMessages.map((m) => m.guid!).toList();
    final existingQuery = messageBox.query(Message_.guid.oneOf(inputGuids)).build();
    final existingMessages = existingQuery.find();
    existingQuery.close();

    final existingMap = <String, Message>{
      for (final m in existingMessages) m.guid!: m,
    };

    // When a single top-level chat is provided all messages belong to it.
    final singleChat = topLevelChatData != null ? chatsMap[topLevelChatData['guid'] as String?] : null;

    final messagesToSave = <Message>[];
    for (int i = 0; i < inputMessages.length; i++) {
      final inputMsg = inputMessages[i];
      final msgData = messagesData[i];
      final existing = existingMap[inputMsg.guid];
      final msgToSave = existing != null ? Message.merge(existing, inputMsg) : inputMsg;

      // Wire to chat.
      Chat? chat = singleChat;
      if (chat == null) {
        final embeddedChats = (msgData['chats'] as List? ?? const []).whereType<Map>();
        for (final raw in embeddedChats) {
          final guid = raw.cast<String, dynamic>()['guid'] as String?;
          if (guid != null) {
            chat = chatsMap[guid];
            if (chat != null) break;
          }
        }
      }
      if (chat != null) msgToSave.chat.target = chat;

      // Wire to handle (by server originalROWID).
      if (!msgToSave.handleRelation.hasValue && msgToSave.handleId != null && msgToSave.handleId! > 0) {
        final handle = handlesByRowId[msgToSave.handleId];
        if (handle != null) {
          msgToSave.handleRelation.target = handle;
          msgToSave.handle = handle;
        }
      } else if (msgToSave.handleRelation.hasValue && msgToSave.handle == null) {
        msgToSave.handle = msgToSave.handleRelation.target;
      }

      messagesToSave.add(msgToSave);
    }

    messageBox.putMany(messagesToSave);

    final messagesByGuid = <String, Message>{
      for (final m in messagesToSave)
        if (m.guid != null) m.guid!: m,
    };

    // Update hasReactions on associated messages.
    final reactionsUpdate = <String, Message>{};
    for (final msg in messagesToSave) {
      final associatedGuid = msg.associatedMessageGuid;
      if ((associatedGuid ?? '').isEmpty) continue;

      Message? associated = messagesByGuid[associatedGuid];
      if (associated == null) {
        final q = messageBox.query(Message_.guid.equals(associatedGuid!)).build();
        q.limit = 1;
        associated = q.findFirst();
        q.close();
      }
      if (associated != null && !associated.hasReactions) {
        associated.hasReactions = true;
        reactionsUpdate[associated.guid!] = associated;
      }
    }
    if (reactionsUpdate.isNotEmpty) {
      try {
        messageBox.putMany(reactionsUpdate.values.toList());
      } catch (ex) {
        Logger.warn('Failed to update hasReactions: $ex', tag: 'SyncActions');
      }
    }

    return (messagesToSave, messagesByGuid);
  }

  /// Upsert attachments and link them to their owner message via
  /// `Attachment.message.target` (the owning ToOne side of the backlink).
  /// Also ensures [Message.hasAttachments] is set to `true` on any owner message
  /// that received at least one attachment in this sync.
  static void _syncAttachmentsInTx(
    List<Map<String, dynamic>> messagesData,
    Map<String, Message> messagesByGuid,
    Box<Attachment> attachmentBox,
    Box<Message> messageBox,
  ) {
    // Collect all attachment maps and their owner message GUID.
    final attachmentMaps = <Map<String, dynamic>>[];
    final ownerGuidByAttachmentGuid = <String, String>{};

    for (final msgData in messagesData) {
      final msgGuid = msgData['guid'] as String?;
      if (msgGuid == null) continue;
      for (final raw in (msgData['attachments'] as List? ?? const []).whereType<Map>()) {
        final a = raw.cast<String, dynamic>();
        final aGuid = a['guid'] as String?;
        if (aGuid == null || ownerGuidByAttachmentGuid.containsKey(aGuid)) continue;
        attachmentMaps.add(a);
        ownerGuidByAttachmentGuid[aGuid] = msgGuid;
      }
    }

    if (attachmentMaps.isEmpty) return;

    final inputAttachments = attachmentMaps.map((a) => Attachment.fromMap(a)).toList();
    final inputGuids = inputAttachments.map((a) => a.guid!).toList();

    final existingQuery = attachmentBox.query(Attachment_.guid.oneOf(inputGuids)).build();
    final existingAttachments = existingQuery.find();
    existingQuery.close();

    final existingMap = <String, Attachment>{
      for (final a in existingAttachments) a.guid!: a,
    };

    final attachmentsToSave = <Attachment>[];
    final messagesNeedingFlagUpdate = <Message>{};
    for (final inputA in inputAttachments) {
      final toSave = existingMap[inputA.guid] ?? inputA;
      final ownerGuid = ownerGuidByAttachmentGuid[inputA.guid];
      if (ownerGuid != null) {
        final msg = messagesByGuid[ownerGuid];
        if (msg?.id != null) {
          toSave.message.target = msg;
          if (!msg!.hasAttachments) {
            msg.hasAttachments = true;
            messagesNeedingFlagUpdate.add(msg);
          }
        }
      }
      attachmentsToSave.add(toSave);
    }

    attachmentBox.putMany(attachmentsToSave);

    if (messagesNeedingFlagUpdate.isNotEmpty) {
      messageBox.putMany(messagesNeedingFlagUpdate.toList());
    }
  }

  /// Query the DB for each chat's true latest message and persist it.
  /// Returns the IDs of updated chats.
  static List<int> _updateLatestMessages(
    Map<String, Chat> chatsMap,
    Box<Chat> chatBox,
  ) {
    final chatsToUpdate = <Chat>[];

    for (final chat in chatsMap.values) {
      if (chat.id == null) continue;
      final q = (Database.messages.query(Message_.dateDeleted.isNull())
            ..link(Message_.chat, Chat_.id.equals(chat.id!))
            ..order(Message_.dateCreated, flags: Order.descending))
          .build();
      q.limit = 1;
      final latest = q.findFirst();
      q.close();

      if (latest != null) {
        chat.setLatestMessage(latest);
        chatsToUpdate.add(chat);
      }
    }

    if (chatsToUpdate.isNotEmpty) {
      chatBox.putMany(chatsToUpdate);
    }

    return chatsToUpdate.map((c) => c.id!).toList();
  }

  // ---------------------------------------------------------------------------
  // Existing actions
  // ---------------------------------------------------------------------------

  /// Performs an incremental sync of chats
  static Future<List<int>> performIncrementalSync(dynamic data) async {
    try {
      int syncStart = SettingsSvc.settings.lastIncrementalSync.value;
      int startRowId = SettingsSvc.settings.lastIncrementalSyncRowId.value;

      final incrementalSyncManager =
          IncrementalSyncManager(startTimestamp: syncStart, startRowId: startRowId, saveMarker: true);

      await incrementalSyncManager.start();
      return incrementalSyncManager.latestMessageIdPerChat.values.toList();
    } catch (ex, s) {
      Logger.error('Incremental sync failed!', error: ex, trace: s);
      rethrow;
    }
  }
}
