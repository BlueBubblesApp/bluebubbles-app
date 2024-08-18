import 'package:bluebubbles/database/models.dart' hide Entity;
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:maps_launcher/maps_launcher.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';

class MentionEntity extends Entity {
  /// Constructor to create an instance of [AddressEntity].
  MentionEntity(String rawValue) : super(rawValue: rawValue, type: EntityType.unknown);
}

List<InlineSpan> buildMessageSpans(BuildContext context, MessagePart part, Message message, {Color? colorOverride, bool hideBodyText = false}) {
  final textSpans = <InlineSpan>[];
  final textStyle = (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
    color: colorOverride ?? (message.isFromMe! ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface),
    fontSizeFactor: message.isBigEmoji ? 3 : 1,
  );

  if (!isNullOrEmpty(part.subject)) {
    textSpans.addAll(MessageHelper.buildEmojiText(
      "${part.displaySubject}${!hideBodyText ? "\n" : ""}",
      textStyle.apply(fontWeightDelta: 2),
    ));
  }
  if (part.mentions.isNotEmpty) {
    part.mentions.forEachIndexed((i, e) {
      final range = part.mentions[i].range;
      textSpans.addAll(MessageHelper.buildEmojiText(
        part.displayText!.substring(i == 0 ? 0 : part.mentions[i - 1].range.last, range.first),
        textStyle,
      ));
      textSpans.addAll(MessageHelper.buildEmojiText(
        part.displayText!.substring(range.first, range.last),
        textStyle.apply(fontWeightDelta: 2),
        recognizer: TapGestureRecognizer()..onTap = () async {
          if (kIsDesktop || kIsWeb) return;
          final handle = cm.activeChat!.chat.participants.firstWhereOrNull((e) => e.address == part.mentions[i].mentionedAddress);
          if (handle?.contact == null && handle != null) {
            await mcs.invokeMethod("open-contact-form", {'address': handle.address, 'address_type': handle.address.isEmail ? 'email' : 'phone'});
          } else if (handle?.contact != null) {
            try {
              await mcs.invokeMethod("view-contact-form", {'id': handle!.contact!.id});
            } catch (_) {
              showSnackbar("Error", "Failed to find contact on device!");
            }
          }
        }
      ));
      if (i == part.mentions.length - 1) {
        textSpans.addAll(MessageHelper.buildEmojiText(
          part.displayText!.substring(range.last),
          textStyle,
        ));
      }
    });
  } else if (!isNullOrEmpty(part.displayText)) {
    textSpans.addAll(MessageHelper.buildEmojiText(
      part.displayText!,
      textStyle,
    ));
  }

  return textSpans;
}

Future<List<InlineSpan>> buildEnrichedMessageSpans(BuildContext context, MessagePart part, Message message, {Color? colorOverride, bool hideBodyText = false}) async {
  final textSpans = <InlineSpan>[];
  final textStyle = (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
    color: colorOverride ?? (message.isFromMe! ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface),
    fontSizeFactor: message.isBigEmoji ? 3 : 1,
  );
  // extract rich content
  final urlRegex = RegExp(r'((https?://)|(www\.))[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9/()@:%_.~#?&=*\[\]]*)\b');
  final linkIndexMatches = <Tuple3<String, List<int>, List?>>[];
  final controller = cvc(message.chat.target ?? cm.activeChat!.chat);
  if (!isNullOrEmpty(part.text)) {
    if (!kIsWeb && !kIsDesktop && ss.settings.smartReply.value) {
      if (controller.mlKitParsedText["${message.guid!}-${part.part}"] == null) {
        try {
          controller.mlKitParsedText["${message.guid!}-${part.part}"] = await GoogleMlKit.nlp.entityExtractor(EntityExtractorLanguage.english)
              .annotateText(part.text!);
        } catch (ex, stack) {
          Logger.warn('Failed to extract entities using mlkit!', error: ex, trace: stack);
        }
      }
      final entities = controller.mlKitParsedText["${message.guid!}-${part.part}"] ?? [];
      entities.insertAll(0, part.mentions.map((e) => EntityAnnotation(
          start: e.range.first,
          end: e.range.last,
          text: message.text!.substring(e.range.first, e.range.last),
          entities: [
            MentionEntity(e.mentionedAddress ?? ""),
          ]
      )));
      List<EntityAnnotation> normalizedEntities = [];
      if (entities.isNotEmpty) {
        // detect the longest amount of the message text as possible
        entities.sort((a, b) => (b.end - b.start).compareTo(a.end - a.start));
        for (int i = 0; i < entities.length; i++) {
          if (i == 0 || entities[i].start > normalizedEntities.last.end) {
            normalizedEntities.add(entities[i]);
          }
        }
      }
      for (EntityAnnotation element in normalizedEntities) {
        if (element.entities.first is AddressEntity) {
          linkIndexMatches.add(Tuple3("map", [element.start, element.end], null));
        } else if (element.entities.first is PhoneEntity) {
          linkIndexMatches.add(Tuple3("phone", [element.start, element.end], null));
        } else if (element.entities.first is EmailEntity) {
          linkIndexMatches.add(Tuple3("email", [element.start, element.end], null));
        } else if (element.entities.first is UrlEntity) {
          linkIndexMatches.add(Tuple3("link", [element.start, element.end], null));
        } else if (element.entities.first is DateTimeEntity) {
          final ent = (element.entities.first as DateTimeEntity);
          if (part.text?.substring(element.start, element.end).toLowerCase() == "now") {
            continue;
          }
          linkIndexMatches.add(Tuple3("date", [element.start, element.end], [ent.timestamp]));
        } else if (element.entities.first is TrackingNumberEntity) {
          final ent = (element.entities.first as TrackingNumberEntity);
          linkIndexMatches.add(Tuple3("tracking", [element.start, element.end], [ent.carrier, ent.number]));
        } else if (element.entities.first is FlightNumberEntity) {
          final ent = (element.entities.first as FlightNumberEntity);
          linkIndexMatches.add(Tuple3("flight", [element.start, element.end], [ent.airlineCode, ent.flightNumber]));
        } else if (element.entities.first is MentionEntity) {
          linkIndexMatches.add(Tuple3("mention", [element.start, element.end], [element.entities.first.rawValue]));
        }
      }
    } else {
      List<RegExpMatch> matches = urlRegex.allMatches(part.text!).toList();
      for (RegExpMatch match in matches) {
        linkIndexMatches.add(Tuple3("link", [match.start, match.end], null));
      }
      linkIndexMatches.addAll(part.mentions.map((e) => Tuple3("mention", [e.range.first, e.range.last], [e.mentionedAddress ?? ""])));
    }
  }
  // render subject
  if (!isNullOrEmpty(part.subject)) {
    textSpans.addAll(MessageHelper.buildEmojiText(
      "${part.displaySubject}${!hideBodyText ? "\n" : ""}",
      textStyle.apply(fontWeightDelta: 2),
    ));
  }
  linkIndexMatches.sort((a, b) => a.item2.first.compareTo(b.item2.first));
  // render rich content if needed
  if (linkIndexMatches.isNotEmpty) {
    linkIndexMatches.forEachIndexed((i, e) {
      final type = e.item1;
      final range = e.item2;
      final data = e.item3;
      final text = part.displayText!.substring(range.first, range.last);
      textSpans.addAll(MessageHelper.buildEmojiText(
        part.displayText!.substring(i == 0 ? 0 : linkIndexMatches[i - 1].item2.last, range.first),
        textStyle,
      ));
      if (type == "mention") {
        textSpans.addAll(MessageHelper.buildEmojiText(
          text,
          textStyle.apply(fontWeightDelta: 2),
          recognizer: TapGestureRecognizer()..onTap = () async {
            if (kIsDesktop || kIsWeb) return;
            final handle = cm.activeChat!.chat.participants.firstWhereOrNull((e) => e.address == data!.first);
            if (handle?.contact == null && handle != null) {
              await mcs.invokeMethod("open-contact-form", {'address': handle.address, 'address_type': handle.address.isEmail ? 'email' : 'phone'});
            } else if (handle?.contact != null) {
              try {
                await mcs.invokeMethod("view-contact-form", {'id': handle!.contact!.id});
              } catch (_) {
                showSnackbar("Error", "Failed to find contact on device!");
              }
            }
          }
        ));
      } else if (urlRegex.hasMatch(text) || type == "map" || text.isPhoneNumber || text.isEmail || type == "date" || type == "tracking" || type == "flight") {
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
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else if (type == "map") {
                  await MapsLauncher.launchQuery(text);
                } else if (type == "phone") {
                  await launchUrl(Uri(scheme: "tel", path: text));
                } else if (type == "email") {
                  await launchUrl(Uri(scheme: "mailto", path: text));
                } else if (type == "date") {
                  await mcs.invokeMethod("open-calendar", {"date": data!.first});
                } else if (type == "tracking") {
                  final TrackingCarrier c = data!.first;
                  final String number = data.last;
                  Clipboard.setData(ClipboardData(text: number));
                  await launchUrl(Uri.parse("https://www.google.com/search?q=${c.name} $number"), mode: LaunchMode.externalApplication);
                } else if (type == "flight") {
                  final String c = data!.first;
                  final String number = data.last;
                  await launchUrl(Uri.parse("https://www.google.com/search?q=flight $c$number"), mode: LaunchMode.externalApplication);
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
      if (i == linkIndexMatches.length - 1) {
        textSpans.addAll(MessageHelper.buildEmojiText(
          part.displayText!.substring(range.last),
          textStyle,
        ));
      }
    });
  } else if (!isNullOrEmpty(part.displayText)) {
    textSpans.addAll(MessageHelper.buildEmojiText(
      part.displayText!,
      textStyle,
    ));
  }

  return textSpans;
}