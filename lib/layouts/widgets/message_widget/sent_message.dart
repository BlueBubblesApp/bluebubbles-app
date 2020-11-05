import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/delivered_receipt.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SentMessageHelper {
  static Widget buildMessageWithTail(BuildContext context, Message message,
      bool showTail, bool hasReactions, bool bigEmoji,
      {Widget customContent}) {
    Color blueColor;
    blueColor = message == null || message.guid.startsWith("temp")
        ? darken(Colors.blue[600], 0.2)
        : Colors.blue[600];

    Widget msg;
    if (bigEmoji) {
      msg = Padding(
          padding: EdgeInsets.only(
              left: (hasReactions) ? 15.0 : 0.0,
              top: (hasReactions) ? 15.0 : 0.0,
              right: 5),
          child: Text(message.text,
              style: Theme.of(context)
                  .textTheme
                  .bodyText1
                  .apply(fontSizeFactor: 4)));
    } else {
      msg = Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          if (showTail)
            MessageTail(
              isFromMe: true,
              blueColor: blueColor,
            ),
          Container(
            margin: EdgeInsets.only(
              top: hasReactions ? 18 : 0,
              left: 10,
              right: 10,
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width *
                      MessageWidgetMixin.maxSize +
                  (customContent != null ? 100 : 0),
            ),
            padding: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: blueColor,
            ),
            child: customContent == null
                ? RichText(
                    text: TextSpan(
                      children: MessageWidgetMixin.buildMessageSpans(
                          context, message),
                      style: Theme.of(context)
                          .textTheme
                          .bodyText1
                          .apply(color: Colors.white),
                    ),
                  )
                : customContent,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        msg,
        getErrorWidget(context, message, CurrentChat().chat),
      ],
    );
  }

  static Widget getErrorWidget(
      BuildContext context, Message message, Chat chat) {
    if (chat == null) return Container();
    if (message != null && message.error > 0) {
      int errorCode = message != null ? message.error : 0;
      String errorText = message != null ? message.guid.split('-')[1] : "";

      return Padding(
        padding: EdgeInsets.only(right: 8.0),
        child: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: new Text("Message failed to send",
                      style: TextStyle(color: Colors.black)),
                  content: new Text("Error ($errorCode): $errorText"),
                  actions: <Widget>[
                    new FlatButton(
                      child: new Text("Retry"),
                      onPressed: () {
                        // Remove the OG alert dialog
                        Navigator.of(context).pop();
                        ActionHandler.retryMessage(message);
                      },
                    ),
                    new FlatButton(
                      child: new Text("Remove"),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        // Delete the message from the DB
                        await Message.delete({'guid': message.guid});

                        // Remove the message from the Bloc
                        NewMessageManager().removeMessage(chat, message.guid);

                        // Get the "new" latest info
                        List<Message> latest =
                            await Chat.getMessages(chat, limit: 1);
                        chat.latestMessageDate = latest.first != null
                            ? latest.first.dateCreated
                            : null;
                        chat.latestMessageText = latest.first != null
                            ? await MessageHelper.getNotificationText(
                                latest.first)
                            : null;

                        // Update it in the Bloc
                        await ChatBloc().updateChatPosition(chat);
                      },
                    ),
                    new FlatButton(
                      child: new Text("Cancel"),
                      onPressed: () {
                        Navigator.of(context).pop();
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
  final double offset;
  final bool showTail;
  final Message message;
  final Message olderMessage;
  final bool showHero;
  final bool shouldFadeIn;
  final bool showDeliveredReceipt;
  final Chat chat;
  final bool hasReactions;
  final bool shouldShowBigEmoji;

  // Sub-widgets
  final Widget stickersWidget;
  final Widget attachmentsWidget;
  final Widget reactionsWidget;
  final Widget urlPreviewWidget;

  SentMessage({
    Key key,
    @required this.showTail,
    @required this.olderMessage,
    @required this.message,
    @required this.showHero,
    @required this.showDeliveredReceipt,
    @required this.hasReactions,
    @required this.shouldFadeIn,
    @required this.offset,
    @required this.chat,
    @required this.shouldShowBigEmoji,

    // Sub-widgets
    @required this.stickersWidget,
    @required this.attachmentsWidget,
    @required this.reactionsWidget,
    @required this.urlPreviewWidget,
  }) : super(key: key);

  @override
  _SentMessageState createState() => _SentMessageState();
}

class _SentMessageState extends State<SentMessage>
    with TickerProviderStateMixin, MessageWidgetMixin {
  @override
  void initState() {
    super.initState();
    initMessageState(widget.message, false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message == null) return Container();

    // The column that holds all the "messages"
    List<Widget> messageColumn = [];

    // Second, add the attachments
    if (isEmptyString(widget.message.text)) {
      messageColumn.add(
        addStickersToWidget(
          message: addReactionsToWidget(
              messageWidget: widget.attachmentsWidget,
              reactions: widget.reactionsWidget,
              message: widget.message),
          stickers: widget.stickersWidget,
          isFromMe: widget.message.isFromMe,
        ),
      );
    } else {
      messageColumn.add(widget.attachmentsWidget);
    }

    // Third, let's add the message or URL preview
    Widget message;
    if (widget.message.hasDdResults && this.hasHyperlinks) {
      message = Padding(
        padding: EdgeInsets.only(left: 10.0),
        child: widget.urlPreviewWidget,
      );
    } else if (!isEmptyString(widget.message.text)) {
      message = SentMessageHelper.buildMessageWithTail(
        context,
        widget.message,
        widget.showTail,
        widget.hasReactions,
        widget.shouldShowBigEmoji,
      );
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
          isFromMe: widget.message.isFromMe,
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
            bottom: (widget.showTail && !isEmptyString(widget.message.text))
                ? 5.0
                : 3.0,
            right: isEmptyString(widget.message.text) ? 10.0 : 0.0),
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
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: msgRow,
        ),
        MessageTimeStamp(
          message: widget.message,
          offset: widget.offset,
        )
      ],
    );
  }
}

// class ActualSentMessage extends StatefulWidget {
//   ActualSentMessage({
//     Key key,
//     @required this.blueColor,
//     @required this.showTail,
//     @required this.message,
//     @required this.chat,
//     @required this.customContent,
//     @required this.textSpans,
//     @required this.createErrorPopup,
//     this.constrained,
//   }) : super(key: key);
//   final Color blueColor;
//   final bool showTail;
//   final Message message;
//   final Chat chat;
//   final List<Widget> customContent;
//   final List<InlineSpan> textSpans;
//   final Function() createErrorPopup;
//   final bool constrained;

//   @override
//   _ActualSentMessageState createState() => _ActualSentMessageState();
// }

// class _ActualSentMessageState extends State<ActualSentMessage> {
//   @override
//   Widget build(BuildContext context) {
//     List<Widget> tail = <Widget>[
//       Container(
//         margin: EdgeInsets.only(bottom: 1),
//         width: 20,
//         height: 15,
//         decoration: BoxDecoration(
//           color: widget.blueColor,
//           borderRadius: BorderRadius.only(
//             bottomLeft: Radius.circular(12),
//           ),
//         ),
//       ),
//       Container(
//         margin: EdgeInsets.only(bottom: 2),
//         height: 28,
//         width: 11,
//         decoration: BoxDecoration(
//           color: Theme.of(context).backgroundColor,
//           borderRadius: BorderRadius.only(
//             bottomLeft: Radius.circular(8),
//           ),
//         ),
//       ),
//     ];

//     List<Widget> stack = <Widget>[
//       Container(
//         height: 30,
//         width: 6,
//         color: Theme.of(context).backgroundColor,
//       ),
//     ];
//     if (widget.showTail) {
//       stack.insertAll(0, tail);
//     }

//     List<Widget> messageWidget = [
//       widget.message == null || !isEmptyString(widget.message.text)
//           ? Stack(
//               alignment: AlignmentDirectional.bottomEnd,
//               children: <Widget>[
//                 Stack(
//                   alignment: AlignmentDirectional.bottomEnd,
//                   children: stack,
//                 ),
//                 Container(
//                   margin: EdgeInsets.symmetric(
//                     horizontal: 10,
//                   ),
//                   constraints: BoxConstraints(
//                     maxWidth: widget.constrained == null
//                         ? MediaQuery.of(context).size.width * 3 / 4
//                         : MediaQuery.of(context).size.width * 3 / 4 + 37,
//                   ),
//                   padding: EdgeInsets.symmetric(
//                     vertical: 8,
//                     horizontal: 14,
//                   ),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(20),
//                     color: widget.blueColor,
//                   ),
//                   child: widget.customContent == null
//                       ? Container(
//                           child: RichText(
//                             text: TextSpan(
//                               children: widget.textSpans,
//                               style:
//                                   Theme.of(context).textTheme.bodyText2.apply(
//                                         color: Colors.white,
//                                       ),
//                             ),
//                           ),
//                         )
//                       : widget.customContent.first,
//                 ),
//               ],
//             )
//           : Container()
//     ];

//     if (widget.message != null && widget.message.error > 0) {
//       int errorCode = widget.message != null ? widget.message.error : 0;
//       String errorText =
//           widget.message != null ? widget.message.guid.split('-')[1] : "";

//       messageWidget.add(
//         GestureDetector(
//           onTap: () {
//             showDialog(
//               context: context,
//               builder: (BuildContext context) {
//                 return AlertDialog(
//                   title: new Text("Message failed to send",
//                       style: TextStyle(color: Colors.black)),
//                   content: new Text("Error ($errorCode): $errorText"),
//                   actions: <Widget>[
//                     new FlatButton(
//                       child: new Text("Retry"),
//                       onPressed: () {
//                         // Remove the OG alert dialog
//                         Navigator.of(context).pop();
//                         ActionHandler.retryMessage(widget.message);
//                       },
//                     ),
//                     new FlatButton(
//                       child: new Text("Remove"),
//                       onPressed: () async {
//                         Navigator.of(context).pop();
//                         // Delete the message from the DB
//                         await Message.delete({'guid': widget.message.guid});

//                         // Remove the message from the Bloc
//                         NewMessageManager()
//                             .removeMessage(widget.chat, widget.message.guid);

//                         // Get the "new" latest info
//                         List<Message> latest =
//                             await Chat.getMessages(widget.chat, limit: 1);
//                         widget.chat.latestMessageDate = latest.first != null
//                             ? latest.first.dateCreated
//                             : null;
//                         widget.chat.latestMessageText = latest.first != null
//                             ? await MessageHelper.getNotificationText(
//                                 latest.first)
//                             : null;

//                         // Update it in the Bloc
//                         await ChatBloc().updateChatPosition(widget.chat);
//                       },
//                     ),
//                     new FlatButton(
//                       child: new Text("Cancel"),
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                     )
//                   ],
//                 );
//               },
//             );
//           },
//           child: Icon(Icons.error_outline, color: Colors.red),
//         ),
//       );
//     }

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: messageWidget,
//     );
//   }
// }
