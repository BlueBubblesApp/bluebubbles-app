import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class _TimestampParts {
  final String? date;
  final String time;
  const _TimestampParts({this.date, required this.time});
}

class TimestampSeparator extends StatelessWidget {
  const TimestampSeparator({
    super.key,
    required this.olderMessage,
  });
  final Message? olderMessage;

  bool withinTimeThreshold(Message first, Message? second) {
    if (second == null) return false;
    return second.dateCreated!.difference(first.dateCreated!).inMinutes.abs() > 30;
  }

  _TimestampParts? buildTimeStamp(Message message) {
    if (SettingsSvc.settings.skin.value == Skins.Samsung &&
        message.dateCreated?.day != olderMessage?.dateCreated?.day) {
      return _TimestampParts(time: buildSeparatorDateSamsung(message.dateCreated!));
    } else if (SettingsSvc.settings.skin.value != Skins.Samsung && withinTimeThreshold(message, olderMessage)) {
      final time = message.dateCreated!;
      if (SettingsSvc.settings.skin.value == Skins.iOS) {
        return _TimestampParts(date: time.isToday() ? "Today" : buildDate(time), time: buildTime(time));
      } else {
        return _TimestampParts(
            date: time.isToday() ? "Today" : buildSeparatorDateMaterial(time), time: buildTime(time));
      }
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = MessageStateScope.messageOf(context);
    final timestamp = buildTimeStamp(message);
    final hasBackground = ChatStateScope.maybeOf(context)?.hasCustomWallpaper ?? false;

    if (timestamp == null) return const SizedBox.shrink();

    final textColor = hasBackground ? context.theme.colorScheme.onSurfaceVariant : context.theme.colorScheme.outline;

    final richText = RichText(
      text: TextSpan(
        style: context.theme.textTheme.labelSmall!.copyWith(color: textColor, fontWeight: FontWeight.normal),
        children: [
          if (timestamp.date != null)
            TextSpan(
              text: "${timestamp.date!} ",
              style: context.theme.textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: textColor),
            ),
          TextSpan(text: timestamp.time),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: hasBackground
          ? Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: richText,
              ),
            )
          : richText,
    );
  }
}
