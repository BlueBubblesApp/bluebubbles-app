import 'package:flutter/widgets.dart';

/// Marks a subtree as a **decorative clone** of a message bubble rather than
/// the live one in the list.
///
/// `MessagePopup` re-renders the bubble it was opened from, against the same
/// `MessageState`, so for as long as the popup is open there are two complete
/// copies of every widget in that message — each with its own state, its own
/// controllers, and its own listeners on the shared observables.
///
/// That is harmless for anything that only draws. It is not harmless for
/// anything that reacts to a signal by *doing work*: both copies see the
/// signal, so the work runs twice. `previewRefreshKey` is the case that bit —
/// "Refresh Preview" is dispatched before the popup closes, so the clone's
/// listener fires alongside the real one.
///
/// Widgets that kick off work from a listener should check this and skip
/// registering it. Note the clone still needs its *initial* load, or the popup
/// would show an empty card; in the normal case that resolves from the disk
/// cache without touching the network.
class MessageCloneScope extends InheritedWidget {
  const MessageCloneScope({super.key, required super.child});

  /// Whether [context] sits inside a decorative clone.
  ///
  /// Uses `getInheritedWidgetOfExactType` rather than `dependOnInherited...`
  /// so it is legal to call from `initState`, which is where the widgets that
  /// care about this decide whether to subscribe. Nothing here ever changes for
  /// a given subtree, so there is no dependency worth registering.
  static bool of(BuildContext context) => context.getInheritedWidgetOfExactType<MessageCloneScope>() != null;

  @override
  bool updateShouldNotify(MessageCloneScope oldWidget) => false;
}
