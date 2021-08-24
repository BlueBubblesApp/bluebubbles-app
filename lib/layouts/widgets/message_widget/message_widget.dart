import 'dart:async';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/group_event.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp_separator.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/received_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/sent_message.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/stickers_widget.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MessageWidget extends StatefulWidget {
  MessageWidget({
    Key? key,
    required this.message,
    required this.olderMessage,
    required this.newerMessage,
    required this.showHandle,
    required this.isFirstSentMessage,
    required this.showHero,
    this.onUpdate,
  }) : super(key: key);

  final Message message;
  final Message? newerMessage;
  final Message? olderMessage;
  final bool showHandle;
  final bool isFirstSentMessage;
  final bool showHero;
  final Message? Function(NewMessageEvent event)? onUpdate;

  @override
  _MessageState createState() => _MessageState();
}

class _MessageState extends State<MessageWidget> with AutomaticKeepAliveClientMixin {
  bool showTail = true;
  Completer<void>? associatedMessageRequest;
  Completer<void>? attachmentsRequest;
  Completer<void>? handleRequest;
  int lastRequestCount = -1;
  int attachmentCount = 0;
  int associatedCount = 0;
  bool handledInit = false;
  CurrentChat? currentChat;
  StreamSubscription<NewMessageEvent>? subscription;
  late Message _message;
  Message? _newerMessage;
  Message? _olderMessage;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    init();
  }

  void init() {
    currentChat = CurrentChat.of(context);
    if (handledInit) return;
    handledInit = true;
    _message = widget.message;
    _newerMessage = widget.newerMessage;
    _olderMessage = widget.olderMessage;

    checkHandle();
    fetchAssociatedMessages();
    fetchAttachments();

    // If we already are listening to the stream, no need to do it again
    if (subscription != null) return;

    // Listen for new messages
    subscription = NewMessageManager().stream.listen((data) {
      // If the message doesn't apply to this chat, ignore it
      if (data.chatGuid != currentChat?.chat.guid) return;

      if (data.type == NewMessageType.ADD) {
        // Check if the new message has an associated GUID that matches this message
        bool fetchAssoc = false;
        bool fetchAttach = false;
        Message? message = data.event["message"];
        if (message == null) return;
        if (message.associatedMessageGuid == widget.message.guid) fetchAssoc = true;
        if (message.hasAttachments) fetchAttach = true;

        // If the associated message GUID matches this one, fetch associated messages
        if (fetchAssoc) fetchAssociatedMessages(forceReload: true);
        if (fetchAttach) fetchAttachments(forceReload: true);
      } else if (data.type == NewMessageType.UPDATE) {
        String? oldGuid = data.event["oldGuid"];
        // If the guid does not match our current guid, then it's not meant for us
        if (oldGuid != _message.guid && oldGuid != _newerMessage?.guid) return;

        // Tell the [MessagesView] to update with the new event, to ensure that things are done synchronously
        if (widget.onUpdate != null) {
          Message? result = widget.onUpdate!(data);
          if (result != null) {
            if (this.mounted)
              setState(() {
                if (_message.guid == oldGuid) {
                  _message = result;
                } else if (_newerMessage!.guid == oldGuid) {
                  _newerMessage = result;
                }
              });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> checkHandle() async {
    // If we've already started, return the request
    if (handleRequest != null) return handleRequest!.future;
    handleRequest = new Completer();

    // Checks ordered in a specific way to ever so slightly reduce processing
    if (_message.isFromMe!) return handleRequest!.complete();
    if (_message.handle != null) return handleRequest!.complete();

    try {
      Handle? handle = await _message.getHandle();
      if (this.mounted && handle != null) {
        setState(() {});
      }
    } catch (ex) {
      handleRequest!.completeError(ex);
    }
  }

  Future<void> fetchAssociatedMessages({bool forceReload = false}) async {
    // If there is already a request being made, return that request
    if (!forceReload && associatedMessageRequest != null) return associatedMessageRequest!.future;

    // Create a new request and get the messages
    associatedMessageRequest = new Completer();

    try {
      await _message.fetchAssociatedMessages();
    } catch (ex) {
      return associatedMessageRequest!.completeError(ex);
    }

    bool hasChanges = false;
    if (_message.associatedMessages.length != associatedCount || forceReload) {
      associatedCount = _message.associatedMessages.length;
      hasChanges = true;
    }

    // If there are changes, re-render
    if (hasChanges) {
      // If we don't think there are reactions, and we found reactions,
      // Update the DB so it saves that we have reactions
      if (!_message.hasReactions && _message.getReactions().length > 0) {
        _message.hasReactions = true;
        _message.update();
      }

      if (this.mounted) setState(() {});
    }

    associatedMessageRequest!.complete();
  }

  Future<void> fetchAttachments({bool forceReload = false}) async {
    // If there is already a request being made, return that request
    if (!forceReload && attachmentsRequest != null) return attachmentsRequest!.future;

    // Create a new request and get the attachments
    attachmentsRequest = new Completer();
    if (!this.mounted) return attachmentsRequest!.complete();

    try {
      await _message.fetchAttachments(currentChat: currentChat);
    } catch (ex) {
      return attachmentsRequest!.completeError(ex);
    }

    // If this is a URL preview and we don't have attachments, we need to get them
    List<Attachment?> nullAttachments = _message.getPreviewAttachments();
    if (_message.isUrlPreview() && nullAttachments.isEmpty) {
      if (lastRequestCount != nullAttachments.length) {
        lastRequestCount = nullAttachments.length;

        List<dynamic> msgs = (await SocketManager().getAttachments(currentChat!.chat.guid!, _message.guid!)) ?? [];
        for (var msg in msgs) await ActionHandler.handleMessage(msg, forceProcess: true);
      }
    }

    bool hasChanges = false;
    if (_message.attachments!.length != this.attachmentCount || forceReload) {
      this.attachmentCount = _message.attachments!.length;
      hasChanges = true;
    }

    // NOTE: Not sure if we need to re-render
    if (this.mounted && hasChanges) {
      setState(() {});
    }

    if (!attachmentsRequest!.isCompleted) attachmentsRequest!.complete();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_newerMessage != null) {
      if (_newerMessage!.isGroupEvent()) {
        showTail = true;
      } else if (SettingsManager().settings.skin.value == Skins.Samsung) {
        showTail = MessageHelper.getShowTailReversed(context, _message, _olderMessage);
      } else {
        showTail = MessageHelper.getShowTail(context, _message, _newerMessage);
      }
    }

    if (_message.isGroupEvent()) {
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
        key: new Key("preview-${_message.guid}"), linkPreviews: _message.getPreviewAttachments(), message: _message);
    StickersWidget stickersWidget =
        StickersWidget(key: new Key("stickers-${associatedCount.toString()}"), messages: _message.associatedMessages);
    ReactionsWidget reactionsWidget = ReactionsWidget(
        key: new Key("reactions-${associatedCount.toString()}"), associatedMessages: _message.associatedMessages);

    // Add the correct type of message to the message stack
    Widget message;
    if (_message.isFromMe!) {
      message = SentMessage(
        showTail: showTail,
        olderMessage: widget.olderMessage,
        newerMessage: widget.newerMessage,
        message: _message,
        urlPreviewWidget: urlPreviewWidget,
        stickersWidget: stickersWidget,
        attachmentsWidget: widgetAttachments,
        reactionsWidget: reactionsWidget,
        shouldFadeIn: currentChat?.sentMessages.contains(_message.guid) ?? false,
        showHero: widget.showHero,
        showDeliveredReceipt: widget.isFirstSentMessage,
      );
    } else {
      message = ReceivedMessage(
        showTail: showTail,
        olderMessage: widget.olderMessage,
        newerMessage: widget.newerMessage,
        message: _message,
        showHandle: widget.showHandle,
        urlPreviewWidget: urlPreviewWidget,
        stickersWidget: stickersWidget,
        attachmentsWidget: widgetAttachments,
        reactionsWidget: reactionsWidget,
      );
    }

    return Column(
      children: [
        message,
        if (SettingsManager().settings.skin.value != Skins.Samsung)
          MessageTimeStampSeparator(
            newerMessage: _newerMessage,
            message: _message,
          )
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
