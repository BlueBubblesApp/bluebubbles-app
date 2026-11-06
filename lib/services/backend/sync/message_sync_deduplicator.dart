import 'dart:convert';

import 'package:collection/collection.dart';

/// Keeps overlapping sync pages from writing the same message snapshot twice.
/// A changed snapshot must still be applied, even when its GUID was already seen.
class MessageSyncDeduplicator {
  final _snapshots = <(String, String), Map<String, dynamic>>{};
  static const _equality = DeepCollectionEquality();

  bool shouldSync(String chatGuid, Map<String, dynamic> message) {
    final guid = message['guid'] as String?;
    if (guid == null) return true;
    final key = (chatGuid, guid);
    if (_equality.equals(_snapshots[key], message)) return false;
    // Model parsing normalizes some nested API maps in place. Keep the wire
    // snapshot separate so those changes cannot defeat later comparisons.
    _snapshots[key] = jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
    return true;
  }

  void clear() => _snapshots.clear();
}
