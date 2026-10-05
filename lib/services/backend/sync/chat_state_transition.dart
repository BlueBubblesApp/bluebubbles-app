class ChatStateTransition {
  const ChatStateTransition({required this.deletedGuids, required this.nextNonEmptyGuids});

  final Set<String> deletedGuids;
  final Set<String> nextNonEmptyGuids;
}

/// Computes forward-only whole-thread deletion transitions.
///
/// The first complete snapshot seeds the baseline without deleting anything.
/// After that, only a chat previously observed with messages can be considered
/// deleted when it reaches zero messages or disappears from a complete snapshot.
ChatStateTransition computeChatStateTransition({
  required bool initialized,
  required Set<String> previouslyNonEmptyGuids,
  required Map<String, int> currentMessageCounts,
}) {
  final nextNonEmptyGuids = currentMessageCounts.entries
      .where((entry) => entry.value > 0)
      .map((entry) => entry.key)
      .toSet();

  if (!initialized) {
    return ChatStateTransition(deletedGuids: const {}, nextNonEmptyGuids: nextNonEmptyGuids);
  }

  final deletedGuids = previouslyNonEmptyGuids.where((guid) => !nextNonEmptyGuids.contains(guid)).toSet();
  return ChatStateTransition(deletedGuids: deletedGuids, nextNonEmptyGuids: nextNonEmptyGuids);
}
