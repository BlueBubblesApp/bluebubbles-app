import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:get/get.dart';

/// Shared initialization and helper logic for all three conversation-list
/// trailing widgets (Cupertino, Material, Samsung).
///
/// Apply with `with TrailingStateMixin<W>` on the State class, e.g.:
/// ```dart
/// class _CupertinoTrailingState
///     extends CustomState<CupertinoTrailing, void, ConversationTileController>
///     with TrailingStateMixin<CupertinoTrailing> { … }
/// ```
mixin TrailingStateMixin<W extends CustomStateful<ConversationTileController>>
    on CustomState<W, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  /// Compute the status indicator text for a given [status] enum value.
  ///
  /// Must be called **inside an `Obx()`** — it reads
  /// [SettingsSvc.settings.statusIndicatorsOnChats], registering a GetX
  /// dependency so the enclosing `Obx` rebuilds when the setting changes.
  /// Pass [ChatState.latestMessageStatus.value] as [status] so that delivery
  /// and read-receipt updates also trigger a rebuild.
  ///
  /// Returns an empty string when no indicator should be shown.
  String computeIndicatorText(MessageStatusIndicator status, bool isGroup) {
    if (!SettingsSvc.settings.statusIndicatorsOnChats.value) return "";
    if (isGroup || status == MessageStatusIndicator.NONE) return "";
    return status.name.toLowerCase().capitalizeFirst!;
  }
}
