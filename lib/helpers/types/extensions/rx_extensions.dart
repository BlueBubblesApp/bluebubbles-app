import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:get/get.dart';

/// this extensions allows us to update an RxMap without re-rendering UI
/// (to avoid getting the markNeedsBuild exception)
extension ConditionlAdd on RxMap {
  void conditionalAdd(Object? key, Object? value, bool shouldRefresh) {
    // ignore this warning, for some reason value is a protected member
    // ignore: invalid_use_of_protected_member
    this.value[key] = value;
    if (shouldRefresh) refresh();
  }
}

extension ChatListHelpers on RxList<Chat> {
  /// Helper to return archived chats or all chats depending on the bool passed to it
  /// This helps reduce a vast amount of code in build methods so the widgets can
  /// update without StreamBuilders
  RxList<Chat> archivedHelper(bool archived) {
    if (archived) {
      return where((e) => e.isArchived ?? false).toList().obs;
    } else {
      return where((e) => !(e.isArchived ?? false)).toList().obs;
    }
  }

  RxList<Chat> bigPinHelper(bool pinned) {
    if (pinned) {
      return where((e) => e.isPinned ?? false).toList().obs;
    } else {
      return where((e) => !(e.isPinned ?? false)).toList().obs;
    }
  }

  RxList<Chat> unknownSendersHelper(bool unknown) {
    if (!ss.settings.filterUnknownSenders.value) return this;
    if (unknown) {
      return where((e) => !e.isGroup && e.participants.firstOrNull?.contact == null).toList().obs;
    } else {
      return where((e) => e.isGroup || (!e.isGroup && e.participants.firstOrNull?.contact != null)).toList().obs;
    }
  }
}