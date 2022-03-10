import 'dart:math';

import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/setup/theme_selector/theme_selector.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/delivered_receipt.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/media_players/balloon_bundle_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_content/message_time_stamp.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_popup_holder.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reply_line_painter.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/show_reply_thread.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';

class SentMessageHelper {
  static Widget buildMessageWithTail(
    BuildContext context,
    Message? message,
    bool showTail,
    bool hasReactions,
    bool bigEmoji,
    Future<List<InlineSpan>> msgSpanFuture, {
    Widget? customContent,
    Message? olderMessage,
    ChatController? currentChat,
    Color? customColor,
    bool padding = true,
    bool margin = true,
    double? customWidth,
    MessageEffect effect = MessageEffect.none,
    CustomAnimationControl controller = CustomAnimationControl.stop,
    void Function()? updateController,
  }) {
    if (effect.isBubble) assert(updateController != null);
    Color bubbleColor;
    bubbleColor = message == null || message.guid!.startsWith("temp")
        ? Theme.of(context).primaryColor.darkenAmount(0.2)
        : Theme.of(context).primaryColor;

    final bool hideEmoji = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideEmojis.value;
    final bool generateContent =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeMessageContent.value;
    final bool hideContent = (SettingsManager().settings.redactedMode.value &&
        SettingsManager().settings.hideMessageContent.value &&
        !generateContent);
    final subject =
        generateContent ? faker.lorem.words(message?.subject?.split(" ").length ?? 0).join(" ") : message?.subject;
    final text = generateContent ? faker.lorem.words(message?.text?.split(" ").length ?? 0).join(" ") : message?.text;

    Widget msg;
    bool hasReactions = (message?.getReactions() ?? []).isNotEmpty;
    Skins currentSkin = Skin.of(context)?.skin ?? SettingsManager().settings.skin.value;
    Size bubbleSize = Size(0, 0);

    // If we haven't played the effect, we should apply it from the start.
    // This must come before we set the bubbleSize variable or else we get a box constraints errors
    if (message?.datePlayed == null && effect != MessageEffect.none) {
      controller = CustomAnimationControl.playFromStart;
      if (effect != MessageEffect.invisibleInk) {
        Timer(Duration(milliseconds: 500), () {
          if (message?.datePlayed == null && !(message?.guid?.contains("redacted-mode-demo") ?? false)) {
            message?.setPlayedDate();
          }
        });
      }
    }

    if (controller != CustomAnimationControl.stop) {
      bubbleSize = message!.getBubbleSize(context);
    }

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
              child: hideEmoji
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(25.0),
                      child: Container(
                          width: 70,
                          height: 70,
                          color: Theme.of(context).colorScheme.secondary,
                          child: Center(
                            child: Text(
                              "emoji",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                          )),
                    )
                  : RichText(
                  text: TextSpan(
                      children: MessageHelper.buildEmojiText(
                          message!.text!,
                          Theme.of(context)
                              .textTheme
                              .bodyText1!
                              .apply(fontSizeFactor: 4)))),
            ),
          );
        })
      ]);
    } else {
      Animatable<TimelineValue<String>>? tween;
      double opacity = 0;
      if (effect == MessageEffect.gentle && controller != CustomAnimationControl.stop) {
        tween = TimelineTween<String>()
          ..addScene(begin: Duration.zero, duration: const Duration(milliseconds: 500))
              .animate("size", tween: 0.5.tweenTo(0.5))
          ..addScene(
                  begin: Duration(milliseconds: 1000),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut)
              .animate("size", tween: 0.5.tweenTo(1.0));
        opacity = 1;
      } else if (controller != CustomAnimationControl.stop) {
        tween = TimelineTween<String>()
          ..addScene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
              .animate("size", tween: 1.0.tweenTo(1.0));
      }
      if (effect == MessageEffect.invisibleInk && controller != CustomAnimationControl.stop) {
        opacity = 1;
      }
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
                              topRight:
                                  olderMessage == null || MessageHelper.getShowTail(context, olderMessage, message)
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
                child: customContent ??
                    (effect.isBubble && controller != CustomAnimationControl.stop
                        ? CustomAnimation<TimelineValue<String>>(
                            control: controller,
                            tween: tween!,
                            duration: Duration(milliseconds: 1800),
                            builder: (context, child, anim) {
                              double value = anim.get("size");
                              return StatefulBuilder(builder: (context, setState) {
                                return GestureDetector(
                                  onHorizontalDragUpdate: (DragUpdateDetails details) {
                                    if (effect != MessageEffect.invisibleInk) return;
                                    if ((details.primaryDelta ?? 0).abs() > 1) {
                                      message?.setPlayedDate();
                                      setState(() {
                                        opacity = 1 - opacity;
                                      });
                                      updateController?.call();
                                    }
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Opacity(
                                        opacity: 1 - opacity,
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              if (!isNullOrEmpty(message!.subject)!)
                                                TextSpan(
                                                  text: "$subject\n",
                                                  style: Theme.of(context).textTheme.bodyText2!.apply(
                                                      fontWeightDelta: 2,
                                                      color: hideContent ? Colors.transparent : Colors.white),
                                                ),
                                              TextSpan(
                                                text: text,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyText2!
                                                    .apply(color: hideContent ? Colors.transparent : Colors.white),
                                              ),
                                            ],
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2!
                                                .apply(color: hideContent ? Colors.transparent : Colors.white),
                                          ),
                                        ),
                                      ),
                                      if (effect == MessageEffect.gentle)
                                        RichText(
                                          text: TextSpan(
                                            children: [
                                              if (!isNullOrEmpty(message.subject)!)
                                                TextSpan(
                                                  text: "$subject\n",
                                                  style: Theme.of(context).textTheme.bodyText2!.apply(
                                                      fontWeightDelta: 2,
                                                      fontSizeFactor: value,
                                                      color: hideContent ? Colors.transparent : Colors.white),
                                                ),
                                              TextSpan(
                                                text: text,
                                                style: Theme.of(context).textTheme.bodyText2!.apply(
                                                    fontSizeFactor: value,
                                                    color: hideContent ? Colors.transparent : Colors.white),
                                              ),
                                            ],
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2!
                                                .apply(color: hideContent ? Colors.transparent : Colors.white),
                                          ),
                                        ),
                                      if (effect == MessageEffect.invisibleInk &&
                                          controller != CustomAnimationControl.stop)
                                        Opacity(
                                          opacity: opacity,
                                          child: AbsorbPointer(
                                            absorbing: true,
                                            child: CircularParticle(
                                              key: UniqueKey(),
                                              numberOfParticles: bubbleSize.height * bubbleSize.width / 25,
                                              speedOfParticles: 0.25,
                                              height: bubbleSize.height - 20,
                                              width: bubbleSize.width - 25,
                                              particleColor: Colors.white.withAlpha(150),
                                              maxParticleSize: (bubbleSize.height / 75).clamp(0.5, 1),
                                              isRandSize: true,
                                              isRandomColor: false,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              });
                            })
                        : FutureBuilder<List<InlineSpan>>(
                            future: msgSpanFuture,
                            initialData: MessageWidgetMixin.buildMessageSpans(context, message),
                            builder: (context, snapshot) {
                              return RichText(
                                text: TextSpan(
                                  children: snapshot.data ?? MessageWidgetMixin.buildMessageSpans(context, message),
                                  style: Theme.of(context).textTheme.bodyText2!.apply(color: Colors.white),
                                ),
                              );
                            })));
          }),
        ],
      );
    }
    if (!padding) return msg;
    final child = Container(
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
              currentChat != null ? currentChat.chat : ChatManager().activeChat?.chat,
            ),
          ],
        ));
    if (effect.isBubble && effect != MessageEffect.invisibleInk && controller != CustomAnimationControl.stop) {
      Animatable<TimelineValue<String>> tween = TimelineTween<String>()
        ..addScene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
            .animate("size", tween: 1.0.tweenTo(1.0));
      if (effect == MessageEffect.gentle && controller != CustomAnimationControl.stop) {
        tween = TimelineTween<String>()
          ..addScene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
              .animate("size", tween: 0.0.tweenTo(1.2))
          ..addScene(
                  begin: Duration(milliseconds: 1000),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut)
              .animate("size", tween: 1.2.tweenTo(1.0));
      }
      if (effect == MessageEffect.loud) {
        tween = TimelineTween<String>()
          ..addScene(begin: Duration.zero, duration: const Duration(milliseconds: 300), curve: Curves.easeIn)
              .animate("size", tween: 1.0.tweenTo(3.0))
          ..addScene(
                  begin: Duration(milliseconds: 200), duration: const Duration(milliseconds: 400), curve: Curves.linear)
              .animate("rotation", tween: 0.0.tweenTo(2.0))
          ..addScene(
                  begin: Duration(milliseconds: 400), duration: const Duration(milliseconds: 500), curve: Curves.easeIn)
              .animate("size", tween: 3.0.tweenTo(1.0));
      }
      if (effect == MessageEffect.slam) {
        tween = TimelineTween<String>()
          ..addScene(begin: Duration.zero, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
              .animate("size", tween: 1.0.tweenTo(5.0))
          ..addScene(begin: Duration.zero, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
              .animate("rotation", tween: 0.0.tweenTo(pi / 16))
          ..addScene(
                  begin: Duration(milliseconds: 250), duration: const Duration(milliseconds: 150), curve: Curves.easeIn)
              .animate("size", tween: 5.0.tweenTo(0.8))
          ..addScene(
                  begin: Duration(milliseconds: 250), duration: const Duration(milliseconds: 150), curve: Curves.easeIn)
              .animate("rotation", tween: (pi / 16).tweenTo(0))
          ..addScene(
                  begin: Duration(milliseconds: 400), duration: const Duration(milliseconds: 100), curve: Curves.easeIn)
              .animate("size", tween: 0.8.tweenTo(1.0));
      }
      return CustomAnimation<TimelineValue<String>>(
          control: controller,
          tween: tween,
          duration: Duration(
              milliseconds: effect == MessageEffect.loud
                  ? 900
                  : effect == MessageEffect.slam
                      ? 500
                      : 1800),
          animationStatusListener: (status) {
            if (status == AnimationStatus.completed) {
              if (message?.datePlayed == null) {
                message?.setPlayedDate();
              }

              updateController?.call();
            }
          },
          builder: (context, child, anim) {
            double value1 = 1;
            double value2 = 0;
            if (effect == MessageEffect.gentle) {
              value1 = anim.get("size");
            } else if (effect == MessageEffect.loud || effect == MessageEffect.slam) {
              value1 = anim.get("size");
              value2 = anim.get("rotation");
            }
            if (effect == MessageEffect.gentle) {
              return Padding(
                padding: EdgeInsets.only(
                    top: (bubbleSize.height + (hasReactions && margin ? 18 : 0)) * (value1.clamp(1, 1.2) - 1)),
                child: Transform.scale(scale: value1, alignment: Alignment.bottomRight, child: child),
              );
            }
            if (effect == MessageEffect.loud) {
              return Container(
                width: (bubbleSize.width + (margin ? 20 : 0)) * value1,
                height: (bubbleSize.height + (hasReactions && margin ? 18 : 0)) * value1,
                child: FittedBox(
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                      angle: sin(value2 * pi * 4) * pi / 24, alignment: Alignment.bottomCenter, child: child),
                ),
              );
            }
            if (effect == MessageEffect.slam) {
              return Container(
                width: (bubbleSize.width + (margin ? 20 : 0)) * value1,
                height: (bubbleSize.height + (hasReactions && margin ? 18 : 0)) * value1,
                child: FittedBox(
                  alignment: Alignment.centerRight,
                  child: Transform.rotate(angle: value2, alignment: Alignment.bottomCenter, child: child),
                ),
              );
            }
            return child!;
          },
          child: child);
    } else {
      return child;
    }
  }

  static Widget getErrorWidget(BuildContext context, Message? message, Chat? chat, {double rightPadding = 8.0}) {
    if (message != null && message.error > 0) {
      int errorCode = message.error;
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
                  title: Text("Message failed to send", style: TextStyle(color: Colors.black)),
                  content: Text("Error ($errorCode): $errorText"),
                  actions: <Widget>[
                    if (chat != null)
                      TextButton(
                        child: Text("Retry"),
                        onPressed: () async {
                          // Remove the OG alert dialog
                          Navigator.of(context).pop();
                          NewMessageManager().removeMessage(chat, message.guid);
                          Message.softDelete(message.guid!);
                          NotificationManager().clearFailedToSend();
                          ActionHandler.retryMessage(message);
                        },
                      ),
                    if (chat != null)
                      TextButton(
                        child: Text("Remove"),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          // Delete the message from the DB
                          Message.softDelete(message.guid!);

                          // Remove the message from the Bloc
                          NewMessageManager().removeMessage(chat, message.guid);
                          NotificationManager().clearFailedToSend();
                          // Get the "new" latest info
                          List<Message> latest = Chat.getMessages(chat, limit: 1);
                          chat.latestMessage = latest.first;
                          chat.latestMessageDate = latest.first.dateCreated;
                          chat.latestMessageText = MessageHelper.getNotificationText(latest.first);

                          // Update it in the Bloc
                          await ChatBloc().updateChatPosition(chat);
                        },
                      ),
                    TextButton(
                      child: Text("Cancel"),
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
          child: Icon(
              SettingsManager().settings.skin.value == Skins.iOS
                  ? CupertinoIcons.exclamationmark_circle
                  : Icons.error_outline,
              color: Colors.red),
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
  final bool autoplayEffect;

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
    required this.autoplayEffect,

    // Sub-widgets
    required this.stickersWidget,
    required this.attachmentsWidget,
    required this.reactionsWidget,
    required this.urlPreviewWidget,
  }) : super(key: key);

  @override
  _SentMessageState createState() => _SentMessageState();
}

class _SentMessageState extends State<SentMessage> with MessageWidgetMixin, WidgetsBindingObserver {
  final Rx<Skins> skin = Rx<Skins>(SettingsManager().settings.skin.value);
  late final spanFuture = MessageWidgetMixin.buildMessageSpansAsync(context, widget.message);
  Size? threadOriginatorSize;
  Size? messageSize;
  bool showReplies = false;
  late String effect;
  CustomAnimationControl animController = CustomAnimationControl.stop;
  final GlobalKey key = GlobalKey();

  @override
  void initState() {
    super.initState();
    showReplies = widget.showReplies;

    effect = widget.message.expressiveSendStyleId == null
        ? "none"
        : effectMap.entries.firstWhereOrNull((element) => element.value == widget.message.expressiveSendStyleId)?.key ??
            "unknown";

    if (!(stringToMessageEffect[effect] ?? MessageEffect.none).isBubble
        && widget.message.datePlayed == null
        && mounted && !(widget.message.guid?.contains("redacted-mode-demo") ?? false)) {
      WidgetsBinding.instance!.addObserver(this);
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        if (!mounted) return;
        EventDispatcher().emit('play-effect', {
          'type': effect,
          'size': key.globalPaintBounds(context),
        });

        widget.message.setPlayedDate();
      });
    }

    /*if (ChatManager().activeChat?.autoplayGuid == widget.message.guid && widget.autoplayEffect) {
      ChatManager().activeChat?.autoplayGuid = null;
      SchedulerBinding.instance!.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.animation?.status == AnimationStatus.completed && widget.autoplayEffect && mounted) {
          setState(() {
            animController = CustomAnimationControl.playFromStart;
          });
        } else if (widget.autoplayEffect) {
          ModalRoute.of(context)?.animation?.addStatusListener((status) {
            if (status == AnimationStatus.completed && widget.autoplayEffect && mounted) {
              setState(() {
                animController = CustomAnimationControl.playFromStart;
              });
            }
          });
        }
      });
    }*/
  }

  List<Color> getBubbleColors(Message message) {
    List<Color> bubbleColors = message.isFromMe ?? false
        ? [Theme.of(context).primaryColor, Theme.of(context).primaryColor]
        : [Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.secondary];
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

    final msg =
        widget.message.associatedMessages.firstWhereOrNull((e) => e.guid == widget.message.threadOriginatorGuid);
    if (widget.message.threadOriginatorGuid != null && showReplies) {
      if (msg != null &&
          widget.olderMessage?.guid != msg.guid &&
          widget.olderMessage?.threadOriginatorGuid != widget.message.threadOriginatorGuid) {
        messageColumn.add(GestureDetector(
          onTap: () {
            showReplyThread(context, widget.message, widget.messageBloc);
          },
          child: StreamBuilder<dynamic>(
              stream: ChatController.of(context)?.totalOffsetStream.stream,
              builder: (context, snapshot) {
                dynamic data;
                if (snapshot.data is double) {
                  data = snapshot.data;
                } else if (snapshot.data is Map<String, dynamic>) {
                  if (snapshot.data["guid"] == widget.message.guid) {
                    data = snapshot.data["offset"];
                  } else {
                    data = snapshot.data["else"];
                  }
                }
                final offset = (-(data ?? 0)).clamp(0, 70).toDouble();
                return AnimatedContainer(
                  duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                  width: CustomNavigator.width(context) - 10 - offset,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: msg.isFromMe ?? false ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if ((SettingsManager().settings.alwaysShowAvatars.value ||
                                (ChatController.of(context)?.chat.isGroup() ?? false)) &&
                            !msg.isFromMe!)
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
                                  future: MessageWidgetMixin.buildMessageSpansAsync(context, msg,
                                      colorOverride: getBubbleColors(msg)[0].lightenOrDarken(30)),
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
                                  }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
        ));
      }
    }

    // Second, add the attachments
    if (isEmptyString(widget.message.fullText)) {
      messageColumn.add(
        MessageWidgetMixin.addStickersToWidget(
          message: MessageWidgetMixin.addReactionsToWidget(
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
      message = SentMessageHelper.buildMessageWithTail(context, widget.message, widget.showTail,
          widget.message.hasReactions, widget.message.bigEmoji ?? false, spanFuture,
          olderMessage: widget.olderMessage,
          effect: stringToMessageEffect[effect] ?? MessageEffect.none,
          controller: animController, updateController: () {
        setState(() {
          animController = CustomAnimationControl.stop;
        });
      });
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
        message = widget.message.fullText.isURL
            ? Padding(
                padding: EdgeInsets.only(right: 5.0),
                child: widget.urlPreviewWidget,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
      if (showReplies &&
          msg != null &&
          (widget.message.shouldConnectLower(widget.olderMessage, widget.newerMessage, msg) ||
              widget.message.shouldConnectUpper(widget.olderMessage, msg))) {
        // get the correct size for the message being replied to
        if (widget.message.upperIsThreadOriginatorBubble(widget.olderMessage)) {
          threadOriginatorSize ??= msg.getBubbleSize(context);
        } else {
          threadOriginatorSize ??= widget.olderMessage?.getBubbleSize(context);
        }
        messageSize ??= widget.message.getBubbleSize(context);
        messageColumn.add(
          StreamBuilder<dynamic>(
              stream: ChatController.of(context)?.totalOffsetStream.stream,
              builder: (context, snapshot) {
                double? data;
                if (snapshot.data is double) {
                  data = snapshot.data;
                } else if (snapshot.data is Map<String, dynamic>) {
                  if (snapshot.data["guid"] == widget.message.guid) {
                    data = snapshot.data["offset"];
                  } else {
                    data = snapshot.data["else"];
                  }
                }
                final offset = (-(data ?? 0)).clamp(0, 70).toDouble();
                final originalWidth = max(
                    min(CustomNavigator.width(context) - messageSize!.width - 150, CustomNavigator.width(context) / 3),
                    10);
                final width = max(
                    min(CustomNavigator.width(context) - messageSize!.width - 150, CustomNavigator.width(context) / 3) -
                        offset,
                    10);
                return AnimatedContainer(
                  duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                  width: CustomNavigator.width(context) - 10 - offset,
                  padding: EdgeInsets.only(
                    // add extra padding when showing contact avatars
                    left: max(
                        ((ChatManager().activeChat?.chat.isGroup() ?? false) ||
                                    SettingsManager().settings.alwaysShowAvatars.value
                                ? 75
                                : 40) -
                            (width == 10 ? offset - (originalWidth - width) : 0),
                        0),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                          duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                          // to make sure the bounds do not overflow, and so we
                          // dont draw an ugly long line)
                          width: width.toDouble(),
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
                                  widget.olderMessage?.threadOriginatorGuid == widget.message.threadOriginatorGuid &&
                                      widget.hasTimestampAbove,
                                  widget.hasTimestampBelow,
                                  false,
                                  offset))),
                      MessageWidgetMixin.addStickersToWidget(
                        message: MessageWidgetMixin.addReactionsToWidget(
                            messageWidget: Padding(
                              key: showReplies ? key : null,
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
                );
              }),
        );
      } else {
        messageColumn.add(
          MessageWidgetMixin.addStickersToWidget(
            message: MessageWidgetMixin.addReactionsToWidget(
                messageWidget: Padding(
                  key: showReplies ? key : null,
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

    messageColumn.add(Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.message.expressiveSendStyleId != null)
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if ((stringToMessageEffect[effect] ?? MessageEffect.none).isBubble) {
                if (effect == "invisible ink" && animController == CustomAnimationControl.playFromStart) {
                  setState(() {
                    animController = CustomAnimationControl.stop;
                  });
                } else {
                  setState(() {
                    animController = CustomAnimationControl.playFromStart;
                  });
                }
              } else {
                EventDispatcher().emit('play-effect', {
                  'type': effect,
                  'size': key.globalPaintBounds(context),
                });
              }
            },
            child: kIsWeb ? Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2, right: 8.0, bottom: 2),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.refresh, size: 10, color: Theme.of(context).primaryColor),
                    Text(
                      " sent with $effect",
                      style: Theme.of(context).textTheme.subtitle2!.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                  ]
              ),
            ): Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 2, right: 8.0, bottom: 2),
              child: Text(
                "↺ sent with $effect",
                style: Theme.of(context).textTheme.subtitle2!.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
              ),
            ),
          ),
        Obx(() {
          final list = widget.messageBloc?.threadOriginators.values.where((e) => e == widget.message.guid) ?? [].obs.reversed;
          if (list.isNotEmpty) {
            return GestureDetector(
              onTap: () {
                showReplyThread(context, widget.message, widget.messageBloc);
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 18.0, top: 2, bottom: 4),
                child: Text(
                  "${list.length} repl${list.length > 1 ? "ies" : "y"}",
                  style:
                      Theme.of(context).textTheme.subtitle2!.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
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
        }),
      ],
    ));

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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        MessagePopupHolder(
          message: widget.message,
          olderMessage: widget.olderMessage,
          newerMessage: widget.newerMessage,
          messageBloc: widget.messageBloc,
          popupPushed: (pushed) {
            if (mounted) {
              setState(() {
                showReplies = !pushed;
              });
            }
          },
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
        if (!kIsDesktop && !kIsWeb && skin.value != Skins.Samsung && widget.message.guid != widget.olderMessage?.guid)
          MessageTimeStamp(
            message: widget.message,
          )
      ],
    );
  }
}
