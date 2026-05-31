import 'dart:async';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

// ignore: non_constant_identifier_names
ClipboardSyncService get ClipboardSyncSvc => Get.isRegistered<ClipboardSyncService>()
    ? Get.find<ClipboardSyncService>()
    : Get.put(ClipboardSyncService());

/// Syncs the system clipboard across all connected devices via the BB server.
///
/// The Mac server is the hub: it polls its own clipboard (which picks up iPhone
/// changes via Apple Universal Clipboard) and broadcasts the clipboard-sync
/// socket event to all clients. Clients write the incoming content locally and,
/// on platforms where clipboard reading is unrestricted, also send their own
/// changes back to the server.
///
/// iOS receives only — Universal Clipboard handles the iPhone→Mac direction.
class ClipboardSyncService extends GetxService {
  static const String _tag = "ClipboardSyncService";
  static const Duration _pollInterval = Duration(milliseconds: 1000);

  Timer? _pollTimer;
  String _lastKnown = "";
  // Tracks what we last wrote so we don't echo it back to the server.
  String _lastWritten = "";

  // iOS cannot silently poll the clipboard (shows a system banner), so we only
  // receive on iOS. All other platforms send + receive.
  bool get _canSend => !kIsWeb && !(Platform.isIOS);

  void start() {
    if (!ss.settings.enableClipboardSync.value) return;
    if (_pollTimer != null) return;
    if (!_canSend) return;

    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    Logger.info("Clipboard sync started", tag: _tag);
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Called by the action handler when the server broadcasts a clipboard change.
  Future<void> handleIncoming(Map<String, dynamic> data) async {
    final content = data['content'];
    if (content == null || content is! String || content.isEmpty) return;
    if (content == _lastKnown) return;

    _lastWritten = content;
    _lastKnown = content;
    await Clipboard.setData(ClipboardData(text: content));
    Logger.info("Clipboard updated from remote", tag: _tag);
  }

  Future<void> _poll() async {
    if (!ss.settings.enableClipboardSync.value) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final current = data?.text ?? "";
      if (current.isEmpty || current == _lastKnown) return;
      _lastKnown = current;
      if (current == _lastWritten) return;

      socket.socket.emit("clipboard-sync", {"content": current});
      Logger.info("Clipboard sent to server", tag: _tag);
    } catch (e) {
      Logger.warn("Clipboard poll failed: $e", tag: _tag);
    }
  }
}
