import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageTimeStampSeparator extends StatelessWidget {
  const MessageTimeStampSeparator({
    Key key,
    @required this.newerMessage,
    @required this.message,
  }) : super(key: key);
  final Message newerMessage;
  final Message message;

  bool withinTimeThreshold(Message first, Message second, {threshold: 5}) {
    if (first == null || second == null) return false;
    return second.dateCreated.difference(first.dateCreated).inMinutes.abs() > threshold;
  }

  Map<String, String> _buildTimeStamp() {
    if (newerMessage != null &&
        (!isEmptyString(message.fullText) || message.hasAttachments) &&
        withinTimeThreshold(message, newerMessage, threshold: 30)) {
      DateTime timeOfnewerMessage = newerMessage.dateCreated;
      String time = new DateFormat.jm().format(timeOfnewerMessage);
      String date;
      if (newerMessage.dateCreated.isToday()) {
        date = "Today";
      } else if (newerMessage.dateCreated.isYesterday()) {
        date = "Yesterday";
      } else {
        date =
            "${timeOfnewerMessage.month.toString()}/${timeOfnewerMessage.day.toString()}/${timeOfnewerMessage.year.toString()}";
      }
      return {"date": date, "time": time};
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, String> timeStamp = _buildTimeStamp();

    return timeStamp != null
        ? Padding(
            padding: const EdgeInsets.all(14.0),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.subtitle2,
                children: [
                  TextSpan(
                    text: "${timeStamp["date"]}, ",
                    style: Theme.of(context).textTheme.subtitle2.apply(fontWeightDelta: 10),
                  ),
                  TextSpan(text: "${timeStamp["time"]}")
                ],
              ),
            ),
          )
        : Container();
  }
}
