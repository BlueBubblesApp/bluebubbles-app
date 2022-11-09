import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/types/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:maps_launcher/maps_launcher.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

List<InlineSpan> buildMessageSpans(BuildContext context, MessagePart part, Message message) {
  final textSpans = <InlineSpan>[];
  final textStyle = (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
    color: message.isFromMe! ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface,
  );

  if (!isNullOrEmpty(part.subject)!) {
    textSpans.addAll(MessageHelper.buildEmojiText(
      "${part.subject}\n",
      textStyle.apply(fontWeightDelta: 2),
    ));
  }
  textSpans.addAll(MessageHelper.buildEmojiText(
    "${part.text}",
    textStyle,
  ));

  return textSpans;
}

Future<List<InlineSpan>> buildEnrichedMessageSpans(BuildContext context, MessagePart part, Message message) async {
  final textSpans = <InlineSpan>[];
  final textStyle = (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
    color: message.isFromMe! ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface,
  );
  // extract rich content
  final urlRegex = RegExp(r'((https?://)|(www\.))[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9/()@:%_.~#?&=*\[\]]*)\b');
  final linkIndexMatches = <Tuple2<String, int>>[];
  final controller = cvc(message.chat.target!);
  if (!kIsWeb && !kIsDesktop) {
    if (controller.mlKitParsedText[message.guid!] == null) {
      try {
        controller.mlKitParsedText[message.guid!] = await GoogleMlKit.nlp.entityExtractor(EntityExtractorLanguage.english)
            .annotateText(part.text!);
      } catch (ex) {
        Logger.warn('Failed to extract entities using mlkit! Error: ${ex.toString()}');
      }
    }
    final entities = controller.mlKitParsedText[message.guid!] ?? [];
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
    List<RegExpMatch> matches = urlRegex.allMatches(part.text!).toList();
    for (RegExpMatch match in matches) {
      linkIndexMatches.add(Tuple2("link", match.start));
      linkIndexMatches.add(Tuple2("link", match.end));
    }
  }
  // render subject
  if (!isNullOrEmpty(part.subject)!) {
    textSpans.addAll(MessageHelper.buildEmojiText(
      "${part.subject}\n",
      textStyle.apply(fontWeightDelta: 2),
    ));
  }
  // render rich content if needed
  if (linkIndexMatches.isNotEmpty) {
    for (int i = 0; i < linkIndexMatches.length + 1; i++) {
      if (i == 0) {
        textSpans.addAll(MessageHelper.buildEmojiText(
          part.text!.substring(0, linkIndexMatches[i].item2),
          textStyle,
        ));
      } else if (i == linkIndexMatches.length && i - 1 >= 0) {
        textSpans.addAll(MessageHelper.buildEmojiText(
          part.text!.substring(linkIndexMatches[i - 1].item2, part.text!.length),
          textStyle,
        ));
      } else if (i - 1 >= 0) {
        String type = linkIndexMatches[i].item1;
        String text = part.text!.substring(linkIndexMatches[i - 1].item2, linkIndexMatches[i].item2);
        if (urlRegex.hasMatch(text) || type == "map" || text.isPhoneNumber || text.isEmail) {
          textSpans.add(
            TextSpan(
              text: text,
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  if (type == "link") {
                    String url = text;
                    if (!url.startsWith("http://") && !url.startsWith("https://")) {
                      url = "http://$url";
                    }

                    await launchUrlString(url);
                  } else if (type == "map") {
                    await MapsLauncher.launchQuery(text);
                  } else if (type == "phone") {
                    await launchUrl(Uri(scheme: "tel", path: text));
                  } else if (type == "email") {
                    await launchUrl(Uri(scheme: "mailto", path: text));
                  }
                },
              style: textStyle.apply(decoration: TextDecoration.underline),
            ),
          );
        } else {
          textSpans.addAll(MessageHelper.buildEmojiText(
            text,
            textStyle,
          ));
        }
      }
    }
  } else {
    textSpans.addAll(MessageHelper.buildEmojiText(
      part.text!,
      textStyle,
    ));
  }

  return textSpans;
}