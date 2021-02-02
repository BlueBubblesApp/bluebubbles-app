import 'package:bluebubbles/helpers/contstants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageTimeStamp extends StatelessWidget {
  const MessageTimeStamp({Key key, this.message}) : super(key: key);
  final Message message;

  @override
  Widget build(BuildContext context) {
    if (context == null || CurrentChat.of(context) == null) return Container();

    return StreamBuilder<double>(
        stream: CurrentChat.of(context)?.timeStampOffsetStream?.stream,
        builder: (context, snapshot) {
          double offset = CurrentChat.of(context)?.timeStampOffset;

          String text =
              DateFormat('h:mm a').format(message.dateCreated).toLowerCase();
          if (message.dateCreated.isYesterday()) {
            text = "Yesterday\n$text";
          } else if (!message.dateCreated.isToday()) {
            text =
                "${message.dateCreated.month.toString()}/${message.dateCreated.day.toString()}/${message.dateCreated.year.toString()}\n$text";
          }

          return AnimatedContainer(
            duration: Duration(milliseconds: offset == 0 ? 150 : 0),
            width: (SettingsManager().settings.skin == Skins.IOS ||
                    SettingsManager().settings.skin == Skins.Material)
                ? (-offset).clamp(0, 70).toDouble()
                : 60,
            height: 30,
            child: Stack(
              children: [
                AnimatedPositioned(
                  // width: ,
                  width: 70,
                  left: (offset).clamp(0, 70).toDouble(),
                  duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                  child: Text(
                    text,
                    textAlign: TextAlign.right,
                    style: Theme.of(context)
                        .textTheme
                        .subtitle1
                        .apply(fontSizeDelta: 0.09),
                    overflow: TextOverflow.visible,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          );
        });
  }
}
