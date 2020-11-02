import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// Mixin just for commonly shared functions and properties between the SentMessage and ReceivedMessage
abstract class MessageWidgetMixin {
  Contact contact;
  String contactTitle = "";
  MemoryImage contactImage;
  bool hasHyperlinks = false;
  static const double maxSize = 3 / 5;

  Future<void> initMessageState(Message message, bool showHandle) async {
    this.hasHyperlinks = parseLinks(message.text).isNotEmpty;
    await getContactTitle(message, showHandle);
  }

  Future<void> getContact(Message message) async {
    Contact contact =
        await ContactManager().getCachedContact(message.handle.address);
    if (contact != null) {
      if (this.contact == null ||
          this.contact.identifier != contact.identifier) {
        this.contact = contact;
      }
    }
  }

  Future<void> getContactTitle(Message message, bool showHandle) async {
    if (message.handle == null || !showHandle) return;

    String title =
        await ContactManager().getContactTitle(message.handle.address);

    if (title != contactTitle) {
      contactTitle = title;
    }
  }

  Future<void> fetchAvatar(Message message) async {
    MemoryImage avatar = await loadAvatar(null, message.handle.address);
    if (contactImage == null ||
        contactImage.bytes.length != avatar.bytes.length) {
      contactImage = avatar;
    }
  }

  /// Adds reacts to a [message] widget
  Widget addReactionsToWidget(
      {@required Widget message, @required Widget reactions, @required bool isFromMe}) {
    return Stack(
      alignment: isFromMe ? AlignmentDirectional.topStart : AlignmentDirectional.topEnd,
      children: [
        message,
        reactions,
      ],
    );
  }

  /// Adds reacts to a [message] widget
  Widget addStickersToWidget(
      {@required Widget message, @required Widget stickers, @required bool isFromMe}) {
    return Stack(
      alignment: (isFromMe) ? AlignmentDirectional.bottomEnd : AlignmentDirectional.bottomStart,
      children: [
        message,
        stickers,
      ],
    );
  }

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
}
