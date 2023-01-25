import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class TimestampSeparator extends StatelessWidget {
  const TimestampSeparator({
    Key? key,
    required this.olderMessage,
    required this.message,
  }) : super(key: key);
  final Message? olderMessage;
  final Message message;

  bool withinTimeThreshold(Message first, Message? second) {
    if (second == null) return false;
    return second.dateCreated!.difference(first.dateCreated!).inMinutes.abs() > 30;
  }

  Tuple2<String?, String>? buildTimeStamp() {
    if (ss.settings.skin.value == Skins.Samsung && (olderMessage?.dateCreated?.isTomorrow(otherDate: message.dateCreated) ?? false)) {
      return Tuple2(null, buildSeparatorDateSamsung(message.dateCreated!));
    } else if (ss.settings.skin.value != Skins.Samsung && withinTimeThreshold(message, olderMessage)) {
      final time = message.dateCreated!;
      if (ss.settings.skin.value == Skins.iOS) {
        return Tuple2(time.isToday() ? "Today" : buildDate(time), buildTime(time));
      } else {
        return Tuple2(time.isToday() ? "Today" : buildSeparatorDateMaterial(time), buildTime(time));
      }
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = buildTimeStamp();

    return timestamp != null ? Padding(
      padding: const EdgeInsets.all(14.0),
      child: RichText(
        text: TextSpan(
          style: context.theme.textTheme.labelSmall!.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.normal),
          children: [
            if (timestamp.item1 != null)
              TextSpan(
                text: "${timestamp.item1!} ",
                style: context.theme.textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: context.theme.colorScheme.outline),
              ),
            TextSpan(text: timestamp.item2)
          ],
        ),
      ),
    ) : const SizedBox.shrink();
  }
}
