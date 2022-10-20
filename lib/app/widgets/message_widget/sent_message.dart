import 'dart:math';

import 'package:async_task/async_task_extension.dart';
import 'package:bluebubbles/core/actions/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/layouts/setup/pages/unfinished/theme_selector.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/delivered_receipt.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/media_players/balloon_bundle_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/message_tail.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_content/message_time_stamp.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_popup_holder.dart';
import 'package:bluebubbles/app/widgets/message_widget/message_widget_mixin.dart';
import 'package:bluebubbles/app/widgets/message_widget/reply_line_painter.dart';
import 'package:bluebubbles/app/widgets/message_widget/show_reply_thread.dart';
import 'package:bluebubbles/core/managers/chat/chat_controller.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/core/events/event_dispatcher.dart';
import 'package:bluebubbles/core/managers/message/message_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:faker/faker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
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
    Control controller = Control.stop,
    void Function()? updateController,
  }) {
    if (effect.isBubble) assert(updateController != null);
    Color bubbleColor;
    bubbleColor = message == null || message.guid!.startsWith("temp")
        ? context.theme.primaryColor.darkenAmount(0.2)
        : context.theme.primaryColor;

    final bool hideEmoji = ss.settings.redactedMode.value && ss.settings.hideEmojis.value;
    final bool generateContent =
        ss.settings.redactedMode.value && ss.settings.generateFakeMessageContent.value;
    final bool hideContent = (ss.settings.redactedMode.value &&
        ss.settings.hideMessageContent.value &&
        !generateContent);
    final subject =
        generateContent ? faker.lorem.words(message?.subject?.split(" ").length ?? 0).join(" ") : message?.subject;
    final text = generateContent ? faker.lorem.words(message?.text?.split(" ").length ?? 0).join(" ") : message?.text;

    Widget msg;
    bool hasReactions = (message?.getReactions() ?? []).isNotEmpty;
    Skins currentSkin = Skin.of(context)?.skin ?? ss.settings.skin.value;
    Size bubbleSize = Size(0, 0);

    // If we haven't played the effect, we should apply it from the start.
    // This must come before we set the bubbleSize variable or else we get a box constraints errors
    if (message?.datePlayed == null && effect != MessageEffect.none) {
      controller = Control.playFromStart;
      if (effect != MessageEffect.invisibleInk) {
        Timer(Duration(milliseconds: 500), () {
          if (message?.datePlayed == null && !(message?.guid?.contains("redacted-mode-demo") ?? false)) {
            message?.setPlayedDate();
          }
        });
      }
    }

    if (controller != Control.stop) {
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
                          color: context.theme.colorScheme.properSurface,
                          child: Center(
                            child: Text(
                              "emoji",
                              textAlign: TextAlign.center,
                              style: (context.theme.extensions[BubbleText] as BubbleText).bubbleText,
                            ),
                          )),
                    )
                  : RichText(
                      text: TextSpan(
                          children: MessageHelper.buildEmojiText(
                              message!.text!,
                              (context.theme.extensions[BubbleText] as BubbleText)
                                  .bubbleText
                                  .apply(fontSizeFactor: bigEmojiScaleFactor)))),
            ),
          );
        })
      ]);
    } else {
      MovieTween? tween;
      double opacity = 0;
      if (effect == MessageEffect.gentle && controller != Control.stop) {
        tween = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 500))
              .tween("size", 0.5.tweenTo(0.5))
          ..scene(
                  begin: Duration(milliseconds: 1000),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut)
              .tween("size", 0.5.tweenTo(1.0));
        opacity = 1;
      } else if (controller != Control.stop) {
        tween = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
              .tween("size", 1.0.tweenTo(1.0));
      }
      if (effect == MessageEffect.invisibleInk && controller != Control.stop) {
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
                      maxWidth: ns.width(context) * MessageWidgetMixin.MAX_SIZE + (!padding ? 100 : 0),
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
              child: customContent ??
                  (effect.isBubble && controller != Control.stop
                      ? CustomAnimationBuilder(
                          control: controller,
                          tween: tween!,
                          duration: Duration(milliseconds: 1800),
                          builder: (context, Movie anim, child) {
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
                                                style: (context.theme.extensions[BubbleText] as BubbleText)
                                                    .bubbleText
                                                    .apply(
                                                        fontWeightDelta: 2,
                                                        color: hideContent
                                                            ? Colors.transparent
                                                            : context.theme.colorScheme.onPrimary),
                                              ),
                                            TextSpan(
                                              text: text,
                                              style: context.theme.extension<BubbleText>()!.bubbleText.apply(
                                                  color: hideContent
                                                      ? Colors.transparent
                                                      : context.theme.colorScheme.onPrimary),
                                            ),
                                          ],
                                          style: context.theme.extension<BubbleText>()!.bubbleText.apply(
                                              color: hideContent
                                                  ? Colors.transparent
                                                  : context.theme.colorScheme.onPrimary),
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
                                                style: (context.theme.extensions[BubbleText] as BubbleText)
                                                    .bubbleText
                                                    .apply(
                                                        fontWeightDelta: 2,
                                                        fontSizeFactor: value,
                                                        color: hideContent
                                                            ? Colors.transparent
                                                            : context.theme.colorScheme.onPrimary),
                                              ),
                                            TextSpan(
                                              text: text,
                                              style: (context.theme.extensions[BubbleText] as BubbleText)
                                                  .bubbleText
                                                  .apply(
                                                      fontSizeFactor: value,
                                                      color: hideContent
                                                          ? Colors.transparent
                                                          : context.theme.colorScheme.onPrimary),
                                            ),
                                          ],
                                          style: context.theme.extension<BubbleText>()!.bubbleText.apply(
                                              color: hideContent
                                                  ? Colors.transparent
                                                  : context.theme.colorScheme.onPrimary),
                                        ),
                                      ),
                                    if (effect == MessageEffect.invisibleInk &&
                                        controller != Control.stop)
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
                                            particleColor: context.theme.colorScheme.onPrimary.withAlpha(150),
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
                            return ((ModalRoute.of(context)?.settings.arguments as Map?)?['hideTail'] ?? false)
                                ? Theme(
                                    data: context.theme.copyWith(
                                        textSelectionTheme: TextSelectionThemeData(
                                            selectionColor: context.theme.colorScheme.properSurface.withAlpha(150))),
                                    child: SelectableText.rich(
                                      TextSpan(
                                        children:
                                            snapshot.data ?? MessageWidgetMixin.buildMessageSpans(context, message),
                                        style: (context.theme.extensions[BubbleText] as BubbleText)
                                            .bubbleText
                                            .apply(color: context.theme.colorScheme.onPrimary),
                                      ),
                                      cursorWidth: 0,
                                      selectionControls: CupertinoTextSelectionControls(),
                                      style: (context.theme.extensions[BubbleText] as BubbleText)
                                          .bubbleText
                                          .apply(color: context.theme.colorScheme.onPrimary),
                                    ),
                                  )
                                : Padding(
                                    padding: EdgeInsets.only(right: 1),
                                    child: RichText(
                                      text: TextSpan(
                                        children:
                                            snapshot.data ?? MessageWidgetMixin.buildMessageSpans(context, message),
                                        style: (context.theme.extensions[BubbleText] as BubbleText)
                                            .bubbleText
                                            .apply(color: context.theme.colorScheme.onPrimary),
                                      ),
                                    ),
                                  );
                          },
                        )),
            );
          }),
        ],
      );
    }
    if (!padding) return msg;
    final child = Container(
        width: customWidth != null ? customWidth - (showTail ? 20 : 0) : null,
        constraints: BoxConstraints(
          maxWidth: customWidth != null ? customWidth - (showTail ? 20 : 0) : ns.width(context),
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
    if (effect.isBubble && effect != MessageEffect.invisibleInk && controller != Control.stop) {
      MovieTween tween = MovieTween()
        ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
            .tween("size", 1.0.tweenTo(1.0));
      if (effect == MessageEffect.gentle && controller != Control.stop) {
        tween = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)
              .tween("size", 0.0.tweenTo(1.2))
          ..scene(
                  begin: Duration(milliseconds: 1000),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut)
              .tween("size", 1.2.tweenTo(1.0));
      }
      if (effect == MessageEffect.loud) {
        tween = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 300), curve: Curves.easeIn)
              .tween("size", 1.0.tweenTo(3.0))
          ..scene(
                  begin: Duration(milliseconds: 200), duration: const Duration(milliseconds: 400), curve: Curves.linear)
              .tween("rotation", 0.0.tweenTo(2.0))
          ..scene(
                  begin: Duration(milliseconds: 400), duration: const Duration(milliseconds: 500), curve: Curves.easeIn)
              .tween("size", 3.0.tweenTo(1.0));
      }
      if (effect == MessageEffect.slam) {
        tween = MovieTween()
          ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
              .tween("size", 1.0.tweenTo(5.0))
          ..scene(begin: Duration.zero, duration: const Duration(milliseconds: 200), curve: Curves.easeIn)
              .tween("rotation", 0.0.tweenTo(pi / 16))
          ..scene(
                  begin: Duration(milliseconds: 250), duration: const Duration(milliseconds: 150), curve: Curves.easeIn)
              .tween("size", 5.0.tweenTo(0.8))
          ..scene(
                  begin: Duration(milliseconds: 250), duration: const Duration(milliseconds: 150), curve: Curves.easeIn)
              .tween("rotation", (pi / 16).tweenTo(0))
          ..scene(
                  begin: Duration(milliseconds: 400), duration: const Duration(milliseconds: 100), curve: Curves.easeIn)
              .tween("size", 0.8.tweenTo(1.0));
      }
      return CustomAnimationBuilder(
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
          builder: (context, Movie anim, child) {
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
        child: KeyboardVisibilityBuilder(builder: (context, isVisible) {
          return GestureDetector(
            onTap: () {
              if (!ss.settings.autoOpenKeyboard.value && !isVisible && !kIsWeb && !kIsDesktop) {
                EventDispatcher().emit('unfocus-keyboard', null);
              }
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: context.theme.colorScheme.properSurface,
                    title: Text("Message failed to send", style: context.theme.textTheme.titleLarge),
                    content: Text("Error ($errorCode): $errorText", style: context.theme.textTheme.bodyLarge),
                    actions: <Widget>[
                      if (chat != null)
                        TextButton(
                          child: Text("Retry",
                              style: context.theme.textTheme.bodyLarge!
                                  .copyWith(color: Get.context!.theme.colorScheme.primary)),
                          onPressed: () async {
                            // Remove the OG alert dialog
                            Navigator.of(context).pop();
                            MessageManager().removeMessage(chat, message.guid);
                            Message.softDelete(message.guid!);
                            await notif.clearFailedToSend();
                            ActionHandler.retryMessage(message);
                          },
                        ),
                      if (chat != null)
                        TextButton(
                          child: Text("Remove",
                              style: context.theme.textTheme.bodyLarge!
                                  .copyWith(color: Get.context!.theme.colorScheme.primary)),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            // Delete the message from the DB
                            Message.softDelete(message.guid!);

                            // Remove the message from the Bloc
                            MessageManager().removeMessage(chat, message.guid);
                            await notif.clearFailedToSend();
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
                        child: Text("Cancel",
                            style: context.theme.textTheme.bodyLarge!
                                .copyWith(color: Get.context!.theme.colorScheme.primary)),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await notif.clearFailedToSend();
                        },
                      )
                    ],
                  );
                },
              );
            },
            child: Icon(
                ss.settings.skin.value == Skins.iOS
                    ? CupertinoIcons.exclamationmark_circle
                    : Icons.error_outline,
                color: context.theme.colorScheme.error),
          );
        }),
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
  State<SentMessage> createState() => _SentMessageState();
}

class _SentMessageState extends State<SentMessage> with MessageWidgetMixin, WidgetsBindingObserver {
  final Rx<Skins> skin = Rx<Skins>(ss.settings.skin.value);
  late final spanFuture = MessageWidgetMixin.buildMessageSpansAsync(context, widget.message);
  Size? threadOriginatorSize;
  Size? messageSize;
  bool showReplies = false;
  late String effect;
  Control animController = Control.stop;
  final GlobalKey key = GlobalKey();

  @override
  void initState() {
    super.initState();
    showReplies = widget.showReplies;

    effect = widget.message.expressiveSendStyleId == null
        ? "none"
        : effectMap.entries.firstWhereOrNull((element) => element.value == widget.message.expressiveSendStyleId)?.key ??
            "unknown";

    if (!(stringToMessageEffect[effect] ?? MessageEffect.none).isBubble &&
        widget.message.datePlayed == null &&
        mounted &&
        !(widget.message.guid?.contains("redacted-mode-demo") ?? false)) {
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
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
            animController = Control.playFromStart;
          });
        } else if (widget.autoplayEffect) {
          ModalRoute.of(context)?.animation?.addStatusListener((status) {
            if (status == AnimationStatus.completed && widget.autoplayEffect && mounted) {
              setState(() {
                animController = Control.playFromStart;
              });
            }
          });
        }
      });
    }*/
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
                  width: ns.width(context) - 10 - offset,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: msg.isFromMe ?? false ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if ((ss.settings.alwaysShowAvatars.value ||
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
                                color: context.theme.colorScheme.primary,
                                isReply: true,
                              ),
                            Container(
                              margin: EdgeInsets.only(
                                left: 6,
                                right: 10,
                              ),
                              constraints: BoxConstraints(
                                maxWidth: ns.width(context) * MessageWidgetMixin.MAX_SIZE - 30,
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: context.theme.colorScheme.primary),
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
                                      colorOverride: context.theme.colorScheme.primary.lightenOrDarken(30)),
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
                                            colorOverride: context.theme.colorScheme.primary.lightenOrDarken(30)),
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
          animController = Control.stop;
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

    List<Widget> messagePopupColumn = List<Widget>.from(messageColumn.slice(1));

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
                    min(ns.width(context) - messageSize!.width - 150, ns.width(context) / 3),
                    10);
                final width = max(
                    min(ns.width(context) - messageSize!.width - 150, ns.width(context) / 3) -
                        offset,
                    10);
                return AnimatedContainer(
                  duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                  width: ns.width(context) - 10 - offset,
                  padding: EdgeInsets.only(
                    // add extra padding when showing contact avatars
                    left: max(
                        ((ChatManager().activeChat?.chat.isGroup() ?? false) ||
                                    ss.settings.alwaysShowAvatars.value
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
        messagePopupColumn.add(
          MessageWidgetMixin.addStickersToWidget(
            message: MessageWidgetMixin.addReactionsToWidget(
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
        messagePopupColumn.add(
          MessageWidgetMixin.addStickersToWidget(
            message: MessageWidgetMixin.addReactionsToWidget(
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

    messageColumn.add(Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.message.expressiveSendStyleId != null)
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if ((stringToMessageEffect[effect] ?? MessageEffect.none).isBubble) {
                if (effect == "invisible ink" && animController == Control.playFromStart) {
                  setState(() {
                    animController = Control.stop;
                  });
                } else {
                  setState(() {
                    animController = Control.playFromStart;
                  });
                }
              } else {
                EventDispatcher().emit('play-effect', {
                  'type': effect,
                  'size': key.globalPaintBounds(context),
                });
              }
            },
            child: kIsWeb
                ? Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 2, right: 8.0, bottom: 2),
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Icon(Icons.refresh, size: 10, color: context.theme.primaryColor),
                      Text(
                        " sent with $effect",
                        style: context.theme.textTheme.labelSmall!
                            .copyWith(fontWeight: FontWeight.bold, color: context.theme.primaryColor),
                      ),
                    ]),
                  )
                : Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 2, right: 8.0, bottom: 2),
                    child: Text(
                      "↺ sent with $effect",
                      style: context.theme.textTheme.labelSmall!
                          .copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        Obx(() {
          final list =
              widget.messageBloc?.threadOriginators.values.where((e) => e == widget.message.guid) ?? [].obs.reversed;
          if (list.isNotEmpty) {
            return GestureDetector(
              onTap: () {
                showReplyThread(context, widget.message, widget.messageBloc);
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 18.0, top: 2, bottom: 4),
                child: Text(
                  "${list.length} repl${list.length > 1 ? "ies" : "y"}",
                  style: context.theme.textTheme.labelSmall!
                      .copyWith(color: context.theme.colorScheme.primary, fontWeight: FontWeight.bold),
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

    messagePopupColumn.add(Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        DeliveredReceipt(
          message: widget.message,
          showDeliveredReceipt: widget.showDeliveredReceipt,
          shouldAnimate: widget.shouldFadeIn,
        ),
      ],
    ));

    // Now, let's create a row that will be the row with the following:
    // -> Contact avatar
    // -> Message
    List<Widget> msgRow = [
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
    ];

    List<Widget> msgPopupRow = [
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
          children: messagePopupColumn,
        ),
      ),
    ];

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
            children: msgPopupRow,
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
