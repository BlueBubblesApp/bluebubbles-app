import 'dart:math';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/widgets/message_widget/group_event.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/message_time_stamp_separator.dart';
import 'package:bluebubbles/app/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/received_message.dart';
import 'package:bluebubbles/app/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/app/widgets/message_widget/stickers_widget.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:faker/faker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_utils/src/extensions/context_extensions.dart';

class MessageWidget extends CustomStateful<MessageWidgetController> {
  MessageWidget({
    Key? key,
    required this.message,
    required this.olderMessage,
    required this.newerMessage,
    required this.showHandle,
    required this.isFirstSentMessage,
    required this.showHero,
    required this.showReplies,
    this.bloc,
    required this.controller,
    required this.autoplayEffect,
  }) : super(key: key, parentController: mwc(message));

  final Message message;
  final Message? newerMessage;
  final Message? olderMessage;
  final bool showHandle;
  final bool isFirstSentMessage;
  final bool showHero;
  final bool showReplies;
  final MessagesService? bloc;
  final ConversationViewController controller;
  final bool autoplayEffect;

  @override
  State<MessageWidget> createState() => _MessageState();
}

class _MessageState extends CustomState<MessageWidget, void, MessageWidgetController> {
  bool showTail = true;
  Message get _message => controller.message;
  late final Message? _newerMessage = widget.newerMessage;
  late final Message? _olderMessage = widget.olderMessage;
  final RxBool tapped = false.obs;
  double baseOffset = 0;
  final RxDouble offset = 0.0.obs;
  bool gaveHapticFeedback = false;

  late final _fakeOlderSubject = faker.lorem.words(widget.olderMessage?.subject?.split(" ").length ?? 0).join(" ");
  late final _fakeOlderText = faker.lorem.words(widget.olderMessage?.text?.split(" ").length ?? 0).join(" ");
  late final _fakeSubject = faker.lorem.words(widget.message.subject?.split(" ").length ?? 0).join(" ");
  late final _fakeText = faker.lorem.words(widget.message.text?.split(" ").length ?? 0).join(" ");

  @override
  Widget build(BuildContext context) {
    if (_newerMessage != null) {
      if (_newerMessage!.isGroupEvent) {
        showTail = true;
      } else if (ss.settings.skin.value == Skins.Samsung) {
        showTail = _message.showTail(_olderMessage);
      } else {
        showTail = _message.showTail(_newerMessage);
      }
    }

    if (_message.isGroupEvent) {
      return GroupEvent(key: Key("group-event-${_message.guid}"), message: _message);
    }

    ////////// READ //////////
    /// This widget and code below will handle building out the following:
    /// -> Attachments
    /// -> Reactions
    /// -> Stickers
    /// -> URL Previews
    /// -> Big Emojis??
    ////////// READ //////////

    // Build the attachments widget
    Widget widgetAttachments = MessageAttachments(
      message: _message,
      showTail: showTail,
      showHandle: widget.showHandle,
    );

    UrlPreviewWidget urlPreviewWidget = UrlPreviewWidget(
        key: Key("preview-${_message.guid}"), linkPreviews: _message.previewAttachments, message: _message);
    StickersWidget stickersWidget =
        StickersWidget(key: Key("stickers-${_message.guid}"), messages: _message.associatedMessages, size: _message.getBubbleSize(context));
    ReactionsWidget reactionsWidget = ReactionsWidget(
        key: Key("reactions-${_message.guid}"), associatedMessages: _message.associatedMessages);
    final separator = MessageTimeStampSeparator(
      newerMessage: _message,
      message: _olderMessage ?? _message,
    );
    final separator2 = MessageTimeStampSeparator(
      newerMessage: _newerMessage,
      message: _message,
    );

    // Add the correct type of message to the message stack
    return Obx(
      () {
        Widget message;
        bool _tapped = tapped.value;
        if (_message.isFromMe!) {
          message = SentMessage(
            showTail: showTail,
            olderMessage: widget.olderMessage,
            newerMessage: widget.newerMessage,
            message: _message,
            messageBloc: widget.bloc,
            hasTimestampAbove: separator.buildTimeStamp().isNotEmpty,
            hasTimestampBelow: separator2.buildTimeStamp().isNotEmpty,
            showReplies: widget.showReplies,
            urlPreviewWidget: urlPreviewWidget,
            stickersWidget: stickersWidget,
            attachmentsWidget: widgetAttachments,
            reactionsWidget: reactionsWidget,
            shouldFadeIn: widget.bloc?.mostRecentSent?.guid == _message.guid,
            showHero: widget.showHero,
            showDeliveredReceipt: widget.isFirstSentMessage || _tapped,
            autoplayEffect: widget.autoplayEffect,
          );
        } else {
          message = ReceivedMessage(
            showTail: showTail,
            olderMessage: widget.olderMessage,
            newerMessage: widget.newerMessage,
            message: _message,
            fakeOlderSubject: _fakeOlderSubject,
            fakeOlderText: _fakeOlderText,
            fakeSubject: _fakeSubject,
            fakeText: _fakeText,
            messageBloc: widget.bloc,
            hasTimestampAbove: separator.buildTimeStamp().isNotEmpty,
            hasTimestampBelow: separator2.buildTimeStamp().isNotEmpty,
            showReplies: widget.showReplies,
            showHandle: widget.showHandle,
            urlPreviewWidget: urlPreviewWidget,
            stickersWidget: stickersWidget,
            attachmentsWidget: widgetAttachments,
            reactionsWidget: reactionsWidget,
            showTimeStamp: _tapped,
            autoplayEffect: widget.autoplayEffect,
          );
        }

        double replyThreshold = 40;
        final Chat? chat = widget.bloc?.chat;

        return Obx(
          () => GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: kIsDesktop || kIsWeb ? () => tapped.value = !tapped.value : null,
            onHorizontalDragStart: !ss.settings.enablePrivateAPI.value
                || !ss.settings.swipeToReply.value
                || !(chat?.isIMessage ?? true) ? null : (details) {
              baseOffset = details.localPosition.dx;
            },
            onHorizontalDragUpdate: !ss.settings.enablePrivateAPI.value
                || !ss.settings.swipeToReply.value
                || !(chat?.isIMessage ?? true) ? null : (details) {
              offset.value = min(max((details.localPosition.dx - baseOffset) * (_message.isFromMe! ? -1 : 1), 0),
                  replyThreshold * 1.5);
              if (!gaveHapticFeedback && offset.value >= replyThreshold) {
                HapticFeedback.lightImpact();
                gaveHapticFeedback = true;
              } else if (offset.value < replyThreshold) {
                gaveHapticFeedback = false;
              }
              // ChatLifecycleManager.of(context)?.setReplyOffset(_message.guid ?? "", offset.value);
            },
            onHorizontalDragEnd: !ss.settings.enablePrivateAPI.value
                || !ss.settings.swipeToReply.value
                || !(chat?.isIMessage ?? true) ? null : (details) {
              if (offset.value >= replyThreshold) {
                widget.controller.replyToMessage = _message;
              }
              offset.value = 0;
              // ChatLifecycleManager.of(context)?.setReplyOffset(_message.guid ?? "", offset.value);
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: offset.value == 0 ? 150 : 0),
              padding: _message.isFromMe!
                  ? EdgeInsets.only(
                      right: max(0, offset.value),
                    )
                  : EdgeInsets.only(
                      left: max(0, offset.value),
                    ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: <Widget>[
                  AnimatedPositioned(
                    duration: Duration(milliseconds: offset.value == 0 ? 150 : 0),
                    left: !_message.isFromMe! ? -offset.value * 0.8 : null,
                    right: _message.isFromMe! ? -offset.value * 0.8 : null,
                    child: AnimatedOpacity(
                      duration: Duration(milliseconds: offset.value == 0 ? 150 : 0),
                      opacity: offset.value == 0 ? 0 : 1,
                      child: AnimatedContainer(
                        margin: EdgeInsets.only(
                            bottom: min(replyThreshold, offset.value) * (!_message.isFromMe! ? 0.10 : 0.20) +
                                (widget.isFirstSentMessage && _message.dateDelivered != null ? 20 : 0)),
                        duration: Duration(milliseconds: offset.value == 0 ? 150 : 0),
                        width: min(replyThreshold, offset.value) * 0.8,
                        height: min(replyThreshold, offset.value) * 0.8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.circular(
                              min(replyThreshold, offset.value) * 0.4,
                            ),
                          ),
                          color: context.theme.colorScheme.properSurface,
                        ),
                        child: AnimatedSize(
                          duration: Duration(milliseconds: offset.value == 0 ? 150 : 0),
                          child: Icon(
                            ss.settings.skin.value == Skins.iOS ? CupertinoIcons.reply : Icons.reply,
                            size: min(replyThreshold, offset.value) * (offset.value >= replyThreshold ? 0.5 : 0.4),
                            color: context.theme.colorScheme.properOnSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Column(children: <Widget>[
                    message,
                    separator2,
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
