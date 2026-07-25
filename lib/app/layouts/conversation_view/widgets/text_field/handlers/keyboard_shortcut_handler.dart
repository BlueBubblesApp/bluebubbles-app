import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handles keyboard shortcuts for the text field:
/// - Enter/Return: send message
/// - Up arrow: edit last sent message (if text field empty)
/// - Tab: switch between subject and message text fields
/// - Escape: clear various states (shown via handlers)
class KeyboardShortcutHandler {
  final ConversationViewController controller;
  final Future<void> Function({String? effect}) sendMessage;
  final TextEditingController subjectTextController;
  final TextEditingController messageTextController;
  final bool isChatCreator;

  KeyboardShortcutHandler({
    required this.controller,
    required this.sendMessage,
    required this.subjectTextController,
    required this.messageTextController,
    required this.isChatCreator,
  });

  /// Handle general keyboard shortcuts (non-autocomplete).
  /// Returns a [KeyEventResult] indicating whether the event was handled.
  KeyEventResult handleKeyEvent(KeyEvent ev) {
    if (ev is! KeyDownEvent) return KeyEventResult.ignored;

    // Chat creator: Enter sends message
    if (isChatCreator) {
      if ((kIsDesktop || kIsWeb) &&
          ev.logicalKey == LogicalKeyboardKey.enter &&
          !HardwareKeyboard.instance.isShiftPressed) {
        sendMessage();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Regular conversation: Up arrow edits last sent message (if empty)
    if (ev.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (messageTextController.text.isEmpty &&
          SettingsSvc.settings.editLastSentMessageOnUpArrow.value &&
          BackendSvc.canEditUnsend) {
        final chat = controller.chat;
        final service = maybeFindMessagesSvc(chat.guid);
        final message = service?.mostRecentSent;
        if (message != null) {
          final messageController = service!.getOrCreateState(message);
          final isSending = messageController.isSending.value;
          if (!isSending) {
            final parts = messageController.parts;
            final part = parts.where((p) => p.text?.isNotEmpty ?? false).lastOrNull;
            if (part != null) {
              final FocusNode? node = kIsDesktop || kIsWeb ? FocusNode() : null;
              controller.editing.add(MessageEditEntry(
                message: message,
                part: part,
                controller: SpellCheckTextEditingController(text: part.text!, focusNode: node),
              ));
              node?.requestFocus();
              return KeyEventResult.handled;
            }
          }
        }
      }
    }

    // Tab: Switch between subject and message text fields (if subject enabled)
    if (ev.logicalKey == LogicalKeyboardKey.tab && SettingsSvc.settings.privateSubjectLine.value) {
      if (!HardwareKeyboard.instance.isShiftPressed && controller.subjectFocusNode.hasPrimaryFocus) {
        controller.focusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (HardwareKeyboard.instance.isShiftPressed && controller.focusNode.hasPrimaryFocus) {
        controller.subjectFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    // Desktop/Web: Enter (without modifier) sends message
    if ((kIsDesktop || kIsWeb) &&
        ev.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      sendMessage();
      controller.focusNode.requestFocus();
      return KeyEventResult.handled;
    }

    // Mobile: Physical Enter key with sendWithReturn setting
    if (kIsDesktop || kIsWeb) return KeyEventResult.ignored;
    if (ev.physicalKey == PhysicalKeyboardKey.enter && SettingsSvc.settings.sendWithReturn.value) {
      if (!isNullOrEmpty(messageTextController.text) || !isNullOrEmpty(controller.subjectTextController.text)) {
        sendMessage();
        controller.focusNode.previousFocus();
        return KeyEventResult.handled;
      } else {
        controller.subjectTextController.text = "";
        messageTextController.text = "";
        controller.focusNode.previousFocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}
