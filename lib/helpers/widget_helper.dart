import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WidgetHelper {
  static List<InlineSpan> buildMessageSpans(
      BuildContext context, Message message) {
    List<InlineSpan> textSpans = <InlineSpan>[];

    if (message != null && !isEmptyString(message.text)) {
      RegExp exp = new RegExp(
          r'((https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9\/()@:%_.~#?&=\*\[\]]{0,})\b');
      List<RegExpMatch> matches = exp.allMatches(message.text).toList();

      List<int> linkIndexMatches = <int>[];
      matches.forEach((match) {
        linkIndexMatches.add(match.start);
        linkIndexMatches.add(match.end);
      });
      if (linkIndexMatches.length > 0) {
        for (int i = 0; i < linkIndexMatches.length + 1; i++) {
          if (i == 0) {
            textSpans.add(
              TextSpan(text: message.text.substring(0, linkIndexMatches[i])),
            );
          } else if (i == linkIndexMatches.length && i - 1 >= 0) {
            textSpans.add(
              TextSpan(
                text: message.text
                    .substring(linkIndexMatches[i - 1], message.text.length),
              ),
            );
          } else if (i - 1 >= 0) {
            String text = message.text
                .substring(linkIndexMatches[i - 1], linkIndexMatches[i]);
            if (exp.hasMatch(text)) {
              textSpans.add(
                TextSpan(
                  text: text,
                  recognizer: new TapGestureRecognizer()
                    ..onTap = () async {
                      String url = text;
                      if (!url.startsWith("http://") &&
                          !url.startsWith("https://")) {
                        url = "http://" + url;
                      }
                      debugPrint(
                          "open url " + text.startsWith("http://").toString());
                      MethodChannelInterface()
                          .invokeMethod("open-link", {"link": url});
                    },
                  style: Theme.of(context).textTheme.bodyText1.apply(
                        decoration: TextDecoration.underline,
                      ),
                ),
              );
            } else {
              textSpans.add(
                TextSpan(
                  text: text,
                ),
              );
            }
          }
        }
      } else {
        textSpans.add(
          TextSpan(
            text: message.text,
          ),
        );
      }
    }

    return textSpans;
  }

  static AnimatedContainer buildMessageTimestamp(
      BuildContext context, Message message, double offset) {
    return AnimatedContainer(
      width: (-offset).clamp(0, 70).toDouble(),
      duration: Duration(milliseconds: offset == 0 ? 150 : 0),
      child: Text(
        DateFormat('h:mm a').format(message.dateCreated).toLowerCase(),
        style: Theme.of(context).textTheme.subtitle1,
        overflow: TextOverflow.clip,
        maxLines: 1,
      ),
    );
  }
}
