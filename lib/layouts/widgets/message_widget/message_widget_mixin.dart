import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';

// Mixin just for commonly shared functions and properties between the SentMessage and ReceivedMessage
abstract class MessageWidgetMixin {
  static const double MAX_SIZE = 3 / 5;

  /// Adds reacts to a [message] widget
  static Widget addReactionsToWidget(
      {required Widget messageWidget, required Widget reactions, required Message? message, bool shouldShow = true}) {
    if (!shouldShow) return messageWidget;

    return Stack(
      alignment: message!.isFromMe! ? AlignmentDirectional.topStart : AlignmentDirectional.topEnd,
      children: [
        messageWidget,
        reactions,
      ],
    );
  }

  /// Adds reacts to a [message] widget
  static Widget addStickersToWidget({required Widget message, required Widget stickers, required bool isFromMe}) {
    return Stack(
      alignment: (isFromMe) ? AlignmentDirectional.bottomEnd : AlignmentDirectional.bottomStart,
      children: [
        message,
        stickers,
      ],
    );
  }

  static List<InlineSpan> buildMessageSpans(BuildContext context, Message? message,
      {List<Color>? colors = const [], Color? colorOverride, String? fakeSubject, String? fakeText}) {
    List<InlineSpan> textSpans = <InlineSpan>[];

    final bool generateContent =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeMessageContent.value;
    final bool hideContent = (message?.guid?.contains("theme-selector") ?? false) ||
        (SettingsManager().settings.redactedMode.value &&
            SettingsManager().settings.hideMessageContent.value &&
            !generateContent);

    TextStyle? textStyle = Theme.of(context).textTheme.bodyText2;
    if (!message!.isFromMe!) {
      if (SettingsManager().settings.colorfulBubbles.value) {
        if (!isNullOrEmpty(colors)!) {
          bool dark = colors![0].computeLuminance() < 0.179;
          if (!dark) {
            textStyle = Theme.of(context)
                .textTheme
                .bodyText2!
                .apply(color: hideContent ? Colors.transparent : colors[0].darkenAmount(0.35));
          } else {
            textStyle = Theme.of(context).textTheme.bodyText2;
            if (hideContent) textStyle = textStyle!.apply(color: Colors.transparent);
          }
        } else {
          textStyle = Theme.of(context).textTheme.bodyText2!.apply(
              color: hideContent
                  ? Colors.transparent
                  : toColorGradient(message.handle?.address ?? "")[0].darkenAmount(0.35));
        }
      } else if (hideContent) {
        textStyle = textStyle!.apply(color: Colors.transparent);
      }
    } else {
      textStyle = textStyle!.apply(
          color: hideContent
              ? Colors.transparent
              : Theme.of(context).primaryColor.computeLuminance() > 0.8
                  ? Colors.black
                  : Colors.white);
    }
    if (colorOverride != null && !hideContent) textStyle = textStyle!.apply(color: colorOverride);
    if ((!isEmptyString(message.text) || !isEmptyString(message.subject))) {
      RegExp exp = RegExp(
          r'((https?://)|(www\.))[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9/()@:%_.~#?&=*\[\]]*)\b');
      List<RegExpMatch> matches = exp.allMatches(message.text!).toList();

      List<int> linkIndexMatches = <int>[];
      for (RegExpMatch match in matches) {
        linkIndexMatches.add(match.start);
        linkIndexMatches.add(match.end);
      }
      if (!isNullOrEmpty(message.subject)!) {
        TextStyle _textStyle = message.isFromMe!
            ? textStyle!.apply(color: Colors.white, fontWeightDelta: 2)
            : textStyle!.apply(fontWeightDelta: 2);
        if (hideContent) {
          _textStyle = _textStyle.apply(color: Colors.transparent);
        }
        if (colorOverride != null && !hideContent) _textStyle = _textStyle.apply(color: colorOverride);
        textSpans.addAll(MessageHelper.buildEmojiText(
          "${message.subject}\n",
          _textStyle,
        ));
      }

      if (linkIndexMatches.isNotEmpty) {
        for (int i = 0; i < linkIndexMatches.length + 1; i++) {
          if (i == 0) {
            textSpans.addAll(MessageHelper.buildEmojiText(
              message.text!.substring(0, linkIndexMatches[i]),
              textStyle!,
            ));
          } else if (i == linkIndexMatches.length && i - 1 >= 0) {
            textSpans.addAll(MessageHelper.buildEmojiText(
              message.text!.substring(linkIndexMatches[i - 1], message.text!.length),
              textStyle!,
            ));
          } else if (i - 1 >= 0) {
            String text = message.text!.substring(linkIndexMatches[i - 1], linkIndexMatches[i]);
            if (exp.hasMatch(text)) {
              textSpans.add(
                TextSpan(
                  text: text,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      String url = text;
                      if (!url.startsWith("http://") && !url.startsWith("https://")) {
                        url = "http://" + url;
                      }

                      await launch(url);
                    },
                  style: textStyle!.apply(decoration: TextDecoration.underline),
                ),
              );
            } else {
              textSpans.addAll(MessageHelper.buildEmojiText(
                text,
                textStyle!,
              ));
            }
          }
        }
      } else {
        textSpans.addAll(MessageHelper.buildEmojiText(
          message.text!,
          textStyle!,
        ));
      }

      if (generateContent) {
        String generatedSubject = fakeSubject ?? faker.lorem.words(message.subject?.split(" ").length ?? 0).join(" ");
        String generatedText = fakeText ?? faker.lorem.words(message.text?.split(" ").length ?? 0).join(" ");
        return [
          if (message.subject != null)
            TextSpan(
                text: "$generatedSubject\n",
                style: message.isFromMe!
                    ? textStyle!.apply(color: Colors.white, fontWeightDelta: 2)
                    : textStyle!.apply(fontWeightDelta: 2)),
          TextSpan(text: generatedText, style: textStyle),
        ];
      }
    } else {
      textSpans.addAll(MessageHelper.buildEmojiText(
        MessageHelper.getNotificationText(message),
        textStyle!,
      ));
    }

    return textSpans;
  }

  static Future<List<InlineSpan>> buildMessageSpansAsync(BuildContext context, Message? message,
      {List<Color>? colors = const [], Color? colorOverride, String? fakeSubject, String? fakeText}) async {
    List<InlineSpan> textSpans = <InlineSpan>[];

    final bool generateContent =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeMessageContent.value;
    final bool hideContent = (message?.guid?.contains("theme-selector") ?? false) ||
        (SettingsManager().settings.redactedMode.value &&
            SettingsManager().settings.hideMessageContent.value &&
            !generateContent);

    TextStyle? textStyle = Theme.of(context).textTheme.bodyText2;
    if (message == null) return [];
    if (!message.isFromMe!) {
      if (SettingsManager().settings.colorfulBubbles.value) {
        if (!isNullOrEmpty(colors)!) {
          bool dark = colors![0].computeLuminance() < 0.179;
          if (!dark) {
            textStyle = Theme.of(context)
                .textTheme
                .bodyText2!
                .apply(color: hideContent ? Colors.transparent : colors[0].darkenAmount(0.35));
          } else {
            textStyle = Theme.of(context).textTheme.bodyText2;
            if (hideContent) textStyle = textStyle!.apply(color: Colors.transparent);
          }
        } else {
          textStyle = Theme.of(context).textTheme.bodyText2!.apply(
              color: hideContent
                  ? Colors.transparent
                  : toColorGradient(message.handle?.address ?? "")[0].darkenAmount(0.35));
        }
      } else if (hideContent) {
        textStyle = textStyle!.apply(color: Colors.transparent);
      }
    } else {
      textStyle = textStyle!.apply(
          color: hideContent
              ? Colors.transparent
              : Theme.of(context).primaryColor.computeLuminance() > 0.8
                  ? Colors.black
                  : Colors.white);
    }
    if (colorOverride != null && !hideContent) textStyle = textStyle!.apply(color: colorOverride);
    if ((!isEmptyString(message.text) || !isEmptyString(message.subject))) {
      RegExp exp = RegExp(
          r'((https?://)|(www\.))[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9/()@:%_.~#?&=*\[\]]*)\b');
      List<Tuple2<String, int>> linkIndexMatches = <Tuple2<String, int>>[];
      if (!kIsWeb && !kIsDesktop) {
        if (ChatManager().activeChat?.mlKitParsedText[message.guid!] == null) {
          ChatManager().activeChat?.mlKitParsedText[message.guid!] =
              await GoogleMlKit.nlp.entityExtractor(EntityExtractorOptions.ENGLISH).extractEntities(message.text!);
        }
        final entities = ChatManager().activeChat?.mlKitParsedText[message.guid!] ?? [];
        List<EntityAnnotation> normalizedEntities = [];
        if (entities.isNotEmpty) {
          for (int i = 0; i < entities.length; i++) {
            if (i == 0 || entities[i].start > normalizedEntities.last.end) {
              normalizedEntities.add(entities[i]);
            }
          }
        }
        for (EntityAnnotation element in normalizedEntities) {
          if (element.entities.first is AddressEntity) {
            linkIndexMatches.add(Tuple2("map", element.start));
            linkIndexMatches.add(Tuple2("map", element.end));
          } else if (element.entities.first is PhoneEntity) {
            linkIndexMatches.add(Tuple2("phone", element.start));
            linkIndexMatches.add(Tuple2("phone", element.end));
          } else if (element.entities.first is EmailEntity) {
            linkIndexMatches.add(Tuple2("email", element.start));
            linkIndexMatches.add(Tuple2("email", element.end));
          } else if (element.entities.first is UrlEntity) {
            linkIndexMatches.add(Tuple2("link", element.start));
            linkIndexMatches.add(Tuple2("link", element.end));
          }
        }
      } else {
        List<RegExpMatch> matches = exp.allMatches(message.text!).toList();
        for (RegExpMatch match in matches) {
          linkIndexMatches.add(Tuple2("link", match.start));
          linkIndexMatches.add(Tuple2("link", match.end));
        }
      }
      if (!isNullOrEmpty(message.subject)!) {
        TextStyle _textStyle = message.isFromMe!
            ? textStyle!.apply(color: Colors.white, fontWeightDelta: 2)
            : textStyle!.apply(fontWeightDelta: 2);
        if (hideContent) {
          _textStyle = _textStyle.apply(color: Colors.transparent);
        }
        if (colorOverride != null && !hideContent) _textStyle = _textStyle.apply(color: colorOverride);
        textSpans.addAll(MessageHelper.buildEmojiText(
          "${message.subject}\n",
          _textStyle,
        ));
      }

      if (linkIndexMatches.isNotEmpty) {
        for (int i = 0; i < linkIndexMatches.length + 1; i++) {
          if (i == 0) {
            textSpans.addAll(MessageHelper.buildEmojiText(
              message.text!.substring(0, linkIndexMatches[i].item2),
              textStyle!,
            ));
          } else if (i == linkIndexMatches.length && i - 1 >= 0) {
            textSpans.addAll(MessageHelper.buildEmojiText(
              message.text!.substring(linkIndexMatches[i - 1].item2, message.text!.length),
              textStyle!,
            ));
          } else if (i - 1 >= 0) {
            String type = linkIndexMatches[i].item1;
            String text = message.text!.substring(linkIndexMatches[i - 1].item2, linkIndexMatches[i].item2);
            if (exp.hasMatch(text) || type == "map" || text.isPhoneNumber || text.isEmail) {
              textSpans.add(
                TextSpan(
                  text: text,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () async {
                      if (type == "link") {
                        String url = text;
                        if (!url.startsWith("http://") && !url.startsWith("https://")) {
                          url = "http://" + url;
                        }

                        await launch(url);
                      } else if (type == "map") {
                        await MapsLauncher.launchQuery(text);
                      } else if (type == "phone") {
                        await launch("tel://$text");
                      } else if (type == "email") {
                        await launch("mailto:$text");
                      }
                    },
                  style: textStyle!.apply(decoration: TextDecoration.underline),
                ),
              );
            } else {
              textSpans.addAll(MessageHelper.buildEmojiText(
                text,
                textStyle!,
              ));
            }
          }
        }
      } else {
        textSpans.addAll(MessageHelper.buildEmojiText(
          message.text!,
          textStyle!,
        ));
      }

      if (generateContent) {
        String generatedSubject = fakeSubject ?? faker.lorem.words(message.subject?.split(" ").length ?? 0).join(" ");
        String generatedText = fakeText ?? faker.lorem.words(message.text?.split(" ").length ?? 0).join(" ");
        return [
          if (message.subject != null)
            TextSpan(
                text: "$generatedSubject\n",
                style: message.isFromMe!
                    ? textStyle!.apply(color: Colors.white, fontWeightDelta: 2)
                    : textStyle!.apply(fontWeightDelta: 2)),
          TextSpan(text: generatedText, style: textStyle),
        ];
      }
    } else {
      textSpans.addAll(MessageHelper.buildEmojiText(
        MessageHelper.getNotificationText(message),
        textStyle!,
      ));
    }

    return textSpans;
  }
}
