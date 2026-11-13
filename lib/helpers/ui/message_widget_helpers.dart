import 'package:bluebubbles/database/models.dart' hide Entity;
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/sticker_tapback_image.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:bluebubbles/models/models.dart' show TextEntityMatch;
import 'package:bluebubbles/helpers/ui/message_run_spans.dart';
import 'package:url_launcher/url_launcher.dart';

final _messageUrlRegex = RegExp(
  r'((https?://)|(www\.))[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9/()@:%_.~#?&=*\[\]]*)\b',
);

List<TextEntityMatch> _detectMessageLinks(String text) =>
    _messageUrlRegex.allMatches(text).map((match) => TextEntityMatch('link', match.start, match.end, null)).toList();

List<InlineSpan> buildMessageSpans(
  BuildContext context,
  MessagePart part,
  Message message, {
  Color? colorOverride,
  bool hideBodyText = false,
}) => _renderMessageSpans(
  context,
  part,
  message,
  entities: _detectMessageLinks(part.text ?? ''),
  colorOverride: colorOverride,
  hideBodyText: hideBodyText,
);

Future<List<InlineSpan>> buildEnrichedMessageSpans(
  BuildContext context,
  MessagePart part,
  Message message, {
  Color? colorOverride,
  bool hideBodyText = false,
}) async {
  if (hideBodyText || part.shouldRedact || isNullOrEmpty(part.text)) {
    return _renderMessageSpans(context, part, message, colorOverride: colorOverride, hideBodyText: hideBodyText);
  }
  final linkIndexMatches = <TextEntityMatch>[];
  final controller = cvc(message.chat.target ?? ChatsSvc.activeChat!.chat);
  if (!isNullOrEmpty(part.text)) {
    if (!kIsWeb && !kIsDesktop && SettingsSvc.settings.smartReply.value) {
      if (controller.mlKitParsedText["${message.guid!}-${part.part}"] == null) {
        try {
          controller.mlKitParsedText["${message.guid!}-${part.part}"] = await EntityExtractor(
            language: EntityExtractorLanguage.english,
          ).annotateText(sanitizeForMlKit(part.text!));
        } catch (ex, stack) {
          Logger.warn('Failed to extract entities using mlkit!', error: ex, trace: stack);
        }
      }
      final entities = controller.mlKitParsedText["${message.guid!}-${part.part}"] ?? [];
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
          linkIndexMatches.add(TextEntityMatch("map", element.start, element.end, null));
        } else if (element.entities.first is PhoneEntity) {
          linkIndexMatches.add(TextEntityMatch("phone", element.start, element.end, null));
        } else if (element.entities.first is EmailEntity) {
          linkIndexMatches.add(TextEntityMatch("email", element.start, element.end, null));
        } else if (element.entities.first is UrlEntity) {
          linkIndexMatches.add(TextEntityMatch("link", element.start, element.end, null));
        } else if (element.entities.first is DateTimeEntity) {
          final ent = (element.entities.first as DateTimeEntity);
          if (part.text?.substring(element.start, element.end).toLowerCase() == "now") {
            continue;
          }
          linkIndexMatches.add(TextEntityMatch("date", element.start, element.end, [ent.timestamp]));
        } else if (element.entities.first is TrackingNumberEntity) {
          final ent = (element.entities.first as TrackingNumberEntity);
          linkIndexMatches.add(TextEntityMatch("tracking", element.start, element.end, [ent.carrier, ent.number]));
        } else if (element.entities.first is FlightNumberEntity) {
          final ent = (element.entities.first as FlightNumberEntity);
          linkIndexMatches.add(
            TextEntityMatch("flight", element.start, element.end, [ent.airlineCode, ent.flightNumber]),
          );
        }
      }
    } else {
      List<RegExpMatch> matches = _messageUrlRegex.allMatches(part.text!).toList();
      for (RegExpMatch match in matches) {
        linkIndexMatches.add(TextEntityMatch("link", match.start, match.end, null));
      }
    }
  }
  if (!context.mounted) return [];
  return _renderMessageSpans(
    context,
    part,
    message,
    entities: linkIndexMatches,
    colorOverride: colorOverride,
    hideBodyText: hideBodyText,
  );
}

List<InlineSpan> _renderMessageSpans(
  BuildContext context,
  MessagePart part,
  Message message, {
  List<TextEntityMatch> entities = const [],
  Color? colorOverride,
  bool hideBodyText = false,
}) {
  final bubbleColors = context.theme.extensions[BubbleColors] as BubbleColors?;
  final textStyle = (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
    color:
        colorOverride ??
        (message.isFromMe!
            ? context.theme.colorScheme.onBubble(context, message.chat.target?.isIMessage ?? true)
            : bubbleColors?.onReceivedBubbleColor ?? context.theme.colorScheme.onSurfaceVariant),
    fontSizeFactor: message.isBigEmoji ? 3 : 1,
  );
  final spans = <InlineSpan>[];
  if (!isNullOrEmpty(part.subject)) {
    spans.addAll(
      MessageHelper.buildEmojiText(
        '${part.displaySubject}${!hideBodyText ? "\n" : ""}',
        textStyle.apply(fontWeightDelta: 2),
      ),
    );
  }
  if (!hideBodyText && !isNullOrEmpty(part.displayText)) {
    spans.addAll(
      buildMessageRunSpans(
        text: part.displayText!,
        runs: part.shouldRedact ? [] : part.runs,
        entities: part.shouldRedact ? [] : entities,
        style: textStyle,
        onTap: _onMessageEntityTap,
        buildText: (text, style, recognizer) => MessageHelper.buildEmojiText(text, style, recognizer: recognizer),
      ),
    );
  }
  return _withInlineAttachments(spans, part, textStyle);
}

Future<void> _onMessageEntityTap(TextEntityMatch entity, String text) async {
  final type = entity.type;
  final data = entity.metadata;
  if (type == 'mention') {
    if (kIsDesktop || kIsWeb) return;
    final handle = ChatsSvc.activeChat?.chat.handles.firstWhereOrNull((e) => e.address == data?.firstOrNull);
    if (handle?.contactsV2.isNotEmpty == true && handle!.contactsV2.first.isNative) {
      try {
        await MethodChannelSvc.actions.viewContactForm(nativeContactId: handle.contactsV2.first.nativeContactId);
      } catch (_) {
        showSnackbar('Error', 'Failed to find contact on device!', type: SnackbarType.error);
      }
    } else if (handle != null) {
      await MethodChannelSvc.actions.openContactForm(address: handle.address, isEmail: handle.address.isEmail);
    }
    return;
  }
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
    await MethodChannelSvc.actions.openCalendar(dateEpochMillis: data!.first as int);
  } else if (type == "tracking") {
    final TrackingCarrier c = data!.first;
    final String number = data.last;
    Clipboard.setData(ClipboardData(text: number));
    showCopiedToast("Tracking number copied to clipboard");
    await launchUrl(
      Uri.parse("https://www.google.com/search?q=${c.name} $number"),
      mode: LaunchMode.externalApplication,
    );
  } else if (type == "flight") {
    final String c = data!.first;
    final String number = data.last;
    await launchUrl(
      Uri.parse("https://www.google.com/search?q=flight $c$number"),
      mode: LaunchMode.externalApplication,
    );
  }
}

List<InlineSpan> _withInlineAttachments(List<InlineSpan> spans, MessagePart part, TextStyle style) =>
    part.hasInlineAttachments ? withInlineAttachments(spans, part.attachments, style) : spans;

/// Swaps each U+FFFC in [spans] for the next of [inline] (Genmoji), drawn at text height.
List<InlineSpan> withInlineAttachments(List<InlineSpan> spans, Iterable<Attachment?> inline, TextStyle style) {
  final attachments = inline.iterator;
  final size = (style.fontSize ?? 14) * 1.25;
  return spans.expand<InlineSpan>((span) {
    if (span is! TextSpan || !(span.text?.contains(objectReplacementChar) ?? false)) return [span];
    final pieces = span.text!.split(objectReplacementChar);
    return [
      for (int i = 0; i < pieces.length; i++) ...[
        if (i > 0)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SizedBox.square(
              dimension: size,
              child: attachments.moveNext() ? StickerTapbackImage(attachment: attachments.current) : null,
            ),
          ),
        if (pieces[i].isNotEmpty) TextSpan(text: pieces[i], style: span.style, recognizer: span.recognizer),
      ],
    ];
  }).toList();
}

/// Resolves the effective multi-attachment layout for a media gallery.
///
/// [MediaCollectionLayout.skinDefault] maps to the default skin-based choice (iOS: collage for small collections /
/// stack for large ones, split at [MediaCollectionLayout.smallMaxCount]; Material/Samsung: grid). Never returns
/// [MediaCollectionLayout.skinDefault].
MediaCollectionLayout resolveMediaCollectionLayout(int attachmentCount) {
  final small = MediaCollectionLayout.isSmall(attachmentCount);
  final setting = small
      ? SettingsSvc.settings.mediaCollectionLayoutSmall.value
      : SettingsSvc.settings.mediaCollectionLayoutLarge.value;
  if (setting != MediaCollectionLayout.skinDefault) return setting;

  if (!CurrentSkin.iOS) return MediaCollectionLayout.grid;
  return small ? MediaCollectionLayout.collage : MediaCollectionLayout.stack;
}
