import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/apple_pay.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/embedded_media.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/game_pigeon.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/supported_interactive.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/unsupported_interactive.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart' hide PayloadType;
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class InteractiveHolder extends StatefulWidget {
  const InteractiveHolder({
    super.key,
    required this.message,
  });

  final MessagePart message;

  @override
  State<StatefulWidget> createState() => _InteractiveHolderState();
}

class _InteractiveHolderState extends State<InteractiveHolder> with AutomaticKeepAliveClientMixin, ThemeHelpers {
  late MessageState _ms;
  MessageState get controller => _ms;

  MessagePart get part => widget.message;
  Message get message => controller.message;
  PayloadData? get payloadData => message.payloadData;

  @override
  void initState() {
    super.initState();
    _ms = MessageStateScope.readStateOnce(context);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      // Observe selection state
      final selected = !iOS && (controller.cvController?.selected.any((m) => m.guid == message.guid) ?? false);

      return ColorFiltered(
        colorFilter: ColorFilter.mode(
            !selected ? Colors.transparent : context.theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            BlendMode.srcOver),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (payloadData == null && !message.isLegacyUrlPreview)
                ? null
                : () async {
                    String? url;
                    if (payloadData == null) {
                      url = message.url;
                    } else if (payloadData!.type == PayloadType.url) {
                      url = payloadData!.urlData!.first.originalUrl ?? payloadData!.urlData!.first.url;
                    } else {
                      url = payloadData!.appData!.first.url;
                    }
                    if (url != null && Uri.tryParse(url) != null) {
                      await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
            child: CustomPaint(
              painter: iOS
                  ? null
                  : TailPainter(
                      isFromMe: message.isFromMe!,
                      showTail: false,
                      color: (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor ??
                          context.theme.colorScheme.surfaceContainerHighest,
                      width: 1.5,
                    ),
              child: Ink(
                color: iOS
                    ? ((context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor ??
                        context.theme.colorScheme.surfaceContainerHighest)
                    : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: NavigationSvc.width(context) * (NavigationSvc.isTabletMode(context) ? 0.5 : 0.6),
                    maxHeight: context.height * 0.6,
                    minHeight: 40,
                    minWidth: 40,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0),
                    child: Center(
                      heightFactor: 1,
                      widthFactor: 1,
                      child: _ms.shouldHideAttachments.value
                          ? const Padding(padding: EdgeInsets.all(15), child: Text("Interactive Message"))
                          : Obx(() {
                              final isTempMessage = controller.isSending.value;
                              return Opacity(
                                  opacity: isTempMessage ? 0.5 : 1,
                                  child: Builder(builder: (context) {
                                    if (payloadData == null && !(message.isLegacyUrlPreview)) {
                                      switch (message.interactiveText) {
                                        case "Handwriten Message":
                                        case "Digital Touch Message":
                                          if (SettingsSvc.settings.enablePrivateAPI.value &&
                                              SettingsSvc.serverDetails.isMinBigSur &&
                                              SettingsSvc.serverDetails.supportsGroupChatManagement) {
                                            return const EmbeddedMedia();
                                          } else {
                                            return const UnsupportedInteractive(
                                              payloadData: null,
                                            );
                                          }
                                        default:
                                          return const UnsupportedInteractive(
                                            payloadData: null,
                                          );
                                      }
                                    } else if (payloadData?.type == PayloadType.url || message.isLegacyUrlPreview) {
                                      final urlData =
                                          payloadData?.urlData?.first ?? UrlPreviewData(originalUrl: message.url);
                                      return UrlPreview(data: urlData);
                                    } else {
                                      final data = payloadData!.appData!.first;
                                      switch (message.interactiveText) {
                                        case "YouTube":
                                        case "Photos":
                                        case "OpenTable":
                                        case "iMessage Poll":
                                        case "Shazam":
                                        case "Google Maps":
                                          return SupportedInteractive(
                                            data: data,
                                          );
                                        case "GamePigeon":
                                          return GamePigeon(
                                            data: data,
                                          );
                                        case "Apple Pay":
                                          return ApplePay(
                                            data: data,
                                          );
                                        default:
                                          return UnsupportedInteractive(
                                            payloadData: data,
                                          );
                                      }
                                    }
                                  }));
                            }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
