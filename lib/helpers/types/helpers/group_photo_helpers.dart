/// Telling a group photo that was resent from one that changed.
///
/// chat.db records a group's current photo as a message with `itemType` 3 and `groupActionType` 3: no sender, no
/// text, and the photo as its attachment. Messages writes that row again, under the GUID it already has and dated
/// now, when it resends the group's photo, which can happen on any send into the group. So the same photo arrives
/// as a "new" message long after it was set, and the transcript would show it again for a photo that never changed.
///
/// The photo itself has an identity: the attachment GUID of that row, which is also the `groupPhotoGuid` in the
/// chat's `properties`. A real change brings a different one. [Chat.knownGroupPhotoGuid] remembers the last one this
/// app showed an event for, and a 3/3 row whose photo is that one is dropped.
library;

/// The `groupPhotoGuid` in a chat's `properties` as the server sends it: chat.db's property list decoded, which is a
/// list of dictionaries (or, from some servers, one dictionary). The last non-empty value wins.
String? groupPhotoGuidInProperties(dynamic properties) {
  final entries = properties is List ? properties : (properties is Map ? [properties] : const []);
  String? found;
  for (final entry in entries) {
    if (entry is! Map) continue;
    final value = entry['groupPhotoGuid'];
    if (value is String && value.isNotEmpty) found = value;
  }
  return found;
}

/// The photo a group-photo message carries: its own attachment when the payload has one, otherwise what the chat
/// names. The attachment comes first because it is the row's own: the chat's `properties` can lag a change.
String? groupPhotoGuidFor({Iterable<String?> attachmentGuids = const [], String? chatGroupPhotoGuid}) {
  for (final guid in attachmentGuids) {
    if (guid != null && guid.isNotEmpty) return guid;
  }
  return chatGroupPhotoGuid;
}

/// Whether a group-photo state row (3/3) carrying [photoGuid] repeats the photo this app already showed. Unknown on
/// either side means it cannot be told apart, and it is kept.
bool isKnownGroupPhoto(String? photoGuid, String? knownGroupPhotoGuid) =>
    photoGuid != null && knownGroupPhotoGuid != null && photoGuid == knownGroupPhotoGuid;

/// Whether a raw server message map is the group's photo as state (3/3).
bool isGroupPhotoStateMap(Map<String, dynamic> message) => message['itemType'] == 3 && message['groupActionType'] == 3;

/// Whether a raw server message map records a person changing the group photo (3/1).
bool isGroupPhotoChangeMap(Map<String, dynamic> message) => message['itemType'] == 3 && message['groupActionType'] == 1;

/// The photo a raw server message map carries, by [groupPhotoGuidFor].
String? groupPhotoGuidOfMap(Map<String, dynamic> message) {
  final attachments = (message['attachments'] as List? ?? const []).whereType<Map>().map((a) => a['guid'] as String?);
  final chats = (message['chats'] as List? ?? const []).whereType<Map>();
  return groupPhotoGuidFor(
    attachmentGuids: attachments,
    chatGroupPhotoGuid: chats.isEmpty ? null : groupPhotoGuidInProperties(chats.first['properties']),
  );
}

/// One chat's batch of raw server messages, without the 3/3 rows that repeat a photo already shown.
///
/// Walked oldest first, so a photo change (3/1) or a new photo earlier in the batch becomes the known one for the
/// rows after it. Returns the messages that remain, in their original order, and the photo now known.
({List<Map<String, dynamic>> kept, String? known}) dropKnownGroupPhotoResends(
  List<Map<String, dynamic>> messages,
  String? known,
) {
  int dateOf(Map<String, dynamic> m) => (m['dateCreated'] as num?)?.toInt() ?? 0;
  final order = List<int>.generate(messages.length, (i) => i)
    ..sort((a, b) => dateOf(messages[a]).compareTo(dateOf(messages[b])));

  final dropped = <int>{};
  for (final i in order) {
    final message = messages[i];
    final isState = isGroupPhotoStateMap(message);
    if (!isState && !isGroupPhotoChangeMap(message)) continue;
    final photo = groupPhotoGuidOfMap(message);
    if (isState && isKnownGroupPhoto(photo, known)) {
      dropped.add(i);
      continue;
    }
    known = photo ?? known;
  }

  return (
    kept: [
      for (var i = 0; i < messages.length; i++)
        if (!dropped.contains(i)) messages[i],
    ],
    known: known,
  );
}
