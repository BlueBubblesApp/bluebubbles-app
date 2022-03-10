import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/material.dart';

class MessageTimeStamp extends StatelessWidget {
  const MessageTimeStamp({Key? key, required this.message, this.singleLine = false, this.useYesterday = false, this.shownByTap = false})
      : super(key: key);
  final Message message;
  final bool singleLine;
  final bool useYesterday;
  final bool shownByTap;

  @override
  Widget build(BuildContext context) {
    if (ChatManager().activeChat == null) return Container();

    return StreamBuilder<double>(
        stream: ChatManager().activeChat?.timeStampOffsetStream.stream,
        builder: (context, snapshot) {
          double offset = ChatManager().activeChat?.timeStampOffset ?? 0;
          String text = buildTime(message.dateCreated).toLowerCase();
          if (!message.dateCreated!.isToday()) {
            String formatted = buildDate(message.dateCreated);
            text = "$formatted${singleLine ? " " : "\n"}$text";
          }

          return AnimatedContainer(
            duration: Duration(milliseconds: offset == 0 ? 150 : 0),
            width: (!shownByTap &&
                (SettingsManager().settings.skin.value == Skins.iOS ||
                    SettingsManager().settings.skin.value == Skins.Material))
                ? (-offset).clamp(0, 70).toDouble()
                : (singleLine)
                    ? 100
                    : 70,
            height: (!message.dateCreated!.isToday() && !singleLine) ? 24 : 12,
            child: Stack(
              alignment: message.isFromMe! ? Alignment.bottomRight : Alignment.bottomLeft,
              children: [
                AnimatedPositioned(
                  // width: ,
                  width: (singleLine) ? 100 : 70,
                  left: (offset).clamp(0, 70).toDouble(),
                  duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                  child: Text(
                    text,
                    textAlign: (message.isFromMe! && SettingsManager().settings.skin.value == Skins.Samsung)
                        ? TextAlign.right
                        : TextAlign.left,
                    style: Theme.of(context).textTheme.subtitle1!.apply(fontSizeFactor: 0.8),
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
