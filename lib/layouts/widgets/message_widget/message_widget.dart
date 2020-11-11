import 'dart:async';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/reaction.dart';
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
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

class _MessageState extends State<MessageWidget>
    with AutomaticKeepAliveClientMixin {
  bool showTail = true;
  OverlayEntry _entry;
  Completer<void> associatedMessageRequest;
  Completer<void> attachmentsRequest;
  int lastRequestCount = -1;
  int attachmentCount = 0;
  int associatedCount = 0;

  @override
  void initState() {
    super.initState();
    fetchAssociatedMessages();
    fetchAttachments();

    // Listen for new messages
    NewMessageManager().stream.listen((data) {
      // If the message doesn't apply to this chat, ignore it
      if (data.chatGuid != widget.chat.guid) return;

      // If it's not an ADD event, ignore it
      if (data.type != NewMessageType.ADD) return;

      // Check if the new message has an associated GUID that matches this message
      bool fetchAssoc = false;
      bool fetchAttach = false;
      Message message = data.event["message"];
      if (message == null) return;
      if (message.associatedMessageGuid == widget.message.guid) {
        fetchAssoc = true;
      }
      if (message.hasAttachments) {
        fetchAttach = true;
      }

      // If the associated message GUID matches this one, fetch associated messages
      if (fetchAssoc) {
        fetchAssociatedMessages(forceReload: true);
      }

      if (fetchAttach) {
        fetchAttachments(forceReload: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchAssociatedMessages();
    fetchAttachments();
  }

  Future<void> fetchAssociatedMessages({bool forceReload = false}) async {
    // If there is already a request being made, return that request
    if (associatedMessageRequest != null &&
        !associatedMessageRequest.isCompleted) {
      return associatedMessageRequest.future;
    }

    // Create a new request and get the messages
    associatedMessageRequest = new Completer();
    await widget.message.fetchAssociatedMessages();

    bool hasChanges = false;
    if (widget.message.associatedMessages.length != associatedCount ||
        forceReload) {
      associatedCount = widget.message.associatedMessages.length;
      hasChanges = true;
    }

    // If there are changes, re-render
    if (this.mounted && hasChanges) {
      // If we don't think there are reactions, and we found reactions,
      // Update the DB so it saves that we have reactions
      if (!widget.message.hasReactions &&
          widget.message.getReactions().length > 0) {
        widget.message.hasReactions = true;
        widget.message.update();
      }

      setState(() {});
    }

    associatedMessageRequest.complete();
  }

  Future<void> fetchAttachments({bool forceReload = false}) async {
    // If there is already a request being made, return that request
    if (attachmentsRequest != null && !attachmentsRequest.isCompleted) {
      return attachmentsRequest.future;
    }

    // Create a new request and get the attachments
    attachmentsRequest = new Completer();
    if (context != null)
      await widget.message
          .fetchAttachments(currentChat: CurrentChat.of(context));

    // If this is a URL preview and we don't have attachments, we need to get them
    List<Attachment> nonNullAttachments = widget.message.getRealAttachments();
    if (widget.message.isUrlPreview() && nonNullAttachments.isEmpty) {
      if (lastRequestCount != nonNullAttachments.length) {
        lastRequestCount = nonNullAttachments.length;
        SocketManager().setup.startIncrementalSync(SettingsManager().settings,
            chatGuid: CurrentChat.of(context).chat.guid,
            saveDate: false, onComplete: () {
          if (this.mounted) setState(() {});
        });
      }
    }

    bool hasChanges = false;
    if (widget.message.attachments.length != this.attachmentCount ||
        forceReload) {
      this.attachmentCount = widget.message.attachments.length;
      hasChanges = true;
    }

    // NOTE: Not sure if we need to re-render
    if (this.mounted && hasChanges) {
      setState(() {});
    }

    attachmentsRequest.complete();
  }

  bool withinTimeThreshold(Message first, Message second, {threshold: 5}) {
    if (first == null || second == null) return false;
    return second.dateCreated.difference(first.dateCreated).inMinutes.abs() >
        threshold;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.newerMessage != null) {
      showTail = withinTimeThreshold(widget.message, widget.newerMessage,
              threshold: 1) ||
          !sameSender(widget.message, widget.newerMessage) ||
          (widget.message.isFromMe &&
              widget.newerMessage.isFromMe &&
              widget.message.dateDelivered != null &&
              widget.newerMessage.dateDelivered == null);
    }

    if (widget.message.isGroupEvent()) {
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

    // Build the attachments widget
    Widget widgetAttachments = MessageAttachments(
      message: widget.message,
      showTail: showTail,
      showHandle: widget.showHandle,
    );

    UrlPreviewWidget urlPreviewWidget = UrlPreviewWidget(
        key: new Key("preview-${widget.message.guid}"),
        linkPreviews: widget.message.getPreviewAttachments(),
        message: widget.message);
    StickersWidget stickersWidget = StickersWidget(
        key: new Key("stickers-${associatedCount.toString()}"),
        messages: widget.message.associatedMessages);
    ReactionsWidget reactionsWidget = ReactionsWidget(
        key: new Key("reactions-${associatedCount.toString()}"),
        message: widget.message,
        associatedMessages: widget.message.associatedMessages);

    // Add the correct type of message to the message stack
    Widget message;
    if (widget.message.isFromMe) {
      message = SentMessage(
          offset: widget.offset,
          showTail: showTail,
          olderMessage: widget.olderMessage,
          message: widget.message,
          urlPreviewWidget: urlPreviewWidget,
          stickersWidget: stickersWidget,
          attachmentsWidget: widgetAttachments,
          reactionsWidget: reactionsWidget,
          chat: widget.chat,
          shouldFadeIn: CurrentChat.of(context)
              .sentMessages
              .contains(widget.message.guid),
          showHero: widget.showHero,
          showDeliveredReceipt: widget.isFirstSentMessage);
    } else {
      message = ReceivedMessage(
          offset: widget.offset,
          showTail: showTail,
          olderMessage: widget.olderMessage,
          message: widget.message,
          showHandle: widget.showHandle,
          urlPreviewWidget: urlPreviewWidget,
          stickersWidget: stickersWidget,
          attachmentsWidget: widgetAttachments,
          reactionsWidget: reactionsWidget);
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

  @override
  bool get wantKeepAlive => true;
}
