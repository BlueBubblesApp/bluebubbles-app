import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/ui/chat/chat_stats/chat_stats_models.dart';
import 'package:collection/collection.dart';

class ChatStatsQueries {
  /// "Real" messages only. Excludes, in order:
  /// - soft-deleted messages
  /// - rows with no timestamp (nothing time-based can use them)
  /// - reactions AND stickers (both carry `associatedMessageGuid`) — separate
  ///   rows pointing at a target message, not messages in their own right
  /// - group events (`itemType != 0`) — name changes, joins/leaves, photo changes
  ///
  /// [sinceMillis], when given, additionally requires `dateCreated >=` it —
  /// this is how the page-level [StatsTimeframe] selector re-scopes every
  /// section's queries to a window ending now, without touching the
  /// aggregation code in `chat_stats_computer.dart` at all.
  static Condition<Message> realMessages({int? sinceMillis}) {
    var cond = Message_.dateDeleted
        .isNull()
        .and(Message_.dateCreated.notNull())
        .and(Message.notReactionCondition)
        .and(Message_.itemType.equals(0));
    if (sinceMillis != null) cond = cond.and(Message_.dateCreated.greaterOrEqual(sinceMillis));
    return cond;
  }

  static QueryBuilder<Message> _forChat(Chat chat, Condition<Message> cond) =>
      Database.messages.query(cond)..link(Message_.chat, Chat_.id.equals(chat.id!));

  // A participant is a person, not a handle. macOS links a merged iMessage/SMS
  // conversation to both of a person's handles and their messages arrive under
  // either one, so keying by `Handle.id` would show one person as two rows.
  // Every participant-keyed result here is keyed by a participant id from
  // [_participantIdsByHandle], and every per-participant filter goes through
  // [_linkParticipant], which matches all of that person's handles.

  /// Maps local sender `Handle.id`s to participant ids. A person's participant
  /// id is the lowest id among their handles linked to [chat], so a current
  /// member's id is always in `chat.handles` (the tabs' departed-member check
  /// relies on it); for someone who has left, the lowest among every handle
  /// with their address. It depends only on the chat and the address, never on
  /// which messages a query read, so every query agrees on it.
  static Map<int, int> _participantIdsByHandle(Chat chat, Iterable<int> handleIds) {
    final ids = handleIds.where((id) => id > 0).toSet();
    if (ids.isEmpty) return const {};
    final senders = Database.handles.getMany(ids.toList()).nonNulls.toList();
    if (senders.isEmpty) return const {};
    final q = Database.handles.query(Handle_.address.oneOf(senders.map((h) => h.address).toSet().toList())).build();
    final List<Handle> sameAddress;
    try {
      sameAddress = q.find();
    } finally {
      q.close();
    }
    final memberIds = chat.handles.map((h) => h.id).whereType<int>().toSet();
    // A handle linked to this chat beats one that is not; between equals, the lower id wins.
    bool preferred(int a, int b) {
      final aIsMember = memberIds.contains(a);
      final bIsMember = memberIds.contains(b);
      return aIsMember != bIsMember ? aIsMember : a < b;
    }
    final chosen = <String, int>{};
    for (final h in sameAddress) {
      final current = chosen[h.address];
      if (current == null || preferred(h.id!, current)) chosen[h.address] = h.id!;
    }
    return {for (final h in senders) h.id!: chosen[h.address] ?? h.id!};
  }

  /// Narrows the incoming messages in [qb] to one participant, across every
  /// handle with their address.
  static void _linkParticipant(QueryBuilder<Message> qb, int participantId) {
    final address = Database.handles.get(participantId)?.address;
    qb.link(
      Message_.handleRelation,
      address == null ? Handle_.id.equals(participantId) : Handle_.address.equals(address),
    );
  }

  /// The participant id for an incoming message's sender — [kMeParticipantId]
  /// is handled by the caller for outgoing ones. `Message.handleId` is the
  /// *server-side* `originalROWID`, not this app's local `Handle.id` — using
  /// it directly here would silently key every incoming message under an id
  /// nothing else recognizes. `handleRelation.targetId` is the local id, which
  /// [participantByHandle] (from [_participantIdsByHandle]) turns into the
  /// participant id; `targetId == 0` means the relation was never resolved.
  static int _senderId(Message m, Map<int, int> participantByHandle) {
    final targetId = m.handleRelation.targetId;
    return targetId == 0 ? kUnattributedParticipantId : (participantByHandle[targetId] ?? targetId);
  }

  static Map<int, int> _participantsOf(Chat chat, Iterable<Message> messages) => _participantIdsByHandle(
        chat,
        messages.where((m) => m.isFromMe != true).map((m) => m.handleRelation.targetId),
      );

  /// Ascending epoch-millis for every participant in the chat.
  ///
  /// Key is a participant id (see [_participantIdsByHandle]), except the local
  /// user, who is [kMeParticipantId].
  /// A 1:1 chat yields 2 entries; a group yields N+1. Downstream code never
  /// branches on group-ness — it just iterates the map.
  ///
  /// One query per participant, each hydrating `Message` entities to read
  /// `dateCreated` (see [_timestamps] for why `PropertyQuery` can't be used
  /// for a `Date`-typed column) — still one pass per participant rather than
  /// one per message, and far cheaper than resolving relations.
  static Map<int, List<int>> timestampsByParticipant(Chat chat, {int? sinceMillis}) {
    final result = <int, List<int>>{};

    result[kMeParticipantId] = _timestamps(
      _forChat(chat, realMessages(sinceMillis: sinceMillis).and(Message_.isFromMe.equals(true))),
    );

    // Include *historical* participants, not just current members — someone
    // who left the group still sent the messages they sent. Sourcing
    // participants from the messages themselves rather than from
    // `chat.handles` guarantees departed members are covered. Scoped to the
    // same window — a departed member with no activity inside it simply
    // doesn't appear, which is correct for that window.
    for (final participantId in participantIds(chat, sinceMillis: sinceMillis)) {
      final qb = _forChat(chat, realMessages(sinceMillis: sinceMillis).and(Message_.isFromMe.equals(false)));
      _linkParticipant(qb, participantId);
      result[participantId] = _timestamps(qb);
    }

    return result;
  }

  /// Distinct participant ids (see [_participantIdsByHandle]) of the senders
  /// of this chat's incoming messages. Hydrates rather than using
  /// `PropertyQuery`: the relation's local target id isn't exposed as a plain
  /// queryable column, only `Message.handleId` (the wrong, server-side id) is.
  static List<int> participantIds(Chat chat, {int? sinceMillis}) {
    final q = _forChat(chat, realMessages(sinceMillis: sinceMillis).and(Message_.isFromMe.equals(false))).build();
    try {
      return _participantsOf(chat, q.find()).values.toSet().toList();
    } finally {
      q.close();
    }
  }

  /// Incoming messages whose sender could not be attributed to a handle.
  /// Non-zero means the leaderboard will under-report — surface it, never
  /// silently drop them (see Task 12).
  static int unattributedCount(Chat chat, {int? sinceMillis}) => count(
        chat,
        realMessages(sinceMillis: sinceMillis).and(Message_.isFromMe.equals(false)).and(Message_.handleRelation.isNull()),
      );

  /// Sorted in Dart. Hydrates entities rather than using `PropertyQuery` —
  /// objectbox-dart's property-query projection doesn't support `Date`-typed
  /// columns at all (`dateCreated`/`dateRead` are `OBXPropertyType.Date`;
  /// `PropertyQuery.find()` throws "unsupported type" for it), so this can't
  /// use the raw-column path the rest of this file uses for int/string
  /// columns. Kept isolated here so the rest of the query layer still gets
  /// the `PropertyQuery` win.
  static List<int> _timestamps(QueryBuilder<Message> qb) {
    final q = qb.build();
    try {
      return q.find().map((m) => m.dateCreated!.millisecondsSinceEpoch).toList()..sort();
    } finally {
      q.close();
    }
  }

  /// `dateRead` millis for messages *I* sent that were read. 1:1 only —
  /// `dateRead` is a single column with no per-participant breakdown, so in a
  /// group it says "somebody read it" and cannot support per-person metrics.
  /// See [_timestamps] for why this hydrates rather than using `PropertyQuery`.
  static List<int> readTimestamps(Chat chat, {int? sinceMillis}) {
    final q = _forChat(
      chat,
      realMessages(sinceMillis: sinceMillis).and(Message_.isFromMe.equals(true)).and(Message_.dateRead.notNull()),
    ).build();
    try {
      return q.find().map((m) => m.dateRead!.millisecondsSinceEpoch).toList()..sort();
    } finally {
      q.close();
    }
  }

  static int count(Chat chat, Condition<Message> cond) {
    final q = _forChat(chat, cond).build();
    try {
      return q.count();
    } finally {
      q.close();
    }
  }

  static int totalMessages(Chat chat) => count(chat, realMessages());
  static int sentCount(Chat chat) => count(chat, realMessages().and(Message_.isFromMe.equals(true)));

  /// [participantId], when given, narrows incoming messages down to just
  /// that one participant — mirrors [recentTexts]' comparison-target scoping so
  /// the Correction Rate denominator matches whichever "theirs" numbers are
  /// on screen.
  static int receivedCount(Chat chat, {int? participantId}) {
    final qb = _forChat(chat, realMessages().and(Message_.isFromMe.equals(false)));
    if (participantId != null) _linkParticipant(qb, participantId);
    final q = qb.build();
    try {
      return q.count();
    } finally {
      q.close();
    }
  }

  static int attachmentMessageCount(Chat chat, {int? sinceMillis}) =>
      count(chat, realMessages(sinceMillis: sinceMillis).and(Message_.hasAttachments.equals(true)));

  /// [fromMe]/[participantId] narrow this to one side of the conversation —
  /// `participantId` only applies when `fromMe: false`, matching
  /// [recentTexts]'s comparison-target scoping.
  static int editedCount(Chat chat, {bool? fromMe, int? participantId}) {
    var cond = realMessages().and(Message_.dateEdited.notNull());
    if (fromMe != null) cond = cond.and(Message_.isFromMe.equals(fromMe));
    final qb = _forChat(chat, cond);
    if (fromMe == false && participantId != null) {
      _linkParticipant(qb, participantId);
    }
    final q = qb.build();
    try {
      return q.count();
    } finally {
      q.close();
    }
  }

  /// Reaction rows. Deliberately does NOT use [realMessages] — it inverts the
  /// reaction filter instead. Types arrive raw; a `-` prefix means *removed*.
  /// Normalization is the computer's job.
  ///
  /// [participantId] carries the reactor's id — [kMeParticipantId] for
  /// outgoing rows, [_senderId] (a participant id) for incoming ones — so
  /// callers can filter received reactions down to a single comparison
  /// target instead of always treating "received" as "from anyone but me".
  /// Hydrates entities (rather than the cheaper `PropertyQuery` the old
  /// implementation used) because the sender relation isn't exposed as a
  /// plain queryable column, matching [reactionMatrixData]'s approach.
  static List<({String type, int participantId})> reactions(Chat chat) {
    final q = _forChat(
      chat,
      Message_.dateDeleted.isNull().and(Message_.associatedMessageType.notNull()),
    ).build();
    try {
      final rows = q.find();
      final participants = _participantsOf(chat, rows);
      return rows
          .map((m) => (
                type: m.associatedMessageType!,
                participantId: m.isFromMe == true ? kMeParticipantId : _senderId(m, participants),
              ))
          .toList();
    } finally {
      q.close();
    }
  }

  /// Attachment mime types — feeds the attachment-mix donut.
  static List<String> attachmentMimeTypes(Chat chat) {
    final ids = _attachmentMessageIds(chat);
    if (ids.isEmpty) return const [];
    final q = (Database.attachments.query(Attachment_.mimeType.notNull())
          ..link(Attachment_.message, Message_.id.oneOf(ids)))
        .build();
    try {
      return q.property(Attachment_.mimeType).find();
    } finally {
      q.close();
    }
  }

  static List<int> _attachmentMessageIds(Chat chat, {bool? fromMe}) {
    var cond = realMessages().and(Message_.hasAttachments.equals(true));
    if (fromMe != null) cond = cond.and(Message_.isFromMe.equals(fromMe));
    final q = _forChat(chat, cond).build();
    try {
      return q.property(Message_.id).find();
    } finally {
      q.close();
    }
  }

  /// Cheap size probe — drives the adaptive detail tier (see main plan).
  /// Must run before any heavy work.
  static int messageCountForTier(Chat chat) => totalMessages(chat);

  /// Share of "real" messages that have non-null `text`. Content-tab metrics
  /// undercount by this gap — `text` is null when the content lives in
  /// `attributedBody` instead (see Task 11's feasibility gate).
  static double textCoverage(Chat chat) {
    final total = totalMessages(chat);
    if (total == 0) return 1.0;
    return count(chat, realMessages().and(Message_.text.notNull())) / total;
  }

  /// Most recent `limit` message texts for one side of the conversation,
  /// newest first. Capped rather than a full `PropertyQuery` fetch because a
  /// `PropertyQuery`'s ordering isn't guaranteed to follow the query's
  /// `order()` — capping requires hydrating entities so the "most recent N"
  /// guarantee actually holds.
  ///
  /// [participantId], when given alongside `fromMe: false`, narrows the
  /// incoming side to just that one participant — this is how the Content tab's
  /// comparison-target selector scopes "theirs" down to a single group
  /// member instead of everyone but me.
  static List<String> recentTexts(Chat chat, {required bool fromMe, int? limit, int? participantId}) {
    final cond = realMessages().and(Message_.isFromMe.equals(fromMe)).and(Message_.text.notNull());
    final qb = _forChat(chat, cond)..order(Message_.dateCreated, flags: Order.descending);
    if (!fromMe && participantId != null) {
      _linkParticipant(qb, participantId);
    }
    final q = qb.build();
    try {
      if (limit != null) q.limit = limit;
      return q.find().map((m) => m.text!).toList();
    } finally {
      q.close();
    }
  }

  /// Text lengths (characters) for every participant in the chat, newest
  /// first per participant and optionally capped — mirrors
  /// [timestampsByParticipant]'s per-participant query shape so departed
  /// members are still included. [sinceMillis] scopes to the page-level
  /// [StatsTimeframe]; [limitPerParticipant] bounds how many of each
  /// participant's most recent texted messages are hydrated, matching the
  /// cap already applied to [recentTexts].
  static Map<int, List<int>> textLengthsByParticipant(Chat chat, {int? sinceMillis, int? limitPerParticipant}) {
    final result = <int, List<int>>{};

    result[kMeParticipantId] = _textLengths(
      _forChat(
        chat,
        realMessages(sinceMillis: sinceMillis).and(Message_.isFromMe.equals(true)).and(Message_.text.notNull()),
      ),
      limitPerParticipant,
    );

    for (final participantId in participantIds(chat, sinceMillis: sinceMillis)) {
      final qb = _forChat(
        chat,
        realMessages(sinceMillis: sinceMillis).and(Message_.isFromMe.equals(false)).and(Message_.text.notNull()),
      );
      _linkParticipant(qb, participantId);
      result[participantId] = _textLengths(qb, limitPerParticipant);
    }

    return result;
  }

  /// Hydrates rather than `PropertyQuery` for the same reason as
  /// [recentTexts] — capping to the most recent N requires entities, since a
  /// property projection isn't guaranteed to follow `order()`.
  static List<int> _textLengths(QueryBuilder<Message> qb, int? limit) {
    qb.order(Message_.dateCreated, flags: Order.descending);
    final q = qb.build();
    try {
      if (limit != null) q.limit = limit;
      return q.find().map((m) => m.text!.length).toList();
    } finally {
      q.close();
    }
  }

  /// Raw `expressiveSendStyleId` values ("slam", "confetti", etc. as Apple
  /// codes) — feeds the effects-used bar.
  static List<String> expressiveSendStyleIds(Chat chat) {
    final q = _forChat(chat, realMessages().and(Message_.expressiveSendStyleId.notNull())).build();
    try {
      return q.property(Message_.expressiveSendStyleId).find();
    } finally {
      q.close();
    }
  }

  /// Edited messages whose `messageSummaryInfo` reports at least one
  /// retracted part — i.e. actually unsent, not just edited. Small subset
  /// (bounded by [editedCount]), so hydrating entities to read the nested
  /// JSON field is cheap. [fromMe]/[participantId] scope this the same way
  /// as [editedCount].
  static int unsentCount(Chat chat, {bool? fromMe, int? participantId}) {
    var cond = realMessages().and(Message_.dateEdited.notNull());
    if (fromMe != null) cond = cond.and(Message_.isFromMe.equals(fromMe));
    final qb = _forChat(chat, cond);
    if (fromMe == false && participantId != null) {
      _linkParticipant(qb, participantId);
    }
    final q = qb.build();
    try {
      return q.find().where((m) => m.retractedParts.isNotEmpty).length;
    } finally {
      q.close();
    }
  }

  static int _audioAttachmentCount(Chat chat, bool fromMe) {
    final ids = _attachmentMessageIds(chat, fromMe: fromMe);
    if (ids.isEmpty) return 0;
    final q = (Database.attachments.query(Attachment_.mimeType.startsWith('audio'))
          ..link(Attachment_.message, Message_.id.oneOf(ids)))
        .build();
    try {
      return q.count();
    } finally {
      q.close();
    }
  }

  /// Sent vs. received audio-attachment counts, plus what share of received
  /// audio was actually played (`datePlayed`). `playedOfReceived` is null when
  /// nothing was received, matching the read-receipt-coverage null pattern.
  static ({int sent, int received, double? playedOfReceived}) audioStats(Chat chat) {
    final sent = _audioAttachmentCount(chat, true);
    final received = _audioAttachmentCount(chat, false);
    final played = count(
      chat,
      realMessages().and(Message_.isFromMe.equals(false)).and(Message_.datePlayed.notNull()),
    );
    return (sent: sent, received: received, playedOfReceived: received == 0 ? null : played / received);
  }

  /// Group-membership/name/photo events (`itemType != 0`), deliberately
  /// excluded from [realMessages]. Cheap — a single query, no aggregation.
  static List<GroupEventRecord> groupEvents(Chat chat) {
    final q = (_forChat(chat, Message_.dateDeleted.isNull().and(Message_.itemType.notEquals(0)))
          ..order(Message_.dateCreated))
        .build();
    try {
      final events = q.find().where((m) => m.dateCreated != null).toList();
      final participants = _participantsOf(chat, events);
      return events
          .map((m) => GroupEventRecord(
                itemType: m.itemType ?? 0,
                groupActionType: m.groupActionType ?? 0,
                groupTitle: m.groupTitle,
                dateMillis: m.dateCreated!.millisecondsSinceEpoch,
                senderId: m.isFromMe == true ? kMeParticipantId : _senderId(m, participants),
              ))
          .toList();
    } finally {
      q.close();
    }
  }

  /// Raw who-reacts-to-whom inputs, windowed to [sinceMillis]. Two hydrated
  /// queries (not `PropertyQuery`) because the matrix needs guid + sender
  /// together, which a single-column property query can't return. This is
  /// the heaviest operation in the feature — callers must cap the window and
  /// gate it behind explicit user action (see Task 12).
  static ({List<ReactionMatrixRow> reactionRows, Map<String, int> guidToSender}) reactionMatrixData(
    Chat chat, {
    required int sinceMillis,
  }) {
    final List<Message> messages;
    final msgQuery = _forChat(chat, realMessages().and(Message_.dateCreated.greaterThan(sinceMillis))).build();
    try {
      messages = msgQuery.find();
    } finally {
      msgQuery.close();
    }

    final List<Message> reactions;
    final reactionQuery = _forChat(
      chat,
      Message_.dateDeleted
          .isNull()
          .and(Message_.associatedMessageType.notNull())
          .and(Message_.dateCreated.greaterThan(sinceMillis)),
    ).build();
    try {
      reactions = reactionQuery.find();
    } finally {
      reactionQuery.close();
    }

    final participants = _participantsOf(chat, [...messages, ...reactions]);
    final guidToSender = <String, int>{};
    for (final m in messages) {
      final guid = m.guid;
      if (guid == null) continue;
      guidToSender[guid] = m.isFromMe == true ? kMeParticipantId : _senderId(m, participants);
    }

    final reactionRows = <ReactionMatrixRow>[];
    for (final m in reactions) {
      final targetGuid = m.associatedMessageGuid;
      final type = m.associatedMessageType;
      if (targetGuid == null || type == null) continue;
      reactionRows.add(ReactionMatrixRow(
        targetGuid: targetGuid,
        reactorId: m.isFromMe == true ? kMeParticipantId : _senderId(m, participants),
        type: type,
      ));
    }

    return (reactionRows: reactionRows, guidToSender: guidToSender);
  }

  /// Absolute earliest "real" message in the chat. Unlike everything else in
  /// this file, deliberately ignores the page-level [StatsTimeframe] window —
  /// "the first message we've tracked" should reflect the chat's full
  /// history, not whatever span happens to be selected.
  static int? firstMessageMillis(Chat chat) {
    final q = (_forChat(chat, realMessages())..order(Message_.dateCreated)).build();
    try {
      q.limit = 1;
      return q.find().firstOrNull?.dateCreated?.millisecondsSinceEpoch;
    } finally {
      q.close();
    }
  }

  /// Cache key input — changes whenever the chat gains or loses messages.
  /// `count()` is native-side and cheap; the latest timestamp only needs the
  /// single newest row, not every row (see [_timestamps] on why `dateCreated`
  /// can't go through `PropertyQuery` here anyway).
  static ({int count, int latestMillis}) cacheKey(Chat chat) {
    final total = totalMessages(chat);
    final q = (_forChat(chat, realMessages())..order(Message_.dateCreated, flags: Order.descending)).build();
    try {
      q.limit = 1;
      final latest = q.find().firstOrNull;
      return (count: total, latestMillis: latest?.dateCreated?.millisecondsSinceEpoch ?? 0);
    } finally {
      q.close();
    }
  }
}
