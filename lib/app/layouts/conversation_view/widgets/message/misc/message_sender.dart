import 'dart:ui';

import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MessageSender extends StatelessWidget {
  const MessageSender({super.key, required this.olderMessage});

  final Message? olderMessage;

  @override
  Widget build(BuildContext context) {
    final state = MessageStateScope.maybeOf(context);
    if (state == null) return const SizedBox.shrink();
    final chatState = ChatStateScope.maybeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25).add(const EdgeInsets.only(bottom: 3)),
      // Obx makes the sender name reactive: updates when contact data syncs.
      child: Obx(() {
        final hasCustomBackground = chatState?.hasCustomWallpaper ?? false;
        final text = Text(
          state.senderDisplayName,
          style: context.theme.textTheme.labelMedium!.copyWith(
            color: hasCustomBackground ? context.theme.colorScheme.onSurface : context.theme.colorScheme.outline,
            fontWeight: FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        if (!hasCustomBackground) return text;
        return Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1.0,
          child: IntrinsicWidth(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: context.theme.colorScheme.surface.withValues(alpha: 0.5),
                  child: text,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
