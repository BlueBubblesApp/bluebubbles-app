import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MessageTimeStampSeparator extends StatelessWidget {
  const MessageTimeStampSeparator({
    Key? key,
    required this.newerMessage,
    required this.message,
  }) : super(key: key);
  final Message? newerMessage;
  final Message message;

  bool withinTimeThreshold(Message first, Message? second, {threshold = 5}) {
    if (second == null) return false;
    return second.dateCreated!.difference(first.dateCreated!).inMinutes.abs() > threshold;
  }

  Map<String, String> buildTimeStamp() {
    if (ss.settings.skin.value == Skins.Samsung
        && newerMessage != null &&
        (!isNullOrEmptyString(message.fullText) || message.hasAttachments) &&
        newerMessage!.dateCreated!.isTomorrow(otherDate: message.dateCreated)) {
        return {"time": buildSeparatorDateSamsung(newerMessage!.dateCreated!)};
    } else if (ss.settings.skin.value != Skins.Samsung
        && newerMessage != null &&
        (!isNullOrEmptyString(message.fullText) || message.hasAttachments) &&
        withinTimeThreshold(message, newerMessage, threshold: 30)) {
      DateTime timeOfnewerMessage = newerMessage!.dateCreated!;
      String time = buildTime(timeOfnewerMessage);
      String date = timeOfnewerMessage.isToday() ? "Today" : buildDate(timeOfnewerMessage);
      return {"date": date, "time": time};
    } else {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, String> timeStamp = buildTimeStamp();

    return timeStamp.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.all(14.0),
            child: RichText(
              text: TextSpan(
                style: context.theme.textTheme.labelSmall!.copyWith(color: context.theme.colorScheme.outline, fontWeight: FontWeight.normal),
                children: [
                  if (timeStamp["date"] != null)
                    TextSpan(
                      text: "${timeStamp["date"]} ",
                      style: context.theme.textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600, color: context.theme.colorScheme.outline),
                    ),
                  TextSpan(text: "${timeStamp["time"]}")
                ],
              ),
            ),
          )
        : Container();
  }
}
