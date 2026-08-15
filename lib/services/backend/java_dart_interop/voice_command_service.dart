import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator_utils.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/backend/startup_tasks.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';

// ignore: non_constant_identifier_names
VoiceCommandService get VoiceCommandSvc => GetIt.I<VoiceCommandService>();

/// A "send a message" request handed to the app by a voice assistant.
///
/// Assistant and Gemini both fulfill the `actions.intent.SEND_MESSAGE` /
/// `actions.intent.CREATE_MESSAGE` capabilities declared in
/// `android/app/src/main/res/xml/shortcuts.xml`. There are two shapes that can
/// arrive, and this models both:
///
///  * The capability's `<url-template>` expands into a `bluebubbles://voice/...`
///    deep link carrying the spoken parameters as query parameters.
///  * The assistant grounded the spoken recipient against one of the dynamic
///    shortcuts donated in `PushShareTargetsHandler`, in which case it launches
///    that shortcut's own intent — which already carries a `chatGuid` extra —
///    and passes the remaining parameters as intent extras.
class VoiceCommandRequest {
  /// An exact chat, present only when a donated shortcut was matched.
  final String? chatGuid;

  /// The spoken recipient, e.g. "Mom" or "the family chat" (`message.recipient.name`).
  final String? recipientName;

  /// A phone number or email, when the assistant resolved one from its own
  /// contact index (`message.recipient.telephone`).
  final String? recipientAddress;

  /// The dictated message body (`message.text`). Absent when the user only
  /// named a recipient.
  final String? messageText;

  const VoiceCommandRequest({
    this.chatGuid,
    this.recipientName,
    this.recipientAddress,
    this.messageText,
  });

  /// Whether the assistant gave us anything at all to aim at. False when the
  /// capability's parameterless fallback intent fired, which just means "open
  /// BlueBubbles".
  bool get hasRecipient =>
      !isNullOrEmpty(chatGuid) || !isNullOrEmpty(recipientName) || !isNullOrEmpty(recipientAddress);

  /// URI scheme registered on `MainActivity` for assistant deep links.
  static const String scheme = 'bluebubbles';

  /// URI host reserved for voice commands. Kept distinct from other deep links
  /// so a future command only needs a new path.
  static const String host = 'voice';

  static const String recipientKey = 'recipient';
  static const String addressKey = 'address';
  static const String textKey = 'text';
  static const String chatGuidKey = 'chatGuid';

  /// Builds a request from a raw intent, or returns null when the intent isn't
  /// a voice command.
  ///
  /// Note what deliberately does *not* qualify: an intent carrying only
  /// `chatGuid`. That's an ordinary notification or launcher-shortcut tap and
  /// has to keep its existing "just open the chat" behaviour — a voice command
  /// always brings at least one App Action parameter or the voice deep link.
  static VoiceCommandRequest? parse({String? data, Map<String, dynamic>? extras}) {
    final parsed = isNullOrEmpty(data) ? null : Uri.tryParse(data!);
    final voiceUri = (parsed != null && parsed.scheme == scheme && parsed.host == host) ? parsed : null;

    String? read(String key) {
      final fromUri = voiceUri?.queryParameters[key];
      final fromExtras = extras?[key];
      final value = (fromUri ?? (fromExtras is String ? fromExtras : null))?.trim();
      return isNullOrEmpty(value) ? null : value;
    }

    final recipientName = read(recipientKey);
    final recipientAddress = read(addressKey);
    final messageText = read(textKey);

    if (voiceUri == null && recipientName == null && recipientAddress == null && messageText == null) {
      return null;
    }

    final guid = extras?[chatGuidKey];
    return VoiceCommandRequest(
      chatGuid: guid is String && guid.isNotEmpty ? guid : null,
      recipientName: recipientName,
      recipientAddress: recipientAddress,
      messageText: messageText,
    );
  }

  @override
  String toString() => 'VoiceCommandRequest(chatGuid: $chatGuid, recipientName: $recipientName, '
      'recipientAddress: ${recipientAddress == null ? 'null' : 'set'}, '
      'messageText: ${messageText == null ? 'null' : '${messageText!.length} chars'})';
}

/// One chat considered as a match for a spoken recipient, with the strength of
/// that match. Higher is better; see [VoiceCommandService.scoreChat].
class ScoredChat {
  final Chat chat;
  final int score;

  const ScoredChat(this.chat, this.score);
}

/// Turns voice-assistant "send a message" requests into a real send.
///
/// Deliberately scoped to conversations that already exist. Creating a chat
/// requires knowing the exact address and service to send on, neither of which
/// a spoken name reliably determines, so an unmatched recipient is reported as
/// an error rather than guessed at.
///
/// The Android intent is currently the only entry point, but nothing below
/// depends on it — [handleRequest] takes a plain [VoiceCommandRequest], so a
/// future assistant integration (e.g. Android AppFunctions) only has to build
/// one of those.
class VoiceCommandService {
  static const String _tag = 'VoiceCommandService';

  /// Below this, a candidate is treated as no match at all rather than a weak one.
  static const int _minimumScore = 45;

  /// Shortest spoken recipient that may match on a substring or prefix rather
  /// than on whole words. See the guard in [_score].
  static const int _weakMatchMinLength = 3;

  /// Ceiling applied to any match that comes from a group's *participants*
  /// rather than the group's own name — a hit on a nameless group's
  /// auto-generated title ("Mom, Dad & 2 others"), or on a participant's
  /// address. Such a hit is real but weak: it says the person is in the group,
  /// not that the group is who the user meant. Capping it here keeps a
  /// dedicated 1:1 chat with that person always winning.
  static const int _groupParticipantCap = 50;

  /// Words assistants routinely keep in the transcribed recipient that are never
  /// part of a contact or group name ("send a message to *my* mom").
  static const Set<String> _leadingFiller = {'my', 'the', 'a', 'an', 'to'};

  /// Trailing nouns users add when naming a thread ("the family *chat*").
  static const Set<String> _trailingFiller = {'chat', 'chats', 'conversation', 'group', 'thread'};

  /// Entry point for a voice command. Surfaces its own errors to the user.
  ///
  /// [isInitialIntent] is forwarded to [IntentsService.openChat] and carries the
  /// same meaning it does there: true when this arrived as the Activity's launch
  /// intent, where a surviving `activeChat` can't be trusted to reflect what is
  /// actually on screen.
  Future<void> handleRequest(VoiceCommandRequest request, {bool isInitialIntent = false}) async {
    if (kIsWeb || kIsDesktop) return;
    Logger.info('Handling voice command: $request', tag: _tag);

    await StartupTasks.waitForUI();
    final context = Get.context;
    if (context == null) {
      Logger.warn('No context available; dropping voice command', tag: _tag);
      return;
    }

    // The capability's fallback intent fires when the assistant couldn't pin
    // down who the message is for. That isn't an error — the user asked to
    // message *someone*, so leave them on the chat list to pick.
    if (!request.hasRecipient) {
      Logger.info('Voice command carried no recipient; leaving the user on the chat list', tag: _tag);
      return;
    }

    final chat = await _resolveChat(context, request);
    if (chat == null) return;

    final text = request.messageText;
    if (isNullOrEmpty(text)) {
      // Recipient only. Open the conversation so the user can dictate or type
      // the body themselves.
      Logger.info('Resolved chat ${chat.guid} with no message body; opening it', tag: _tag);
      await IntentsSvc.openChat(chat.guid, isInitialIntent: isInitialIntent);
      return;
    }

    final autoSend = SettingsSvc.settings.voiceCommandAutoSend.value;
    final confirmed = autoSend || (await _confirmSend(context, chat, text!) ?? false);

    if (!confirmed) {
      // Cancelling must not throw the dictation away — drop the user into the
      // conversation with the text already in the composer so they can fix it.
      Logger.info('User declined the voice send; opening the chat with the text prefilled', tag: _tag);
      await IntentsSvc.openChat(chat.guid, text: text, isInitialIntent: isInitialIntent);
      return;
    }

    // Navigate first so the message animates into a visible conversation
    // rather than landing somewhere off-screen.
    await IntentsSvc.openChat(chat.guid, isInitialIntent: isInitialIntent);
    await _send(chat, text!);
  }

  // ── Chat resolution ──────────────────────────────────────────────────────

  /// Resolves the request to a single existing chat, or null after telling the
  /// user why it couldn't.
  Future<Chat?> _resolveChat(BuildContext context, VoiceCommandRequest request) async {
    // The assistant grounded against a donated shortcut, so it already told us
    // exactly which conversation this is — no matching required.
    if (request.chatGuid != null) {
      final chat = ChatsSvc.findChatByGuid(request.chatGuid!) ?? Chat.findOne(guid: request.chatGuid);
      if (chat != null) {
        Logger.info('Voice command resolved directly to shortcut chat ${chat.guid}', tag: _tag);
        return chat;
      }
      Logger.warn('Shortcut chat ${request.chatGuid} no longer exists; falling back to name matching', tag: _tag);
    }

    final chats = await _candidateChats();
    final spokenName = request.recipientName ?? '';

    if (chats.isEmpty) {
      await showBBDialog(
        context: context,
        title: 'No Conversations',
        body: "BlueBubbles doesn't have any conversations synced yet, so there's nothing to send to. "
            'Open the app and let it finish syncing, then try again.',
        actions: [
          BBDialogAction(
            text: 'OK',
            isDefault: true,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      );
      return null;
    }

    final matches = rankChats(chats, name: request.recipientName, address: request.recipientAddress);

    if (matches.isEmpty) {
      Logger.info('No chat matched "$spokenName"', tag: _tag);
      await showBBDialog(
        context: context,
        title: 'No Matching Conversation',
        body: isNullOrEmpty(spokenName)
            ? "BlueBubbles couldn't find an existing conversation for that recipient. "
                'Voice commands can only message conversations you already have.'
            : 'BlueBubbles has no existing conversation with "$spokenName". '
                'Voice commands can only message conversations you already have — '
                'start the chat in the app first.',
        actions: [
          BBDialogAction(
            text: 'OK',
            isDefault: true,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
      );
      return null;
    }

    if (matches.length == 1) {
      Logger.info('Voice command matched chat ${matches.first.chat.guid} (score ${matches.first.score})', tag: _tag);
      return matches.first.chat;
    }

    // Equally-good candidates — the app can't pick for the user without
    // risking a message going to the wrong person.
    Logger.info('Voice command was ambiguous between ${matches.length} chats; asking the user', tag: _tag);
    return await showBBListSelector<Chat>(
      context: context,
      title: 'Which Conversation?',
      message: isNullOrEmpty(spokenName)
          ? 'More than one conversation matches that recipient.'
          : 'More than one conversation matches "$spokenName".',
      options: _buildSelectorOptions(matches),
    );
  }

  /// Builds disambiguation labels, appending the service only when two
  /// candidates would otherwise read identically (the common case being the
  /// same person on both iMessage and SMS).
  List<BBListSelectorOption<Chat>> _buildSelectorOptions(List<ScoredChat> matches) {
    final titleCounts = <String, int>{};
    for (final match in matches) {
      final title = match.chat.getTitle();
      titleCounts[title] = (titleCounts[title] ?? 0) + 1;
    }

    return matches.map((match) {
      final title = match.chat.getTitle();
      final label = (titleCounts[title] ?? 0) > 1 ? '$title (${match.chat.isIMessage ? 'iMessage' : 'SMS'})' : title;
      return BBListSelectorOption<Chat>(label: label, value: match.chat);
    }).toList();
  }

  /// The set of chats to match against — every chat in the local database that
  /// hasn't been deleted.
  ///
  /// [ChatsService] mirrors the whole ObjectBox chat table in memory (it pages
  /// through it in batches of [ChatsService.batchSize] on startup), so reading
  /// from it avoids a redundant query while still covering every chat rather
  /// than just the loaded page. The wait matters on a cold start: a voice
  /// command can land before that paging finishes.
  Future<List<Chat>> _candidateChats() async {
    if (!ChatsSvc.loadedAllChats.isCompleted && ChatsSvc.hasChats.value) {
      Logger.debug('Waiting on the chat list before matching', tag: _tag);
      await ChatsSvc.loadedAllChats.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => Logger.warn('Chat list still loading; matching against what is loaded', tag: _tag),
      );
    }

    return ChatsSvc.allChats.where((chat) => chat.dateDeleted == null).toList();
  }

  // ── Matching ─────────────────────────────────────────────────────────────

  /// Ranks [chats] against a spoken recipient and returns every chat tied for
  /// the best score, or an empty list when nothing clears [_minimumScore].
  ///
  /// Returning the whole tied set rather than one winner is intentional: a tie
  /// means the app genuinely cannot tell which conversation was meant, and
  /// silently picking one risks sending to the wrong person.
  static List<ScoredChat> rankChats(List<Chat> chats, {String? name, String? address}) {
    final normalizedName = isNullOrEmpty(name) ? null : normalize(name!);

    // Single pass rather than sort-then-filter, so ties come back in the order
    // they arrived. `chats` is ordered by pin index then recency, and Dart's
    // List.sort isn't stable, so sorting would scramble that for equal scores.
    int best = 0;
    final matches = <ScoredChat>[];
    for (final chat in chats) {
      final score = scoreChat(chat, normalizedName: normalizedName, address: address);
      if (score < _minimumScore || score < best) continue;
      if (score > best) {
        best = score;
        matches.clear();
      }
      matches.add(ScoredChat(chat, score));
    }

    return matches;
  }

  /// Scores one chat against a spoken recipient. 0 means no match.
  static int scoreChat(Chat chat, {String? normalizedName, String? address}) {
    int best = 0;

    if (!isNullOrEmpty(address)) {
      for (final handle in chat.handles) {
        if (!ChatCreatorUtils.addressesMatch(address!, handle.address)) continue;
        // An exact address is the strongest signal there is for a 1:1 chat. In a
        // group it only says the person is among the participants, which is a
        // much weaker claim about who the user meant.
        best = max(best, chat.isGroup ? _groupParticipantCap : 100);
      }
    }

    if (normalizedName == null || normalizedName.isEmpty) return best;

    if (chat.isGroup) {
      final displayName = chat.displayName;
      if (!isNullOrEmpty(displayName)) {
        return max(best, _scoreAgainst(normalizedName, displayName!));
      }
      // A nameless group's title is its participant list ("Mom, Dad & 2 others"),
      // so "Mom" substring-matches every group she's in. Cap those.
      return max(best, min(_groupParticipantCap, _scoreAgainst(normalizedName, chat.getTitle())));
    }

    for (final handle in chat.handles) {
      best = max(best, _scoreAgainst(normalizedName, handle.displayName));
      best = max(best, _scoreAgainst(normalizedName, handle.shortName));
      // Covers a spoken phone number or email read back by the assistant.
      if (ChatCreatorUtils.addressesMatch(normalizedName, handle.address)) best = max(best, 100);
    }
    if (!isNullOrEmpty(chat.displayName)) {
      best = max(best, _scoreAgainst(normalizedName, chat.displayName!));
    }

    return best;
  }

  static int _scoreAgainst(String normalizedQuery, String rawCandidate) =>
      _score(normalizedQuery, normalize(rawCandidate));

  /// Tiered similarity between two already-normalized strings.
  ///
  /// The tiers are ordered so that a stronger kind of match on any candidate
  /// always beats a weaker kind on another — "Mom" should resolve to the chat
  /// literally named Mom, not to "Mommy's Book Club" just because it also
  /// contains the word.
  static int _score(String query, String candidate) {
    if (query.isEmpty || candidate.isEmpty) return 0;
    if (query == candidate) return 100;

    // One name is the start of the other: "mom" vs "mom smith".
    if (candidate.startsWith('$query ') || query.startsWith('$candidate ')) return 85;

    final queryTokens = query.split(' ');
    final candidateTokens = candidate.split(' ');

    // Every spoken word appears as a word of the candidate, in any order:
    // "smith john" vs "john smith".
    final candidateSet = candidateTokens.toSet();
    if (queryTokens.every(candidateSet.contains)) return 70;

    // The two substring/prefix tiers below are only meaningful for a query with
    // some substance to it. "a" or "jo" prefixes half the address book, and
    // every one of those hits would tie, turning a valid command into a
    // pointlessly long disambiguation list.
    if (query.length < _weakMatchMinLength) return 0;

    if (candidate.contains(query)) return 55;

    // Every spoken word at least prefixes a word of the candidate — catches
    // truncated or partially transcribed names.
    if (queryTokens.every((token) => candidateTokens.any((word) => word.startsWith(token)))) return 45;

    return 0;
  }

  /// Lower-cases, strips punctuation, collapses whitespace, and drops the filler
  /// words assistants keep in a transcribed recipient.
  ///
  /// Unicode letters are preserved — stripping to ASCII would mangle any
  /// accented name into something that matches nothing.
  static String normalize(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    final tokens = cleaned.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();

    while (tokens.length > 1 && _leadingFiller.contains(tokens.first)) {
      tokens.removeAt(0);
    }
    while (tokens.length > 1 && _trailingFiller.contains(tokens.last)) {
      tokens.removeLast();
    }

    return tokens.join(' ');
  }

  // ── Confirmation & send ──────────────────────────────────────────────────

  /// Asks the user to confirm before anything leaves the device. Returns null
  /// if the dialog was dismissed, which is treated as a cancel.
  Future<bool?> _confirmSend(BuildContext context, Chat chat, String text) {
    return showBBDialog<bool>(
      context: context,
      title: 'Send to ${chat.getTitle()}?',
      body: '"$text"',
      actions: [
        BBDialogAction(text: 'Cancel', onPressed: () => Navigator.of(context, rootNavigator: true).pop(false)),
        BBDialogAction(
          text: 'Send',
          isDefault: true,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
  }

  Future<void> _send(Chat chat, String text) async {
    Logger.info('Sending voice message to ${chat.guid}', tag: _tag);

    // Held so the temp GUID assigned during queueing can be used to check the
    // send outcome below.
    final message = Message(
      text: text,
      dateCreated: DateTime.now(),
      hasAttachments: false,
      isFromMe: true,
      handleId: 0,
    );

    final completer = Completer<void>();
    OutgoingMsgHandler.queue(OutgoingMessage(completer: completer, chat: chat, message: message));
    await completer.future;

    // A failed send is finalized inside the handler — the message is persisted
    // with an error code — and the completer still completes *normally*, so
    // waiting on it says nothing about success. Re-read the queued message to
    // find out. On success the temp GUID is swapped for the real one and this
    // lookup finds nothing.
    final tempGuid = message.guid;
    final failed = tempGuid != null && (Message.findOne(guid: tempGuid)?.error ?? 0) != 0;
    if (failed) {
      Logger.error('Voice message to ${chat.guid} failed to send', tag: _tag);
      showSnackbar('Failed to Send', 'Your message to ${chat.getTitle()} could not be sent.');
    }
  }
}
