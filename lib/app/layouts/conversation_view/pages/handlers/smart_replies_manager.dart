import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart' hide Message;

/// Manages smart reply generation via ML Kit.
///
/// Responsibilities:
/// - Initialize ML Kit smart reply processor on startup
/// - Add incoming messages to conversation context
/// - Generate reply suggestions when new messages arrive
/// - Clear suggestions when user sends a message
/// - Refresh suggestions when non-user messages arrive
class SmartRepliesManager {
  /// Rolling context window size. ML Kit's own conversation list has no cap, so this
  /// class enforces one to keep suggestions scoped to recent context and to bound
  /// memory growth for chats that stay mounted for a long time (desktop, tablet split-view).
  static const int _maxContextMessages = 5;

  late final SmartReply smartReply;

  final RxList<String> smartReplies = <String>[].obs;

  final List<Message> _context = [];

  SmartRepliesManager() {
    smartReply = SmartReply();
  }

  bool shouldShowSmartReplies(bool messagesEmpty) {
    return !messagesEmpty && smartReplies.isNotEmpty;
  }

  void addMessageToContext(Message message) {
    _context.add(message);
    if (_context.length > _maxContextMessages) {
      _context.removeRange(0, _context.length - _maxContextMessages);
    }
    _rebuildConversation();
  }

  void _rebuildConversation() {
    smartReply.clearConversation();
    for (final message in _context) {
      final text = sanitizeForMlKit(message.fullText);
      if (message.isFromMe ?? false) {
        smartReply.addMessageToConversationFromLocalUser(
          text,
          message.dateCreated!.millisecondsSinceEpoch,
        );
      } else {
        smartReply.addMessageToConversationFromRemoteUser(
          text,
          message.dateCreated!.millisecondsSinceEpoch,
          message.handleRelation.target?.address ?? "participant",
        );
      }
    }
  }

  /// Generate smart reply suggestions based on current conversation context.
  /// Call this after adding messages or when new context arrives.
  Future<void> generateSuggestions() async {
    try {
      SmartReplySuggestionResult results = await smartReply.suggestReplies();

      if (results.status == SmartReplySuggestionResultStatus.success) {
        smartReplies.value = results.suggestions;
      } else {
        smartReplies.clear();
      }
    } catch (e) {
      // Silently fail if ML Kit is unavailable
    }
  }

  /// Clean up resources (close ML Kit processor).
  void dispose() {
    if (!kIsWeb && !kIsDesktop) {
      smartReply.close();
    }
  }
}
