import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/url_preview_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_attachments.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';

class ReceivedMessage extends StatefulWidget {
  final double offset;
  final bool showTail;
  final Message message;
  final Message olderMessage;
  final bool showHandle;
  final SavedAttachmentData savedAttachmentData;
  final bool isGroup;

  // Sub-widgets
  final Widget stickersWidget;
  final Widget attachmentsWidget;
  final Widget reactionsWidget;
  final Widget urlPreviewWidget;

  ReceivedMessage({
    Key key,
    @required this.showTail,
    @required this.olderMessage,
    @required this.message,
    @required this.showHandle,
    @required this.savedAttachmentData,
    @required this.isGroup,

    // Sub-widgets
    @required this.stickersWidget,
    @required this.attachmentsWidget,
    @required this.reactionsWidget,
    @required this.urlPreviewWidget,
    this.offset,
  }) : super(key: key);

  @override
  _ReceivedMessageState createState() => _ReceivedMessageState();
}

class _ReceivedMessageState extends State<ReceivedMessage>
    with MessageWidgetMixin {
  @override
  initState() {
    super.initState();
    initMessageState(widget.message, widget.showHandle)
        .then((value) => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    didChangeMessageDependencies(widget.message, widget.showHandle);

    ContactManager().stream.listen((List<String> addresses) {
      // Check if any of the addresses are members of the chat
      if (!addresses.contains(widget.message.handle.address)) return;
      fetchAvatar(widget.message).then((value) => setState(() {}));
    });
  }

  Future<void> didChangeMessageDependencies(
      Message message, bool showHandle) async {
    await getContactTitle(message, showHandle);
    await getContact(message);
    await fetchAvatar(message);
    setState(() {});
  }

  /// Builds the message bubble with teh tail (if applicable)
  Widget _buildMessageWithTail() {
    return Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        if (widget.showTail) MessageTail(isFromMe: false),
        Container(
          margin: EdgeInsets.only(
            top: widget.message.hasReactions ? 12 : 0,
            left: 10,
            right: 10,
          ),
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width * MessageWidgetMixin.maxSize,
          ),
          padding: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).accentColor,
          ),
          child: RichText(
            text: TextSpan(
              children:
                  MessageWidgetMixin.buildMessageSpans(context, widget.message),
              style: Theme.of(context).textTheme.bodyText1,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message == null) return Container();

    dynamic initials = getInitials(contact?.displayName ?? "", " ", size: 25);

    // The column that holds all the "messages"
    List<Widget> messageColumn = [];

    // First, add the message sender (if applicable)
    if (!sameSender(widget.message, widget.olderMessage) ||
        !widget.message.dateCreated
            .isWithin(widget.olderMessage.dateCreated, minutes: 30)) {
      messageColumn.add(
        Padding(
          padding: EdgeInsets.only(left: 25.0, top: 5.0, bottom: 3.0),
          child: Text(
            contactTitle,
            style: Theme.of(context).textTheme.subtitle1,
          ),
        ),
      );
    }

    // Second, add the attachments
    if (isEmptyString(widget.message.text)) {
      messageColumn.add(
        addStickersToWidget(
          message: addReactionsToWidget(
            message: widget.attachmentsWidget,
            reactions: widget.reactionsWidget,
          ),
          stickers: widget.stickersWidget,
        ),
      );
    } else {
      messageColumn.add(widget.attachmentsWidget);
    }

    // Third, let's add the message or URL preview
    Widget message;
    if (widget.message.hasDdResults && this.hasHyperlinks) {
      message = Padding(
          padding: EdgeInsets.only(left: 10.0), child: widget.urlPreviewWidget);
    } else if (!isEmptyString(widget.message.text)) {
      message = _buildMessageWithTail();
    }

    // Fourth, let's add any reactions or stickers to the widget
    if (message != null) {
      messageColumn.add(
        addStickersToWidget(
          message: addReactionsToWidget(
            message: message,
            reactions: widget.reactionsWidget,
          ),
          stickers: widget.stickersWidget,
        ),
      );
    }

    // Now, let's create a row that will be the row with the following:
    // -> Contact avatar
    // -> Message
    List<Widget> msgRow = [];
    if (widget.showTail && widget.isGroup) {
      msgRow.add(
        Padding(
          padding: EdgeInsets.only(
            left: 5.0,
          ),
          child: ContactAvatarWidget(
            contactImage: contactImage,
            initials: initials,
            size: 30,
            fontSize: 14,
          ),
        ),
      );
    }

    // Add the message column to the row
    msgRow.add(
      Padding(
        // Padding to shift the bubble up a bit, relative to the avatar
        padding: EdgeInsets.only(bottom: (widget.showTail) ? 5.0 : 3.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: messageColumn,
        ),
      ),
    );

    // Finally, create a container row so we can have the swipe timestamp
    return Padding(
      // Add padding when we are showing the avatar
      padding: EdgeInsets.only(
        left: (!widget.showTail && widget.isGroup) ? 35.0 : 0.0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: msgRow,
          ),
          MessageTimeStamp(
            message: widget.message,
            offset: widget.offset,
          )
        ],
      ),
    );
  }
}
