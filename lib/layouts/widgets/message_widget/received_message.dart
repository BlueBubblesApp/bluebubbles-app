import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/ballon_bundle_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_popup_holder.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

class ReceivedMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final Message olderMessage;
  final bool showHandle;

  // Sub-widgets
  final Widget stickersWidget;
  final Widget attachmentsWidget;
  final Widget reactionsWidget;
  final Widget urlPreviewWidget;

  final bool isGroup;

  ReceivedMessage({
    Key key,
    @required this.showTail,
    @required this.olderMessage,
    @required this.message,
    @required this.showHandle,

    // Sub-widgets
    @required this.stickersWidget,
    @required this.attachmentsWidget,
    @required this.reactionsWidget,
    @required this.urlPreviewWidget,
    this.isGroup = false,
  }) : super(key: key);

  @override
  _ReceivedMessageState createState() => _ReceivedMessageState();
}

class _ReceivedMessageState extends State<ReceivedMessage>
    with MessageWidgetMixin {
  bool checkedHandle = false;
  @override
  initState() {
    super.initState();
    initMessageState(widget.message, widget.showHandle)
        .then((value) => {if (this.mounted) setState(() {})});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    didChangeMessageDependencies(widget.message, widget.showHandle);
  }

  Future<void> didChangeMessageDependencies(
      Message message, bool showHandle) async {
    await getContactTitle(message, showHandle);
    // await fetchAvatar(message);
    if (this.mounted) setState(() {});
  }

  /// Builds the message bubble with teh tail (if applicable)
  Widget _buildMessageWithTail(Message message) {
    if (message.isBigEmoji()) {
      bool hasReactions = (message?.getReactions() ?? []).length > 0 ?? false;
      return Padding(
        padding: EdgeInsets.only(
          left:
              CurrentChat.of(context).chat.participants.length > 1 ? 5.0 : 0.0,
          right: (hasReactions) ? 15.0 : 0.0,
          top: widget.message.getReactions().length > 0 ? 15 : 0,
        ),
        child: Text(
          message.text,
          style: Theme.of(context).textTheme.bodyText2.apply(fontSizeFactor: 4),
        ),
      );
    }

    List<Color> bubbleColors = [
      Theme.of(context).accentColor,
      Theme.of(context).accentColor
    ];
    if (SettingsManager().settings.colorfulBubbles) {
      bubbleColors = toColorGradient(message?.handle?.address);
    }

    return Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        if (widget.showTail)
          MessageTail(message: message, color: bubbleColors[0]),
        Container(
          margin: EdgeInsets.only(
            top: widget.message.getReactions().length > 0 &&
                    !widget.message.hasAttachments
                ? 18
                : 0,
            left: 10,
            right: 10,
          ),
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.of(context).size.width * MessageWidgetMixin.MAX_SIZE,
          ),
          padding: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: AlignmentDirectional.bottomCenter,
              end: AlignmentDirectional.topCenter,
              colors: bubbleColors,
            ),
          ),
          child: RichText(
            text: TextSpan(
              children:
                  MessageWidgetMixin.buildMessageSpans(context, widget.message),
              style: Theme.of(context).textTheme.bodyText2,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message == null) return Container();

    // The column that holds all the "messages"
    List<Widget> messageColumn = [];

    // First, add the message sender (if applicable)
    if (CurrentChat.of(context).chat.isGroup() &&
        (!sameSender(widget.message, widget.olderMessage) ||
            !widget.message.dateCreated
                .isWithin(widget.olderMessage.dateCreated, minutes: 30))) {
      messageColumn.add(
        Padding(
          padding: EdgeInsets.only(
              left: 15.0,
              top: 5.0,
              bottom: widget.message.getReactions().length > 0 ? 0.0 : 3.0),
          child: Text(
            contactTitle,
            style: Theme.of(context).textTheme.subtitle1,
          ),
        ),
      );
    }

    // Second, add the attachments
    if (widget.message.getRealAttachments().length > 0) {
      messageColumn.add(
        addStickersToWidget(
          message: addReactionsToWidget(
              messageWidget: widget.attachmentsWidget,
              reactions: widget.reactionsWidget,
              message: widget.message,
              shouldShow: widget.message.hasAttachments),
          stickers: widget.stickersWidget,
          isFromMe: widget.message.isFromMe,
        ),
      );
    }

    // Third, let's add the actual message we want to show
    Widget message;
    if (widget.message.isUrlPreview()) {
      message = Padding(
        padding: EdgeInsets.only(left: 10.0),
        child: widget.urlPreviewWidget,
      );
    } else if (widget.message.isInteractive()) {
      message = Padding(
          padding: EdgeInsets.only(left: 10.0),
          child: BalloonBundleWidget(message: widget.message));
    } else if (widget.message.hasText()) {
      message = _buildMessageWithTail(widget.message);
    }

    // Fourth, let's add any reactions or stickers to the widget
    if (message != null) {
      messageColumn.add(
        addStickersToWidget(
          message: addReactionsToWidget(
              messageWidget: message,
              reactions: widget.reactionsWidget,
              message: widget.message,
              shouldShow: widget.message.getRealAttachments().isEmpty),
          stickers: widget.stickersWidget,
          isFromMe: widget.message.isFromMe,
        ),
      );
    }

    // Now, let's create a row that will be the row with the following:
    // -> Contact avatar
    // -> Message
    List<Widget> msgRow = [];
    if (widget.showTail && CurrentChat.of(context).chat.isGroup()) {
      msgRow.add(
        Padding(
          padding: EdgeInsets.only(
            left: 5.0,
          ),
          child: ContactAvatarWidget(
            handle: widget.message.handle,
            size: 30,
            fontSize: 14,
            borderThickness: 0.1,
          ),
        ),
      );
    }

    // Add the message column to the row
    msgRow.add(
      Padding(
        // Padding to shift the bubble up a bit, relative to the avatar
        padding: EdgeInsets.only(bottom: widget.showTail ? 0.0 : 5.0),
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
          left: (!widget.showTail &&
                  (CurrentChat.of(context).chat.isGroup() || widget.isGroup))
              ? 35.0
              : 0.0,
          bottom: (widget.showTail) ? 10.0 : 0.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MessagePopupHolder(
            message: widget.message,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: msgRow,
            ),
          ),
          MessageTimeStamp(
            message: widget.message,
          )
        ],
      ),
    );
  }
}
