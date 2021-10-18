import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/layouts/setup/theme_selector/theme_selector.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reply_line_painter.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
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
import 'package:bluebubbles/helpers/darty.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SentMessageHelper {
  static Widget buildMessageWithTail(
      BuildContext context, Message? message, bool showTail, bool hasReactions, bool bigEmoji, Future<List<InlineSpan>> msgSpanFuture,
      {Widget? customContent,
      Message? olderMessage,
      CurrentChat? currentChat,
      Color? customColor,
      bool padding = true,
      bool margin = true,
      double? customWidth}) {
    Color bubbleColor;
    bubbleColor = message == null || message.guid!.startsWith("temp")
        ? Theme.of(context).primaryColor.darkenAmount(0.2)
        : Theme.of(context).primaryColor;

    final bool hideContent =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideEmojis.value;

    Widget msg;
    bool hasReactions = (message?.getReactions() ?? []).length > 0;
    Skins currentSkin = Skin.of(context)?.skin ?? SettingsManager().settings.skin.value;

    if (message?.isBigEmoji() ?? false) {
      // this stack is necessary for layouting width properly
      msg = Stack(alignment: AlignmentDirectional.bottomEnd, children: [
        LayoutBuilder(builder: (_, constraints) {
          return Container(
            width: customWidth != null ? constraints.maxWidth : null,
            child: Padding(
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
            ),
          );
        })
      ]);
    } else {
      msg = Stack(
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          if (showTail && currentSkin == Skins.iOS && message != null)
            MessageTail(
              isFromMe: true,
              color: customColor ?? bubbleColor,
            ),
          LayoutBuilder(builder: (_, constraints) {
            return Container(
              width: customWidth != null ? constraints.maxWidth : null,
              constraints: customWidth == null
                  ? BoxConstraints(
                      maxWidth: CustomNavigator.width(context) * MessageWidgetMixin.MAX_SIZE + (!padding ? 100 : 0),
                    )
                  : null,
              margin: EdgeInsets.only(
                top: hasReactions && margin ? 18 : 0,
                left: margin ? 10 : 0,
                right: margin ? 10 : 0,
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
                  ? FutureBuilder<List<InlineSpan>>(
                      future: msgSpanFuture,
                      builder: (context, snapshot) {
                        if (snapshot.data != null) {
                          return RichText(
                            text: TextSpan(
                              children: snapshot.data!,
                              style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
                            ),
                          );
                        }
                        return RichText(
                          text: TextSpan(
                            children: MessageWidgetMixin.buildMessageSpans(context, message),
                            style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
                          ),
                        );
                      }
                    )
                  : customContent,
            );
          }),
        ],
      );
    }
    if (!padding) return msg;
    return Container(
        width: customWidth != null ? customWidth - (showTail ? 20 : 0) : null,
        constraints: BoxConstraints(
          maxWidth: customWidth != null ? customWidth - (showTail ? 20 : 0) : CustomNavigator.width(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customWidth != null) Expanded(child: msg),
            if (customWidth == null) msg,
            getErrorWidget(
              context,
              message,
              currentChat != null ? currentChat.chat : CurrentChat.of(context)?.chat,
            ),
          ],
        ));
  }

  static Widget getErrorWidget(BuildContext context, Message? message, Chat? chat, {double rightPadding = 8.0}) {
    if (message != null && message.error.value > 0) {
      int errorCode = message.error.value;
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
                    if (chat != null)
                      new TextButton(
                        child: new Text("Retry"),
                        onPressed: () async {
                          // Remove the OG alert dialog
                          Navigator.of(context).pop();
                          NewMessageManager().removeMessage(chat, message.guid);
                          await Message.softDelete({'guid': message.guid});
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
                          chat.latestMessage = latest.first;
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
          child: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.exclamationmark_circle : Icons.error_outline, color: Colors.red),
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
  final MessageBloc? messageBloc;
  final bool hasTimestampAbove;
  final bool hasTimestampBelow;
  final bool showReplies;

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
    required this.messageBloc,
    required this.hasTimestampAbove,
    required this.hasTimestampBelow,
    required this.showReplies,

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
  final Rx<Skins> skin = Rx<Skins>(SettingsManager().settings.skin.value);
  late final spanFuture = MessageWidgetMixin.buildMessageSpansAsync(context, widget.message);
  Size? threadOriginatorSize;
  Size? messageSize;

  @override
  void initState() {
    super.initState();
    initMessageState(widget.message, false);
  }

  List<Color> getBubbleColors(Message message) {
    List<Color> bubbleColors = message.isFromMe ?? false ? [Theme
        .of(context)
        .primaryColor, Theme
        .of(context)
        .primaryColor
    ] : [Theme
        .of(context)
        .accentColor, Theme
        .of(context)
        .accentColor
    ];
    if (SettingsManager().settings.colorfulBubbles.value && !message.isFromMe!) {
      if (message.handle?.color == null) {
        bubbleColors = toColorGradient(message.handle?.address);
      } else {
        bubbleColors = [
          HexColor(message.handle!.color!),
          HexColor(message.handle!.color!).lightenAmount(0.02),
        ];
      }
    }
    return bubbleColors;
  }

  @override
  Widget build(BuildContext context) {
    if (Skin.of(context) != null) {
      skin.value = Skin.of(context)!.skin;
    }
    // The column that holds all the "messages"
    List<Widget> messageColumn = [];

    final msg = widget.message.associatedMessages.firstWhereOrNull((e) => e.guid == widget.message.threadOriginatorGuid);
    if (widget.message.threadOriginatorGuid != null && widget.showReplies) {
      if (msg != null && widget.olderMessage?.guid != msg.guid && widget.olderMessage?.threadOriginatorGuid != widget.message.threadOriginatorGuid) {
        messageColumn.add(GestureDetector(
          onTap: () {
            List<Message> _messages = [];
            if (widget.message.threadOriginatorGuid != null) {
              _messages = widget.messageBloc?.messages.values.where((e) => e.threadOriginatorGuid == widget.message.threadOriginatorGuid || e.guid == widget.message.threadOriginatorGuid).toList() ?? [];
            } else {
              _messages = widget.messageBloc?.messages.values.where((e) => e.threadOriginatorGuid == widget.message.guid || e.guid == widget.message.guid).toList() ?? [];
            }
            _messages.sort((a, b) => a.id!.compareTo(b.id!));
            _messages.sort((a, b) => a.dateCreated!.compareTo(b.dateCreated!));
            Navigator.push(
              context,
              PageRouteBuilder(
                settings: RouteSettings(arguments: {"hideTail": true}),
                transitionDuration: Duration(milliseconds: 150),
                pageBuilder: (context, animation, secondaryAnimation) {
                  return FadeTransition(
                    opacity: animation,
                    child: GestureDetector(
                      onTap: () {
                        Get.back();
                      },
                      child: AbsorbPointer(
                        absorbing: true,
                        child: AnnotatedRegion<SystemUiOverlayStyle>(
                          value: SystemUiOverlayStyle(
                            systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
                            systemNavigationBarIconBrightness:
                            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
                            statusBarColor: Colors.transparent, // status bar color
                          ),
                          child: Scaffold(
                            backgroundColor: context.theme.backgroundColor,
                            body: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: CustomScrollView(
                                  slivers: [
                                    SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                          Message? olderMessage;
                                          Message? newerMessage;
                                          if (index + 1 >= 0 && index + 1 < _messages.length) {
                                            olderMessage = _messages[index + 1];
                                          }
                                          if (index - 1 >= 0 && index - 1 < _messages.length) {
                                            newerMessage = _messages[index - 1];
                                          }

                                          return Padding(
                                              padding: EdgeInsets.only(left: 5.0, right: 5.0),
                                              child: MessageWidget(
                                                key: Key(_messages[index].guid!),
                                                message: _messages[index],
                                                olderOlderMessage: null,
                                                olderMessage: null,
                                                newerMessage: null,
                                                showHandle: true,
                                                isFirstSentMessage: widget.messageBloc!.firstSentMessage == _messages[index].guid,
                                                showHero: false,
                                                showReplies: false,
                                                bloc: widget.messageBloc!,
                                              ));
                                        },
                                        childCount: _messages.length,
                                      ),
                                    ),
                                  ]
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  );
                },
                fullscreenDialog: true,
                opaque: false,
              ),
            );
          },
          child: SizedBox(
            width: CustomNavigator.width(context) - 10,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: msg.isFromMe ?? false ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if ((CurrentChat.of(context)?.chat.isGroup() ?? false) && !msg.isFromMe!)
                    Padding(
                      padding: EdgeInsets.only(top: 5, left: 6),
                      child: ContactAvatarWidget(
                        handle: msg.handle,
                        size: 25,
                        fontSize: 10,
                        borderThickness: 0.1,
                      ),
                    ),
                  Stack(
                    alignment: AlignmentDirectional.bottomStart,
                    children: [
                      if (skin.value == Skins.iOS)
                        MessageTail(
                          isFromMe: false,
                          color: getBubbleColors(msg)[0],
                          isReply: true,
                        ),
                      Container(
                        margin: EdgeInsets.only(
                          left: 6,
                          right: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: CustomNavigator.width(context) * MessageWidgetMixin.MAX_SIZE - 30,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: getBubbleColors(msg)[0]),
                          borderRadius: skin.value == Skins.iOS
                              ? BorderRadius.only(
                            bottomLeft: Radius.circular(17),
                            bottomRight: Radius.circular(20),
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          )
                              : (skin.value == Skins.Material)
                              ? BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                          )
                              : (skin.value == Skins.Samsung)
                              ? BorderRadius.only(
                            topLeft: Radius.circular(17.5),
                            topRight: Radius.circular(17.5),
                            bottomRight: Radius.circular(17.5),
                            bottomLeft: Radius.circular(17.5),
                          )
                              : null,
                        ),
                        child: FutureBuilder<List<InlineSpan>>(
                            future: MessageWidgetMixin.buildMessageSpansAsync(context, msg, colorOverride: getBubbleColors(msg)[0].lightenOrDarken(30)),
                            builder: (context, snapshot) {
                              if (snapshot.data != null) {
                                return RichText(
                                  text: TextSpan(
                                    children: snapshot.data!,
                                  ),
                                );
                              }
                              return RichText(
                                text: TextSpan(
                                  children: MessageWidgetMixin.buildMessageSpans(context, msg,
                                      colorOverride: getBubbleColors(msg)[0].lightenOrDarken(30)),
                                ),
                              );
                            }
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ));
      }
    }

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
    if (widget.message.balloonBundleId != null &&
        widget.message.balloonBundleId != 'com.apple.messages.URLBalloonProvider') {
      message = BalloonBundleWidget(message: widget.message);
    } else if (!isEmptyString(widget.message.text) || !isEmptyString(widget.message.subject ?? "")) {
      message = SentMessageHelper.buildMessageWithTail(
          context, widget.message, widget.showTail, widget.message.hasReactions, widget.message.bigEmoji ?? false, spanFuture,
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
      if (widget.message.fullText.replaceAll("\n", " ").hasUrl) {
        message = widget.message.fullText.isURL ? Padding(
          padding: EdgeInsets.only(right: 5.0),
          child: widget.urlPreviewWidget,
        ) : Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Padding(
                padding: EdgeInsets.only(right: 5.0),
                child: widget.urlPreviewWidget,
              ),
              message,
        ]);
      }
    }

    // Fourth, let's add any reactions or stickers to the widget
    if (message != null) {
      // only draw the reply line if it will connect up or down
      if (widget.showReplies
          && msg != null
          && (widget.message.shouldConnectLower(widget.olderMessage, widget.newerMessage, msg)
              || widget.message.shouldConnectUpper(widget.olderMessage, msg))) {
        // get the correct size for the message being replied to
        if (widget.message.upperIsThreadOriginatorBubble(widget.olderMessage)) {
          threadOriginatorSize ??= msg.getBubbleSize(context);
        } else {
          threadOriginatorSize ??= widget.olderMessage?.getBubbleSize(context);
        }
        messageSize ??= widget.message.getBubbleSize(context);
        messageColumn.add(
          Container(
            width: CustomNavigator.width(context) - 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                      // add extra padding when showing contact avatars
                      left: (CurrentChat.of(context)?.chat.isGroup() ?? false)
                          || SettingsManager().settings.alwaysShowAvatars.value ? 75 : 40,
                  ),
                  child: Container(
                      // to make sure the bounds do not overflow, and so we
                      // dont draw an ugly long line)
                      width: min(CustomNavigator.width(context) - messageSize!.width - 150, CustomNavigator.width(context) / 3),
                      height: messageSize!.height / 2,
                      child: CustomPaint(
                        painter: LinePainter(
                            context,
                            widget.message,
                            widget.olderMessage,
                            widget.newerMessage,
                            msg,
                            threadOriginatorSize!,
                            messageSize!,
                            widget.olderMessage?.threadOriginatorGuid == widget.message.threadOriginatorGuid
                                && widget.hasTimestampAbove,
                            widget.hasTimestampBelow,
                            false,
                          )
                      )
                  ),
                ),
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
              ],
            ),
          ),
        );
      } else {
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
    }
    messageColumn.add(
      Obx(() {
        final list = widget.messageBloc?.threadOriginators.values.where((e) => e == widget.message.guid) ?? [];
        if (list.isNotEmpty) {
          return GestureDetector(
            onTap: () {
              List<Message> _messages = [];
              if (widget.message.threadOriginatorGuid != null) {
                _messages = widget.messageBloc?.messages.values.where((e) => e.threadOriginatorGuid == widget.message.threadOriginatorGuid || e.guid == widget.message.threadOriginatorGuid).toList() ?? [];
              } else {
                _messages = widget.messageBloc?.messages.values.where((e) => e.threadOriginatorGuid == widget.message.guid || e.guid == widget.message.guid).toList() ?? [];
              }
              _messages.sort((a, b) => a.id!.compareTo(b.id!));
              _messages.sort((a, b) => a.dateCreated!.compareTo(b.dateCreated!));
              Navigator.push(
                context,
                PageRouteBuilder(
                  settings: RouteSettings(arguments: {"hideTail": true}),
                  transitionDuration: Duration(milliseconds: 150),
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return FadeTransition(
                        opacity: animation,
                        child: GestureDetector(
                          onTap: () {
                            Get.back();
                          },
                          child: AbsorbPointer(
                            absorbing: true,
                            child: AnnotatedRegion<SystemUiOverlayStyle>(
                              value: SystemUiOverlayStyle(
                                systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
                                systemNavigationBarIconBrightness:
                                Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
                                statusBarColor: Colors.transparent, // status bar color
                              ),
                              child: Scaffold(
                                backgroundColor: context.theme.backgroundColor,
                                body: SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: CustomScrollView(
                                        slivers: [
                                          SliverList(
                                            delegate: SliverChildBuilderDelegate(
                                                  (context, index) {
                                                Message? olderMessage;
                                                Message? newerMessage;
                                                if (index + 1 >= 0 && index + 1 < _messages.length) {
                                                  olderMessage = _messages[index + 1];
                                                }
                                                if (index - 1 >= 0 && index - 1 < _messages.length) {
                                                  newerMessage = _messages[index - 1];
                                                }

                                                return Padding(
                                                    padding: EdgeInsets.only(left: 5.0, right: 5.0),
                                                    child: MessageWidget(
                                                      key: Key(_messages[index].guid!),
                                                      message: _messages[index],
                                                      olderOlderMessage: null,
                                                      olderMessage: null,
                                                      newerMessage: null,
                                                      showHandle: true,
                                                      isFirstSentMessage: widget.messageBloc!.firstSentMessage == _messages[index].guid,
                                                      showHero: false,
                                                      showReplies: false,
                                                      bloc: widget.messageBloc!,
                                                    ));
                                              },
                                              childCount: _messages.length,
                                            ),
                                          ),
                                        ]
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                    );
                  },
                  fullscreenDialog: true,
                  opaque: false,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 18.0, top: 2, bottom: 4),
              child: Text(
                "${list.length} Repl${list.length > 1 ? "ies" : "y"}",
                style: Theme.of(context).textTheme.subtitle2!.copyWith(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
          );
        } else {
          return DeliveredReceipt(
            message: widget.message,
            showDeliveredReceipt: widget.showDeliveredReceipt,
            shouldAnimate: widget.shouldFadeIn,
          );
        }
      })
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
            top: (skin.value != Skins.iOS && widget.message.isFromMe == widget.olderMessage?.isFromMe)
                ? (skin.value != Skins.iOS)
                    ? 0
                    : 3
                : (skin.value == Skins.iOS)
                    ? 0.0
                    : 10,
            bottom: (skin.value == Skins.iOS && widget.showTail && !isEmptyString(widget.message.fullText)) ? 5.0 : 0,
            right: isEmptyString(widget.message.fullText) && widget.message.error.value == 0 ? 10.0 : 0.0),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MessagePopupHolder(
          message: widget.message,
          olderMessage: widget.olderMessage,
          newerMessage: widget.newerMessage,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: msgRow,
          ),
          popupChild: Row(
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