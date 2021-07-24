import 'dart:ui';

import 'package:bluebubbles/layouts/setup/theme_selector/theme_selector.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/delivered_receipt.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/balloon_bundle_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_popup_holder.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SentMessageHelper {
  static Widget buildMessageWithTail(
      BuildContext context, Message? message, bool showTail, bool hasReactions, bool bigEmoji,
      {Widget? customContent,
      Message? olderMessage,
      CurrentChat? currentChat,
      Color? customColor,
      bool padding = true,
      bool margin = true}) {
    Color bubbleColor;
    bubbleColor = message == null || message.guid!.startsWith("temp")
        ? Theme.of(context).primaryColor.darkenAmount(0.2)
        : Theme.of(context).primaryColor;

    final bool hideContent = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideEmojis.value;

    Widget msg;
    bool hasReactions = (message?.getReactions() ?? []).length > 0;
    Skins currentSkin = Skin.of(context)?.skin ?? SettingsManager().settings.skin.value;

    if (message?.isBigEmoji() ?? false) {
      msg = Padding(
        padding: EdgeInsets.only(
          left: (hasReactions) ? 15.0 : 0.0,
          top: (hasReactions) ? 15.0 : 0.0,
          right: 5,
        ),
        child: hideContent
            ? ClipRRect(
                borderRadius: BorderRadius.circular(25.0),
                child: Container(
                    width: 70,
                    height: 70,
                    color: Theme.of(context).accentColor,
                    child: Center(
                      child: Text(
                        "emoji",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                    )),
              )
            : Text(
                message!.text!,
                style: Theme.of(context).textTheme.bodyText2!.apply(fontSizeFactor: 4),
              ),
      );
    } else {
      msg = Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          if (showTail && currentSkin == Skins.iOS && message != null)
            MessageTail(
              isFromMe: true,
              color: customColor ?? bubbleColor,
            ),
          Container(
            margin: EdgeInsets.only(
              top: hasReactions && margin ? 18 : 0,
              left: margin ? 10 : 0,
              right: margin ? 10 : 0,
            ),
            constraints: BoxConstraints(
              maxWidth: context.width * MessageWidgetMixin.MAX_SIZE + (!padding ? 100 : 0),
            ),
            padding: EdgeInsets.symmetric(
              vertical: padding ? 8 : 0,
              horizontal: padding ? 14 : 0,
            ),
            decoration: BoxDecoration(
              borderRadius: currentSkin == Skins.iOS
                  ? BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(17),
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    )
                  : (currentSkin == Skins.Material)
                      ? BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: olderMessage == null || MessageHelper.getShowTail(context, olderMessage, message)
                              ? Radius.circular(20)
                              : Radius.circular(5),
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(showTail ? 20 : 5),
                        )
                      : (currentSkin == Skins.Samsung)
                          ? BorderRadius.only(
                              topLeft: Radius.circular(17.5),
                              topRight: Radius.circular(17.5),
                              bottomRight: Radius.circular(17.5),
                              bottomLeft: Radius.circular(17.5),
                            )
                          : null,
              color: customColor ?? bubbleColor,
            ),
            child: customContent == null
                ? RichText(
                    text: TextSpan(
                      children: MessageWidgetMixin.buildMessageSpans(context, message),
                      style: Theme.of(context).textTheme.bodyText1!.apply(color: Colors.white),
                    ),
                  )
                : customContent,
          ),
        ],
      );
    }

    if (!padding) return msg;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        msg,
        getErrorWidget(
          context,
          message,
          currentChat != null ? currentChat.chat : CurrentChat.of(context)?.chat,
        ),
      ],
    );
  }

  static Widget getErrorWidget(BuildContext context, Message? message, Chat? chat, {double rightPadding = 8.0}) {
    if (message != null && message.error! > 0) {
      int? errorCode = message.error != null ? message.error : 0;
      String errorText = "Server Error. Contact Support.";
      if (errorCode == 22) {
        errorText = "The recipient is not registered with iMessage!";
      } else if (message.guid!.startsWith("error-")) {
        errorText = message.guid!.split('-')[1];
      }

      return Padding(
        padding: EdgeInsets.only(right: rightPadding),
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: new Text("Message failed to send", style: TextStyle(color: Colors.black)),
                  content: new Text("Error ($errorCode): $errorText"),
                  actions: <Widget>[
                    new TextButton(
                      child: new Text("Retry"),
                      onPressed: () {
                        // Remove the OG alert dialog
                        Navigator.of(context).pop();
                        NotificationManager().clearFailedToSend();
                        ActionHandler.retryMessage(message);
                      },
                    ),
                    if (chat != null)
                      new TextButton(
                        child: new Text("Remove"),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          // Delete the message from the DB
                          await Message.softDelete({'guid': message.guid});

                          // Remove the message from the Bloc
                          NewMessageManager().removeMessage(chat, message.guid);
                          NotificationManager().clearFailedToSend();
                          // Get the "new" latest info
                          List<Message> latest = await Chat.getMessages(chat, limit: 1);
                          chat.latestMessageDate = latest.first.dateCreated;
                          chat.latestMessageText = await MessageHelper.getNotificationText(latest.first);

                          // Update it in the Bloc
                          await ChatBloc().updateChatPosition(chat);
                        },
                      ),
                    new TextButton(
                      child: new Text("Cancel"),
                      onPressed: () {
                        Navigator.of(context).pop();
                        NotificationManager().clearFailedToSend();
                      },
                    )
                  ],
                );
              },
            );
          },
          child: Icon(Icons.error_outline, color: Colors.red),
        ),
      );
    }
    return Container();
  }
}

class SentMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final Message? olderMessage;
  final Message? newerMessage;
  final bool showHero;
  final bool shouldFadeIn;
  final bool showDeliveredReceipt;

  // Sub-widgets
  final Widget stickersWidget;
  final Widget attachmentsWidget;
  final Widget reactionsWidget;
  final Widget urlPreviewWidget;

  SentMessage({
    Key? key,
    required this.showTail,
    required this.olderMessage,
    required this.newerMessage,
    required this.message,
    required this.showHero,
    required this.showDeliveredReceipt,
    required this.shouldFadeIn,

    // Sub-widgets
    required this.stickersWidget,
    required this.attachmentsWidget,
    required this.reactionsWidget,
    required this.urlPreviewWidget,
  }) : super(key: key);

  @override
  _SentMessageState createState() => _SentMessageState();
}

class _SentMessageState extends State<SentMessage> with TickerProviderStateMixin, MessageWidgetMixin {
  Rx<Skins> skin = Rx<Skins>(SettingsManager().settings.skin.value);

  @override
  void initState() {
    super.initState();
    initMessageState(widget.message, false);
  }

  @override
  Widget build(BuildContext context) {
    if (Skin.of(context) != null) {
      skin.value = Skin.of(context)!.skin;
    }
    // The column that holds all the "messages"
    List<Widget> messageColumn = [];

    // Second, add the attachments
    if (isEmptyString(widget.message.fullText)) {
      messageColumn.add(
        addStickersToWidget(
          message: addReactionsToWidget(
              messageWidget: widget.attachmentsWidget, reactions: widget.reactionsWidget, message: widget.message),
          stickers: widget.stickersWidget,
          isFromMe: widget.message.isFromMe!,
        ),
      );
    } else {
      messageColumn.add(widget.attachmentsWidget);
    }

    // Third, let's add the message or URL preview
    Widget? message;
    if (widget.message.isUrlPreview()) {
      message = Padding(
        padding: EdgeInsets.only(left: 10.0),
        child: widget.urlPreviewWidget,
      );
    } else if (widget.message.balloonBundleId != null &&
        widget.message.balloonBundleId != 'com.apple.messages.URLBalloonProvider') {
      message = BalloonBundleWidget(message: widget.message);
    } else if (!isEmptyString(widget.message.text)) {
      message = SentMessageHelper.buildMessageWithTail(
          context, widget.message, widget.showTail, widget.message.hasReactions, widget.message.bigEmoji ?? false,
          olderMessage: widget.olderMessage);
      if (widget.showHero) {
        message = Hero(
          tag: "first",
          child: Material(
            type: MaterialType.transparency,
            child: message,
          ),
        );
      }
    }

    // Fourth, let's add any reactions or stickers to the widget
    if (message != null) {
      messageColumn.add(
        addStickersToWidget(
          message: addReactionsToWidget(
              messageWidget: Padding(
                padding: EdgeInsets.only(bottom: widget.showTail ? 2.0 : 0),
                child: message,
              ),
              reactions: widget.reactionsWidget,
              message: widget.message),
          stickers: widget.stickersWidget,
          isFromMe: widget.message.isFromMe!,
        ),
      );
    }
    messageColumn.add(
      DeliveredReceipt(
        message: widget.message,
        showDeliveredReceipt: widget.showDeliveredReceipt,
        shouldAnimate: widget.shouldFadeIn,
      ),
    );

    // Now, let's create a row that will be the row with the following:
    // -> Contact avatar
    // -> Message
    List<Widget> msgRow = [];

    // Add the message column to the row
    msgRow.add(
      Padding(
        // Padding to shift the bubble up a bit, relative to the avatar
        padding: EdgeInsets.only(
            top: (skin.value != Skins.iOS &&
                    widget.message.isFromMe == widget.olderMessage?.isFromMe)
                ? (skin.value != Skins.iOS)
                    ? 0
                    : 3
                : (skin.value == Skins.iOS)
                    ? 0.0
                    : 10,
            bottom: (skin.value == Skins.iOS &&
                    widget.showTail &&
                    !isEmptyString(widget.message.fullText))
                ? 5.0
                : 0,
            right: isEmptyString(widget.message.fullText) && widget.message.error == 0 ? 10.0 : 0.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: messageColumn,
        ),
      ),
    );

    // Finally, create a container row so we can have the swipe timestamp
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment:
          (skin.value == Skins.iOS) ? CrossAxisAlignment.center : CrossAxisAlignment.end,
      children: [
        if (skin.value == Skins.iOS ||
            skin.value == Skins.Material)
          MessagePopupHolder(
            message: widget.message,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: msgRow,
            ),
          ),
        if (skin.value == Skins.Samsung)
          MessagePopupHolder(
            message: widget.message,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: msgRow,
            ),
          ),
        if (skin.value != Skins.Samsung && widget.message.guid != widget.olderMessage?.guid)
          MessageTimeStamp(
            message: widget.message,
          )
      ],
    );
  }
}
