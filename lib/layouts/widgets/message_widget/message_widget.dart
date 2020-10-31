import 'dart:async';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp_separator.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_details_popup.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/stickers_widget.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../../helpers/utils.dart';
import '../../../repository/models/message.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({
    Key key,
    this.message,
    this.chat,
    this.olderMessage,
    this.newerMessage,
    this.showHandle,
    this.isFirstSentMessage,
    this.showHero,
    this.offset,
  }) : super(key: key);

  final Message message;
  final Chat chat;
  final Message newerMessage;
  final Message olderMessage;
  final bool showHandle;
  final bool isFirstSentMessage;
  final bool showHero;
  final double offset;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> {
  List<Attachment> attachments = <Attachment>[];
  List<Message> associatedMessages = [];
  bool showTail = true;
  OverlayEntry _entry;
  Completer<void> associatedMessageRequest;
  Completer<void> attachmentsRequest;

  @override
  void initState() {
    super.initState();
    fetchAssociatedMessages();
    fetchAttachments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchAssociatedMessages();
    fetchAttachments();
  }

  Future<void> fetchAssociatedMessages() async {
    // If there is already a request being made, return that request
    if (associatedMessageRequest != null &&
        !associatedMessageRequest.isCompleted) {
      return associatedMessageRequest.future;
    }

    // Create a new request and get the messages
    associatedMessageRequest = new Completer();
    List<Message> messages = await widget.message.getAssociatedMessages();

    // Make sure the messages are in the correct order from oldest to newest
    messages.sort((a, b) => a.originalROWID.compareTo(b.originalROWID));
    messages = normalizedAssociatedMessages(messages);

    bool hasChanges = false;
    if (messages.length != associatedMessages.length) {
      associatedMessages = messages;
      hasChanges = true;
    }

    // NOTE: Not sure if we need to re-render
    if (this.mounted && hasChanges) {
      setState(() {});
    }

    associatedMessageRequest.complete();
    associatedMessageRequest = null;
  }

  Future<void> fetchAttachments() async {
    // If there is already a request being made, return that request
    if (attachmentsRequest != null && !attachmentsRequest.isCompleted) {
      return attachmentsRequest.future;
    }

    // Create a new request and get the attachments
    attachmentsRequest = new Completer();
    List<Attachment> attachments = await Message.getAttachments(widget.message);

    bool hasChanges = false;
    if (attachments.length != associatedMessages.length) {
      this.attachments = attachments;
      hasChanges = true;
    }

    // NOTE: Not sure if we need to re-render
    if (this.mounted && hasChanges) {
      setState(() {});
    }

    attachmentsRequest.complete();
  }

  /// Removes duplicate associated message guids from a list of [associatedMessages]
  List<Message> normalizedAssociatedMessages(List<Message> associatedMessages) {
    Set<String> guids =
        associatedMessages.map((e) => e.associatedMessageGuid).toSet();
    List<Message> normalized = [];

    for (Message message in associatedMessages.reversed.toList()) {
      if (guids.remove(message.associatedMessageGuid)) {
        normalized.add(message);
      }
    }
    return normalized;
  }

  bool withinTimeThreshold(Message first, Message second, {threshold: 5}) {
    if (first == null || second == null) return false;
    return second.dateCreated.difference(first.dateCreated).inMinutes.abs() >
        threshold;
  }

  @override
  Widget build(BuildContext context) {
    // This needs to be done every build so that if there is a new reaction added
    // while the chat is open, then it will auto update
    fetchAssociatedMessages();

    if (widget.newerMessage != null) {
      showTail = withinTimeThreshold(widget.message, widget.newerMessage,
              threshold: 1) ||
          !sameSender(widget.message, widget.newerMessage) ||
          (widget.message.isFromMe &&
              widget.newerMessage.isFromMe &&
              widget.message.dateDelivered != null &&
              widget.newerMessage.dateDelivered == null);
    }

    if (widget.message != null &&
        isEmptyString(widget.message.text) &&
        !widget.message.hasAttachments) {
      return GroupEvent(message: widget.message);
    }

    ////////// READ //////////
    /// This widget and code below will handle building out the following:
    /// -> Attachments
    /// -> Reactions
    /// -> Stickers
    /// -> URL Previews
    /// -> Big Emojis??
    ////////// READ //////////
    SavedAttachmentData savedAttachmentData =
        CurrentChat().getSavedAttachmentData(widget.message);

    // Build the attachments widget
    Widget widgetAttachments = savedAttachmentData != null
        ? MessageAttachments(
            message: widget.message,
            savedAttachmentData: savedAttachmentData,
            showTail: showTail,
            showHandle: widget.showHandle,
          )
        : Container();

    Widget urlPreviewWidget = UrlPreviewWidget(
      linkPreviews:
          this.attachments.where((item) => item.mimeType == null).toList(),
      message: widget.message,
    );

    // Add the correct type of message to the message stack
    Widget message;
    if (widget.message.isFromMe) {
      message = SentMessage(
        offset: widget.offset,
        hasReactions: associatedMessages.length > 0,
        showTail: showTail,
        olderMessage: widget.olderMessage,
        message: widget.message,
        urlPreviewWidget: urlPreviewWidget,
        stickersWidget: StickersWidget(
          messages: this.associatedMessages,
        ),
        attachmentsWidget: widgetAttachments,
        reactionsWidget: ReactionsWidget(
          message: widget.message,
          associatedMessages: associatedMessages,
        ),
        chat: widget.chat,
        shouldFadeIn: CurrentChat().sentMessages.contains(widget.message.guid),
        showHero: widget.showHero,
        showDeliveredReceipt: widget.isFirstSentMessage,
      );
    } else {
      message = ReceivedMessage(
        offset: widget.offset,
        hasReactions: associatedMessages.length > 0,
        showTail: showTail,
        olderMessage: widget.olderMessage,
        message: widget.message,
        showHandle: widget.showHandle,
        isGroup: widget.chat.participants.length > 1,
        urlPreviewWidget: urlPreviewWidget,
        stickersWidget: StickersWidget(
          messages: associatedMessages,
        ),
        attachmentsWidget: widgetAttachments,
        reactionsWidget: ReactionsWidget(
          message: widget.message,
          associatedMessages: associatedMessages,
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_entry != null) {
          try {
            _entry.remove();
          } catch (e) {}
          _entry = null;
          return true;
        } else {
          return true;
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () async {
          Feedback.forLongPress(context);
          Overlay.of(context).insert(_createMessageDetailsPopup());
        },
        child: Column(
          children: [
            message,
            MessageTimeStampSeparator(
              newerMessage: widget.newerMessage,
              message: widget.message,
            )
          ],
        ),
      ),
    );
  }

  OverlayEntry _createMessageDetailsPopup() {
    _entry = OverlayEntry(
      builder: (context) => MessageDetailsPopup(
        entry: _entry,
        message: widget.message,
      ),
    );
    return _entry;
  }
}
