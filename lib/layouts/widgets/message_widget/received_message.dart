import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/redacted_helper.dart';
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
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:particles_flutter/particles_flutter.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:supercharged/supercharged.dart';

class ReceivedMessage extends StatefulWidget {
  final bool showTail;
  final Message message;
  final String fakeOlderSubject;
  final String fakeSubject;
  final String fakeOlderText;
  final String fakeText;
  final Message? olderMessage;
  final Message? newerMessage;
  final bool showHandle;
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

  final bool showTimeStamp;

  ReceivedMessage({
    Key? key,
    required this.showTail,
    required this.olderMessage,
    required this.newerMessage,
    required this.message,
    this.fakeOlderSubject = "",
    this.fakeOlderText = "",
    this.fakeSubject = "",
    this.fakeText = "",
    required this.showHandle,
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
    this.showTimeStamp = false,
  }) : super(key: key);

  @override
  _ReceivedMessageState createState() => _ReceivedMessageState();
}

class _ReceivedMessageState extends State<ReceivedMessage> with MessageWidgetMixin, WidgetsBindingObserver {
  bool checkedHandle = false;
  late String contactTitle;
  final Rx<Skins> skin = Rx<Skins>(SettingsManager().settings.skin.value);
  late final spanFuture = MessageWidgetMixin.buildMessageSpansAsync(context, widget.message,
      colors: widget.message.handle?.color != null ? getBubbleColors(widget.message) : null,
      fakeSubject: widget.fakeSubject,
      fakeText: widget.fakeText);
  Size? threadOriginatorSize;
  Size? messageSize;
  late String effect;
  bool showReplies = false;
  CustomAnimationControl controller = CustomAnimationControl.stop;
  final GlobalKey key = GlobalKey();

  @override
  initState() {
    super.initState();
    showReplies = widget.showReplies;
    contactTitle = ContactManager().getContactTitle(widget.message.handle);

    effect = widget.message.expressiveSendStyleId == null
        ? "none"
        : effectMap.entries.firstWhereOrNull((element) => element.value == widget.message.expressiveSendStyleId)?.key ??
            "unknown";

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh-avatar' && event["data"][0] == widget.message.handle?.address && mounted) {
        widget.message.handle?.color = event['data'][1];
        setState(() {});
      }
    });

    if (!(stringToMessageEffect[effect] ?? MessageEffect.none).isBubble && widget.message.datePlayed == null) {
      WidgetsBinding.instance!.addObserver(this);
      WidgetsBinding.instance!.addPostFrameCallback((_) async {
        EventDispatcher().emit('play-effect', {
          'type': effect,
          'size': key.globalPaintBounds(context),
        });

        if (widget.message.guid != "redacted-mode-demo" && !widget.message.guid!.contains("theme-selector")) {
          widget.message.setPlayedDate();
        }
      });
    }

    /*if (ChatManager().activeChat?.autoplayGuid == widget.message.guid && widget.autoplayEffect) {
      ChatManager().activeChat?.autoplayGuid = null;
      SchedulerBinding.instance!.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.animation?.status == AnimationStatus.completed && widget.autoplayEffect && mounted) {
          setState(() {
            controller = CustomAnimationControl.playFromStart;
          });
        } else if (widget.autoplayEffect) {
          ModalRoute.of(context)?.animation?.addStatusListener((status) {
            if (status == AnimationStatus.completed && widget.autoplayEffect && mounted) {
              setState(() {
                controller = CustomAnimationControl.playFromStart;
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

  /// Builds the message bubble with teh tail (if applicable)
  Widget _buildMessageWithTail(Message message, MessageEffect effect) {
    Animatable<TimelineValue<String>>? tween;
    Size bubbleSize = Size(0, 0);
    double opacity = 0;

    // If we haven't played the effect, we should apply it from the start.
    // This must come before we set the bubbleSize variable or else we get a box constraints errors
    if (message.datePlayed == null && effect != MessageEffect.none) {
      controller = CustomAnimationControl.playFromStart;
      if (effect != MessageEffect.invisibleInk) {
        Timer(Duration(milliseconds: 500), () {
          if (message.datePlayed == null) {
            message.setPlayedDate();
          }
        });
      }
    }

    if (controller != CustomAnimationControl.stop) {
      bubbleSize = message.getBubbleSize(context);
    }
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
      setState(() {
        opacity = 1;
      });
    }
    double topPadding = widget.message.getReactions().isNotEmpty && !widget.message.hasAttachments
        ? 18
        : (widget.message.isFromMe != widget.olderMessage?.isFromMe && skin.value != Skins.Samsung)
            ? 5.0
            : 0;

    late final Widget child;
    if (message.isBigEmoji()) {
      final bool hideContent =
          SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideEmojis.value;

      bool hasReactions = message.getReactions().isNotEmpty;
      child = Padding(
        padding: EdgeInsets.only(
          left: ChatManager().activeChat?.chat.isGroup() ?? false ? 5.0 : 0.0,
          right: (hasReactions) ? 15.0 : 0.0,
          top: widget.message.getReactions().isNotEmpty ? 15 : 0,
        ),
        child: hideContent
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
                        message.text!, Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 4)))),
      );
    } else {
      child = Stack(
        alignment: AlignmentDirectional.bottomStart,
        children: [
          if (widget.showTail && skin.value == Skins.iOS)
            Obx(() => MessageTail(
                  isFromMe: false,
                  color: getBubbleColors(widget.message)[0],
                )),
          Container(
            margin: EdgeInsets.only(
              top: topPadding,
              left: 10,
              right: 10,
            ),
            constraints: BoxConstraints(
              maxWidth: CustomNavigator.width(context) * MessageWidgetMixin.MAX_SIZE,
            ),
            padding: EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 14,
            ),
            decoration: BoxDecoration(
              borderRadius: skin.value == Skins.iOS
                  ? BorderRadius.only(
                      bottomLeft: Radius.circular(17),
                      bottomRight: Radius.circular(20),
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    )
                  : (skin.value == Skins.Material)
                      ? BorderRadius.only(
                          topLeft: widget.olderMessage == null ||
                                  MessageHelper.getShowTail(context, widget.olderMessage, widget.message)
                              ? Radius.circular(20)
                              : Radius.circular(5),
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                          bottomLeft: Radius.circular(widget.showTail ? 20 : 5),
                        )
                      : (skin.value == Skins.Samsung)
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
                colors: getBubbleColors(widget.message),
              ),
            ),
            child: effect.isBubble && controller != CustomAnimationControl.stop
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
                              message.setPlayedDate();
                              setState(() {
                                opacity = 1 - opacity;
                                controller = CustomAnimationControl.stop;
                              });
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: 1 - opacity,
                                child: RichText(
                                  text: TextSpan(
                                    children: MessageWidgetMixin.buildMessageSpans(context, widget.message,
                                        colors: widget.message.handle?.color != null
                                            ? getBubbleColors(widget.message)
                                            : null,
                                        fakeSubject: widget.fakeSubject,
                                        fakeText: widget.fakeText),
                                    style: Theme.of(context).textTheme.bodyText2,
                                  ),
                                ),
                              ),
                              if (effect == MessageEffect.gentle)
                                RichText(
                                  text: TextSpan(
                                    children: MessageWidgetMixin.buildMessageSpans(context, widget.message,
                                        colors: widget.message.handle?.color != null
                                            ? getBubbleColors(widget.message)
                                            : null,
                                        fakeSubject: widget.fakeSubject,
                                        fakeText: widget.fakeText),
                                    style: Theme.of(context).textTheme.bodyText2!.apply(fontSizeFactor: value),
                                  ),
                                ),
                              if (effect == MessageEffect.invisibleInk && controller != CustomAnimationControl.stop)
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
                    future: SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape)
                        ? MessageWidgetMixin.buildMessageSpansAsync(context, widget.message,
                            colors: widget.message.handle?.color != null ? getBubbleColors(widget.message) : null,
                            fakeSubject: widget.fakeSubject,
                            fakeText: widget.fakeText)
                        : spanFuture,
                    initialData: MessageWidgetMixin.buildMessageSpans(context, widget.message,
                        colors: widget.message.handle?.color != null ? getBubbleColors(widget.message) : null,
                        fakeSubject: widget.fakeSubject,
                        fakeText: widget.fakeText),
                    builder: (context, snapshot) {
                      return RichText(
                        text: TextSpan(
                          children: snapshot.data ??
                              MessageWidgetMixin.buildMessageSpans(context, widget.message,
                                  colors: widget.message.handle?.color != null ? getBubbleColors(widget.message) : null,
                                  fakeSubject: widget.fakeSubject,
                                  fakeText: widget.fakeText),
                          style: Theme.of(context).textTheme.bodyText2,
                        ),
                      );
                    }),
          ),
        ],
      );
    }

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
              .animate("rotation", tween: 0.0.tweenTo(-pi / 16))
          ..addScene(
                  begin: Duration(milliseconds: 250), duration: const Duration(milliseconds: 150), curve: Curves.easeIn)
              .animate("size", tween: 5.0.tweenTo(0.8))
          ..addScene(
                  begin: Duration(milliseconds: 250), duration: const Duration(milliseconds: 150), curve: Curves.easeIn)
              .animate("rotation", tween: (-pi / 16).tweenTo(0))
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
              if (message.datePlayed == null) {
                message.setPlayedDate();
              }

              setState(() {
                controller = CustomAnimationControl.stop;
              });
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
                padding: EdgeInsets.only(top: (bubbleSize.height + topPadding) * (value1.clamp(1, 1.2) - 1)),
                child: Transform.scale(scale: value1, alignment: Alignment.bottomLeft, child: child),
              );
            }
            if (effect == MessageEffect.loud) {
              return Container(
                width: (bubbleSize.width + 20) * value1,
                height: (bubbleSize.height + topPadding) * value1,
                child: FittedBox(
                  alignment: Alignment.bottomLeft,
                  child: Transform.rotate(
                      angle: sin(value2 * pi * 4) * pi / 24, alignment: Alignment.bottomCenter, child: child),
                ),
              );
            }
            if (effect == MessageEffect.slam) {
              return Container(
                width: (bubbleSize.width + 20) * value1,
                height: (bubbleSize.height + topPadding) * value1,
                child: FittedBox(
                  alignment: Alignment.centerLeft,
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

  @override
  Widget build(BuildContext context) {
    contactTitle = ContactManager().getContactTitle(widget.message.handle);

    if (Skin.of(context) != null) {
      skin.value = Skin.of(context)!.skin;
    }
    // The column that holds all the "messages"
    List<Widget> messageColumn = [];
    final msg =
        widget.message.associatedMessages.firstWhereOrNull((e) => e.guid == widget.message.threadOriginatorGuid);

    // First, add the message sender (if applicable)
    bool isGroup = ChatManager().activeChat?.chat.isGroup() ?? false;
    bool addedSender = false;
    bool showSender = SettingsManager().settings.alwaysShowAvatars.value ||
        isGroup ||
        widget.message.guid == "redacted-mode-demo" ||
        widget.message.guid!.contains("theme-selector");
    if (widget.message.guid == "redacted-mode-demo" ||
        widget.message.guid!.contains("theme-selector") ||
        (isGroup &&
            (!sameSender(widget.message, widget.olderMessage) ||
                !widget.message.dateCreated!.isWithin(widget.olderMessage!.dateCreated!, minutes: 30)))) {
      messageColumn.add(
        Padding(
          padding: EdgeInsets.only(left: 15.0, top: 5.0, bottom: widget.message.getReactions().isNotEmpty ? 0.0 : 3.0),
          child: Text(
            getContactName(context, contactTitle, widget.message.handle!.address),
            style: Theme.of(context).textTheme.subtitle1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
      addedSender = true;
    }

    // Second, add the attachments
    if (widget.message.getRealAttachments().isNotEmpty) {
      messageColumn.add(
        MessageWidgetMixin.addStickersToWidget(
          message: MessageWidgetMixin.addReactionsToWidget(
              messageWidget: widget.attachmentsWidget,
              reactions: widget.reactionsWidget,
              message: widget.message,
              shouldShow: widget.message.hasAttachments),
          stickers: widget.stickersWidget,
          isFromMe: widget.message.isFromMe!,
        ),
      );
    }

    // Third, let's add the actual message we want to show
    Widget? message;
    if (widget.message.isInteractive()) {
      message = Padding(padding: EdgeInsets.only(left: 10.0), child: BalloonBundleWidget(message: widget.message));
    } else if (widget.message.hasText()) {
      message = _buildMessageWithTail(widget.message, stringToMessageEffect[effect] ?? MessageEffect.none);
      if (widget.message.fullText.replaceAll("\n", " ").hasUrl) {
        message = widget.message.fullText.isURL
            ? Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: widget.urlPreviewWidget,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Padding(
                      padding: EdgeInsets.only(left: 10.0),
                      child: widget.urlPreviewWidget,
                    ),
                    message,
                  ]);
      }
    }

    // Fourth, let's add any reactions or stickers to the widget
    if (message != null) {
      // only show the line if it is going to either connect up or down
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
                  min(CustomNavigator.width(context) - messageSize!.width - 125, CustomNavigator.width(context) / 3),
                  10);
              final width = max(
                  min(CustomNavigator.width(context) - messageSize!.width - 125, CustomNavigator.width(context) / 3) -
                      offset,
                  10);
              return AnimatedContainer(
                duration: Duration(milliseconds: offset == 0 ? 150 : 0),
                width: CustomNavigator.width(context) - 45 - offset,
                padding: EdgeInsets.only(right: max(30 - (width == 10 ? offset - (originalWidth - width) : 0), 0)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MessageWidgetMixin.addStickersToWidget(
                      message: MessageWidgetMixin.addReactionsToWidget(
                          messageWidget: SizedBox(key: showReplies ? key : null, child: message!),
                          reactions: widget.reactionsWidget,
                          message: widget.message,
                          shouldShow: widget.message.getRealAttachments().isEmpty),
                      stickers: widget.stickersWidget,
                      isFromMe: widget.message.isFromMe!,
                    ),
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
                          addedSender,
                          offset,
                        ))),
                  ],
                ),
              );
            },
          ),
        );
      } else {
        messageColumn.add(
          MessageWidgetMixin.addStickersToWidget(
            message: MessageWidgetMixin.addReactionsToWidget(
                messageWidget: SizedBox(key: showReplies ? key : null, child: message),
                reactions: widget.reactionsWidget,
                message: widget.message,
                shouldShow: widget.message.getRealAttachments().isEmpty),
            stickers: widget.stickersWidget,
            isFromMe: widget.message.isFromMe!,
          ),
        );
      }
    }

    if (widget.showTimeStamp) {
      messageColumn.add(
        DeliveredReceipt(
          message: widget.message,
          showDeliveredReceipt: widget.showTimeStamp,
          shouldAnimate: true,
        ),
      );
    }

    List<Widget> messagePopupColumn = List<Widget>.from(messageColumn);
    if (!addedSender && isGroup) {
      messagePopupColumn.insert(
        0,
        Padding(
          padding: EdgeInsets.only(left: 15.0, top: 5.0, bottom: widget.message.getReactions().isNotEmpty ? 0.0 : 3.0),
          child: Text(
            getContactName(context, contactTitle, widget.message.handle!.address),
            style: Theme.of(context).textTheme.subtitle1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Now, let's create a row that will be the row with the following:
    // -> Contact avatar
    // -> Message
    List<Widget> msgRow = [];
    bool addedAvatar = false;
    if (widget.showTail && (showSender || skin.value == Skins.Samsung)) {
      double topPadding = (isGroup) ? 5 : 0;
      if (skin.value == Skins.Samsung && addedSender) {
        topPadding = 27.5;
      }

      msgRow.add(
        Padding(
          padding: EdgeInsets.only(left: 5.0, top: topPadding, bottom: widget.showTimeStamp ? 20 : 0),
          child: ContactAvatarWidget(
            handle: widget.message.handle,
            size: 30,
            fontSize: 14,
            borderThickness: 0.1,
          ),
        ),
      );
      addedAvatar = true;
    }

    List<Widget> msgPopupRow = List<Widget>.from(msgRow);
    if (!addedAvatar && (showSender || skin.value == Skins.Samsung)) {
      double topPadding = (isGroup) ? 5 : 0;
      if (skin.value == Skins.Samsung && addedSender) {
        topPadding = 27.5;
      }

      msgPopupRow.add(
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

    msgPopupRow.add(
      Padding(
        // Padding to shift the bubble up a bit, relative to the avatar
        padding: EdgeInsets.only(bottom: 0.0),
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: messagePopupColumn,
          ),
        ),
      ),
    );

    // Finally, create a container row so we can have the swipe timestamp
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showReplies &&
            widget.message.threadOriginatorGuid != null &&
            widget.olderMessage?.threadOriginatorGuid != widget.message.threadOriginatorGuid &&
            msg != null &&
            widget.olderMessage?.guid != msg.guid)
          GestureDetector(
            onTap: () {
              showReplyThread(context, widget.message, widget.messageBloc);
            },
            child: Container(
              width: CustomNavigator.width(context) - 10,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: msg.isFromMe ?? false ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if ((SettingsManager().settings.alwaysShowAvatars.value ||
                            (ChatManager().activeChat?.chat.isGroup() ?? false)) &&
                        !msg.isFromMe!)
                      Padding(
                        padding: EdgeInsets.only(top: 5),
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
                          Obx(() => MessageTail(
                                isFromMe: false,
                                color: getBubbleColors(msg)[0],
                                isReply: true,
                              )),
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
                                  colorOverride: getBubbleColors(msg)[0].lightenOrDarken(30),
                                  fakeSubject: widget.fakeOlderSubject,
                                  fakeText: widget.fakeOlderText),
                              initialData: MessageWidgetMixin.buildMessageSpans(context, msg,
                                  colorOverride: getBubbleColors(msg)[0].lightenOrDarken(30),
                                  fakeSubject: widget.fakeOlderSubject,
                                  fakeText: widget.fakeOlderText),
                              builder: (context, snapshot) {
                                return RichText(
                                  text: TextSpan(
                                    children: snapshot.data ??
                                        MessageWidgetMixin.buildMessageSpans(context, msg,
                                            colorOverride: getBubbleColors(msg)[0].lightenOrDarken(30),
                                            fakeSubject: widget.fakeOlderSubject,
                                            fakeText: widget.fakeOlderText),
                                  ),
                                );
                              }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          // Add padding when we are showing the avatar
          padding: EdgeInsets.only(
              top: (skin.value != Skins.iOS && widget.message.isFromMe == widget.olderMessage?.isFromMe) ? 3.0 : 0.0,
              left: (!widget.showTail && (showSender || skin.value == Skins.Samsung)) ? 35.0 : 0.0,
              bottom: (widget.showTail && skin.value == Skins.iOS) ? 10.0 : 0.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: (skin.value == Skins.iOS || skin.value == Skins.Material)
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: skin.value == Skins.Samsung ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: msgRow,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.message.expressiveSendStyleId != null)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if ((stringToMessageEffect[effect] ?? MessageEffect.none).isBubble) {
                              if (effect == "invisible ink" && controller == CustomAnimationControl.playFromStart) {
                                setState(() {
                                  controller = CustomAnimationControl.stop;
                                });
                              } else {
                                setState(() {
                                  controller = CustomAnimationControl.playFromStart;
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
                                  padding: EdgeInsets.only(left: addedAvatar ? 50 : 18, right: 8.0, top: 2, bottom: 4),
                                  child: Row(children: [
                                    Icon(Icons.refresh, size: 10, color: Theme.of(context).primaryColor),
                                    Text(
                                      " sent with $effect",
                                      style: Theme.of(context)
                                          .textTheme
                                          .subtitle2!
                                          .copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                    ),
                                  ]),
                                )
                              : Padding(
                                  padding: EdgeInsets.only(left: addedAvatar ? 50 : 18, right: 8.0, top: 2, bottom: 4),
                                  child: Text(
                                    "↺ sent with $effect",
                                    style: Theme.of(context)
                                        .textTheme
                                        .subtitle2!
                                        .copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                  ),
                                ),
                        ),
                      Obx(() {
                        final list =
                            widget.messageBloc?.threadOriginators.values.where((e) => e == widget.message.guid) ??
                                [].obs.reversed;
                        if (list.isNotEmpty) {
                          return GestureDetector(
                            onTap: () {
                              showReplyThread(context, widget.message, widget.messageBloc);
                            },
                            child: Padding(
                              padding: EdgeInsets.only(left: addedAvatar ? 50 : 18, right: 8.0, top: 2, bottom: 4),
                              child: Text(
                                "${list.length} repl${list.length > 1 ? "ies" : "y"}",
                                style: Theme.of(context)
                                    .textTheme
                                    .subtitle2!
                                    .copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                              ),
                            ),
                          );
                        } else {
                          return Container();
                        }
                      }),
                    ],
                  ),
                  // Add the timestamp for the samsung theme
                  if (skin.value == Skins.Samsung &&
                      widget.message.dateCreated != null &&
                      (widget.newerMessage?.dateCreated == null ||
                          widget.message.isFromMe != widget.newerMessage?.isFromMe ||
                          widget.message.handleId != widget.newerMessage?.handleId ||
                          !widget.message.dateCreated!.isWithin(widget.newerMessage!.dateCreated!, minutes: 5)))
                    Padding(
                      padding: EdgeInsets.only(top: 5, left: addedAvatar ? 50 : 15),
                      child: MessageTimeStamp(
                        message: widget.message,
                        singleLine: true,
                        useYesterday: true,
                      ),
                    )
                ]),
                popupChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: skin.value == Skins.Samsung ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: msgPopupRow,
                ),
              ),
              if (!kIsDesktop &&
                  !kIsWeb &&
                  skin.value != Skins.Samsung &&
                  widget.message.guid != widget.olderMessage?.guid)
                MessageTimeStamp(
                  message: widget.message,
                )
            ],
          ),
        ),
      ],
    );
  }
}
