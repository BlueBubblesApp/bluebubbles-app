import 'package:get/get.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/redacted_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/balloon_bundle_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_popup_holder.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/material.dart';

class ReceivedMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final Message olderMessage;
  final Message newerMessage;
  final bool showHandle;

  // Sub-widgets
  final Widget stickersWidget;
  final Widget attachmentsWidget;
  final Widget reactionsWidget;
  final Widget urlPreviewWidget;

  ReceivedMessage({
    Key key,
    @required this.showTail,
    @required this.olderMessage,
    @required this.newerMessage,
    @required this.message,
    @required this.showHandle,

    // Sub-widgets
    @required this.stickersWidget,
    @required this.attachmentsWidget,
    @required this.reactionsWidget,
    @required this.urlPreviewWidget,
  }) : super(key: key);

  @override
  _ReceivedMessageState createState() => _ReceivedMessageState();
}

class _ReceivedMessageState extends State<ReceivedMessage> with MessageWidgetMixin {
  bool checkedHandle = false;

  @override
  initState() {
    super.initState();
    initMessageState(widget.message, widget.showHandle).then((value) => {if (this.mounted) setState(() {})});

    // We need this here, or else messages without an avatar may not change.
    // Even if it fits the criteria
    ContactManager().colorStream.listen((event) {
      if (!event.containsKey(widget?.message?.handle?.address)) return;

      Color color = event[widget?.message?.handle?.address];
      if (color == null) {
        widget.message.handle.color = null;
      } else {
        widget.message.handle.color = color.value.toRadixString(16);
      }

      if (this.mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    didChangeMessageDependencies(widget.message, widget.showHandle);
  }

  Future<void> didChangeMessageDependencies(Message message, bool showHandle) async {
    await getContactTitle(message, showHandle);
    // await fetchAvatar(message);
    if (this.mounted) setState(() {});
  }

  /// Builds the message bubble with teh tail (if applicable)
  Widget _buildMessageWithTail(Message message) {
    if (message.isBigEmoji()) {
      final bool hideContent = SettingsManager().settings.redactedMode && SettingsManager().settings.hideMessageContent;
      final bool hideType = SettingsManager().settings.redactedMode && SettingsManager().settings.hideAttachmentTypes;

      bool hasReactions = (message?.getReactions() ?? []).length > 0 ?? false;
      return Padding(
        padding: EdgeInsets.only(
          left: CurrentChat.of(context).chat.participants.length > 1 ? 5.0 : 0.0,
          right: (hasReactions) ? 15.0 : 0.0,
          top: widget.message.getReactions().length > 0 ? 15 : 0,
        ),
        child: Stack(
          children: <Widget>[
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyText2.apply(fontSizeFactor: 4),
            ),
            if (hideContent)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25.0),
                  child: Container(color: Theme.of(context).accentColor),
                ),
              ),
            if (hideContent && !hideType)
              Positioned.fill(
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    "emoji",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    List<Color> bubbleColors = [Theme.of(context).accentColor, Theme.of(context).accentColor];
    if (SettingsManager().settings.colorfulBubbles) {
      if (message?.handle?.color == null) {
        bubbleColors = toColorGradient(message?.handle?.address);
      } else {
        bubbleColors = [
          HexColor(message.handle.color),
          lighten(HexColor(message.handle.color), 0.02),
        ];
      }
    }

    return Stack(
      alignment: AlignmentDirectional.bottomStart,
      children: [
        if (widget.showTail && SettingsManager().settings.skin == Skins.iOS)
          MessageTail(
            message: message,
            color: bubbleColors[0],
          ),
        Container(
          margin: EdgeInsets.only(
            top: widget.message.getReactions().length > 0 && !widget.message.hasAttachments
                ? 18
                : (widget.message?.isFromMe != widget.olderMessage?.isFromMe)
                    ? 5.0
                    : 0,
            left: 10,
            right: 10,
          ),
          constraints: BoxConstraints(
            maxWidth: Get.mediaQuery.size.width * MessageWidgetMixin.MAX_SIZE,
          ),
          padding: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: SettingsManager().settings.skin == Skins.iOS
                ? BorderRadius.only(
                    bottomLeft: Radius.circular(17),
                    bottomRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  )
                : (SettingsManager().settings.skin == Skins.Material)
                    ? BorderRadius.only(
                        topLeft: widget.olderMessage == null ||
                                MessageHelper.getShowTail(widget.olderMessage, widget.message)
                            ? Radius.circular(20)
                            : Radius.circular(5),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(widget.showTail ? 20 : 5),
                      )
                    : (SettingsManager().settings.skin == Skins.Samsung)
                        ? BorderRadius.only(
                            topLeft: Radius.circular(17.5),
                            topRight: Radius.circular(17.5),
                            bottomRight: Radius.circular(17.5),
                            bottomLeft: Radius.circular(17.5),
                          )
                        : null,
            gradient: LinearGradient(
              begin: AlignmentDirectional.bottomCenter,
              end: AlignmentDirectional.topCenter,
              colors: bubbleColors,
            ),
          ),
          child: RichText(
            text: TextSpan(
              children: MessageWidgetMixin.buildMessageSpans(context, widget.message,
                  colors: widget.message?.handle?.color != null ? bubbleColors : null),
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
    bool isGroup = CurrentChat.of(context)?.chat?.isGroup() ?? false;
    if (isGroup &&
        (!sameSender(widget.message, widget.olderMessage) ||
            !widget.message.dateCreated.isWithin(widget.olderMessage.dateCreated, minutes: 30))) {
      messageColumn.add(
        Padding(
          padding: EdgeInsets.only(left: 15.0, top: 5.0, bottom: widget.message.getReactions().length > 0 ? 0.0 : 3.0),
          child: Text(getContactName(context, contactTitle, widget.message.handle.address),
              style: Theme.of(context).textTheme.subtitle1),
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
      message = Padding(padding: EdgeInsets.only(left: 10.0), child: BalloonBundleWidget(message: widget.message));
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
    if (widget.showTail && (isGroup || SettingsManager().settings.skin == Skins.Samsung)) {
      double topPadding = (isGroup) ? 5 : 0;
      if (SettingsManager().settings.skin == Skins.Samsung) {
        topPadding = 5.0;
        if (isGroup) topPadding += 18;
        if (widget.message.hasReactions) topPadding += 20;
      }

      msgRow.add(
        Padding(
          padding: EdgeInsets.only(left: 5.0, top: topPadding),
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
          top: (SettingsManager().settings.skin != Skins.iOS &&
                  widget.message?.isFromMe == widget.olderMessage?.isFromMe)
              ? 3.0
              : 0.0,
          left: (!widget.showTail && (isGroup || SettingsManager().settings.skin == Skins.Samsung)) ? 35.0 : 0.0,
          bottom: (widget.showTail && SettingsManager().settings.skin == Skins.iOS) ? 10.0 : 0.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment:
            (SettingsManager().settings.skin == Skins.iOS || SettingsManager().settings.skin == Skins.Material)
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
        crossAxisAlignment:
            (SettingsManager().settings.skin != Skins.Samsung) ? CrossAxisAlignment.center : CrossAxisAlignment.end,
        children: [
          MessagePopupHolder(
              message: widget.message,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: (SettingsManager().settings.skin == Skins.Samsung)
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: msgRow,
                ),
                // Add the timestamp for the samsung theme
                if (SettingsManager().settings.skin == Skins.Samsung &&
                    widget.message?.dateCreated != null &&
                    (widget.newerMessage?.dateCreated == null ||
                        widget.message?.isFromMe != widget.newerMessage?.isFromMe ||
                        widget.message?.handleId != widget.newerMessage?.handleId ||
                        !widget.message.dateCreated.isWithin(widget.newerMessage.dateCreated, minutes: 5)))
                  Padding(
                    padding: EdgeInsets.only(top: 5, left: (isGroup) ? 60 : 20),
                    child: MessageTimeStamp(
                      message: widget.message,
                      singleLine: true,
                      useYesterday: true,
                    ),
                  )
              ])),
          if ((SettingsManager().settings.skin != Skins.Samsung && widget.message?.guid != widget.olderMessage?.guid))
            MessageTimeStamp(
              message: widget.message,
            )
        ],
      ),
    );
  }
}
