import 'dart:math';

import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Handles mention autocomplete detection, matching, and selection via keyboard shortcuts.
///
/// This handler intercepts:
/// - Down arrow: cycle through mention matches
/// - Up arrow: cycle backwards through mention matches
/// - Tab/Enter: insert selected mention at cursor position
/// - Escape: clear mention matches
/// - Custom mention dialog: initiated from context menu (see text_field_component.dart)
class MentionAutocompleteHandler {
  final ConversationViewController controller;
  final TextEditingController textField;

  MentionAutocompleteHandler({
    required this.controller,
    required this.textField,
  });

  /// Handle mention-related key events. Returns true if the event was handled.
  bool handleKeyEvent({
    required LogicalKeyboardKey logicalKey,
    required bool isEscapeKey,
    required bool isTabOrEnter,
    required bool isDownArrow,
    required bool isUpArrow,
    required int? maxShown,
    required int? upMovementIndex,
    required int? downMovementIndex,
  }) {
    // Escape key: clear mention matches
    if (isEscapeKey) {
      if (controller.mentionMatches.isNotEmpty) {
        controller.mentionMatches.value = <Mentionable>[];
        return true;
      }
    }

    // Down arrow: cycle through matches
    if (isDownArrow) {
      if (controller.mentionMatches.length > controller.mentionSelectedIndex.value) {
        controller.mentionSelectedIndex.value++;
        if (controller.mentionSelectedIndex.value >= downMovementIndex! &&
            controller.mentionSelectedIndex < controller.mentionMatches.length - maxShown! + downMovementIndex + 1) {
          controller.emojiScrollController.jumpTo(max((controller.mentionSelectedIndex.value - downMovementIndex) * 40,
              controller.emojiScrollController.offset));
        }
        return true;
      }
    }

    // Up arrow: cycle backwards through matches
    if (isUpArrow) {
      if (controller.mentionSelectedIndex.value > 0) {
        controller.mentionSelectedIndex.value--;
        if (controller.mentionSelectedIndex.value >= upMovementIndex! &&
            controller.mentionSelectedIndex < controller.mentionMatches.length - maxShown! + upMovementIndex + 1) {
          controller.emojiScrollController.jumpTo(min(
              (controller.mentionSelectedIndex.value - upMovementIndex) * 40, controller.emojiScrollController.offset));
        }
        return true;
      }
    }

    // Tab or Enter: insert mention at cursor
    if (isTabOrEnter) {
      if (controller.mentionMatches.isEmpty ||
          controller.mentionMatches.length <= controller.mentionSelectedIndex.value) {
        return false;
      }
      // A name typed without "@" only suggests: Enter still sends, Tab or a click takes the mention
      final tc = controller.textController;
      final typedAt = tc.selection.baseOffset >= 0 &&
          RegExp(r"@[^\s@]*$").hasMatch(tc.text.substring(0, tc.selection.baseOffset));
      if (logicalKey == LogicalKeyboardKey.enter && !typedAt) return false;

      if (!controller.textController.addMention(controller.mentionMatches[controller.mentionSelectedIndex.value])) {
        // If user moved cursor before inserting, reset picker
        controller.emojiScrollController.jumpTo(0);
      }

      controller.mentionSelectedIndex.value = 0;
      controller.mentionMatches.value = <Mentionable>[];

      return true;
    }

    return false;
  }
}
