import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/types/extensions/extensions.dart';
import 'package:collection/collection.dart';

/// The iMessage effect name (as keyed in [effectMap]) a message was sent with,
/// or `null` when it carries no expressive send style.
String? effectNameOf(Message message) {
  if (message.expressiveSendStyleId == null) return null;
  return effectMap.entries.firstWhereOrNull((e) => e.value == message.expressiveSendStyleId)?.key;
}

/// The [MessageEffect] a message was sent with.
///
/// Returns [MessageEffect.none] when the message carries no expressive send
/// style, or one this client doesn't recognise.
MessageEffect effectOf(Message message) => stringToMessageEffect[effectNameOf(message)] ?? MessageEffect.none;

/// The newest message in [messages] that was sent with a **screen** effect,
/// regardless of whether that effect has already been played.
///
/// Bubble effects are deliberately not considered here: they animate their own
/// bubble, so every unplayed one plays independently (see `BubbleEffects`).
/// Screen effects take over the whole conversation, so only one can meaningfully
/// play at a time.
///
/// [messages] may be in any order — it is scanned rather than assumed sorted,
/// so it is safe to pass a chat's loaded messages straight from `ChatMessages`.
Message? newestScreenEffectMessage(Iterable<Message> messages) {
  Message? newest;
  for (final message in messages) {
    // Message.sort dereferences dateCreated, which an in-flight send may not
    // have set yet.
    if (message.dateCreated == null || !effectOf(message).isScreen) continue;
    if (newest == null || Message.sort(message, newest) < 0) newest = message;
  }
  return newest;
}

/// How recently a message must have arrived for its send effect to still be
/// worth playing.
///
/// An effect is a "look what just came in" flourish. Firing one off for a
/// message the sender sent last week isn't a celebration, it's a jump scare. It
/// also bounds the first launch after this auto-play behaviour ships, when a
/// backlog of historical effects is sitting unflagged in every chat.
const effectMaxAge = Duration(hours: 72);

/// Whether [message] arrived recently enough for its send effect to auto-play.
///
/// Invisible ink is exempt, and is filtered out by the caller rather than here:
/// it is a resting state that hides its bubble until swiped, not a one-shot
/// animation, so it renders at any age.
bool isEffectRecent(Message message, {Duration maxAge = effectMaxAge}) {
  final created = message.dateCreated;
  // Nothing to judge by (an in-flight send) — don't suppress.
  if (created == null) return true;

  // Some Macs report an incorrect dateCreated (see Message.sort, which takes the
  // *earlier* of created/delivered to keep ordering stable). This is a
  // suppression gate rather than an ordering, so it wants the opposite: take the
  // latest timestamp available, so a wrong-but-old dateCreated on a message that
  // was just delivered still counts as having arrived now.
  final delivered = message.dateDelivered;
  final arrived = (delivered != null && delivered.isAfter(created)) ? delivered : created;

  return DateTime.now().difference(arrived.toLocal()) <= maxAge;
}

/// The one message whose screen effect should auto-play for [messages], or
/// `null` when there is nothing to play.
///
/// Only the *newest* screen-effect message is ever a candidate, and it is the
/// only one that ever gets flagged as played. That single flag is what stops the
/// whole chat's history from replaying: an older screen effect can never become
/// the newest one again, so a chat whose newest one has been played stays quiet
/// no matter how many unplayed ones sit behind it. It also means a message that
/// arrives while the chat is closed (or backgrounded) still plays the next time
/// the chat is opened or resumed, because nothing marked it played — as long as
/// that is within [maxAge].
Message? pendingScreenEffectMessage(Iterable<Message> messages, {Duration maxAge = effectMaxAge}) {
  final newest = newestScreenEffectMessage(messages);
  if (newest == null || newest.hasEffectPlayed) return null;
  // Stale. Deliberately not flagged played: it only gets older, so it will keep
  // failing this check on its own, and leaving the flag alone keeps it meaning
  // "was played" rather than "was considered".
  if (!isEffectRecent(newest, maxAge: maxAge)) return null;
  return newest;
}
