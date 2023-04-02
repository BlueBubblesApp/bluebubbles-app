import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/embedded_media.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/reaction_picker_clipper.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/components/custom/custom_cupertino_alert_dialog.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:sprung/sprung.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:universal_io/io.dart';

class MessagePopup extends StatefulWidget {
  final Offset childPosition;
  final Size size;
  final Widget child;
  final MessagePart part;
  final MessageWidgetController controller;
  final ConversationViewController cvController;
  final Tuple3<bool, bool, bool> serverDetails;
  final Function([String? type, int? part]) sendTapback;
  final BuildContext? Function() widthContext;

  const MessagePopup({
    Key? key,
    required this.childPosition,
    required this.size,
    required this.child,
    required this.part,
    required this.controller,
    required this.cvController,
    required this.serverDetails,
    required this.sendTapback,
    required this.widthContext,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MessagePopupState();
}

class _MessagePopupState extends OptimizedState<MessagePopup> with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
    animationBehavior: AnimationBehavior.preserve,
  );
  final double itemHeight = kIsDesktop || kIsWeb ? 56 : 48;

  List<Message> reactions = [];
  late double messageOffset = Get.height - widget.childPosition.dy - widget.size.height;
  late double materialOffset = widget.childPosition.dy +
      EdgeInsets.fromWindowPadding(
        WidgetsBinding.instance.window.viewInsets,
        WidgetsBinding.instance.window.devicePixelRatio,
      ).bottom;
  late int numberToShow = 5;
  late Chat? dmChat = chats.chats
      .firstWhereOrNull((chat) => !chat.isGroup && chat.participants.firstWhereOrNull((handle) => handle.address == message.handle?.address) != null);
  String? selfReaction;
  String? currentlySelectedReaction = "init";

  ConversationViewController get cvController => widget.cvController;

  MessagesService get service => ms(chat.guid);

  Chat get chat => widget.cvController.chat;

  MessagePart get part => widget.part;

  Message get message => widget.controller.message;

  bool get isSent => !message.guid!.startsWith('temp') && !message.guid!.startsWith('error');

  bool get showDownload =>
      (isSent && part.attachments.isNotEmpty && part.attachments.where((element) => as.getContent(element) is PlatformFile).isNotEmpty) || isEmbeddedMedia;

  late bool isEmbeddedMedia = (message.balloonBundleId == "com.apple.Handwriting.HandwritingProvider"
      || message.balloonBundleId == "com.apple.DigitalTouchBalloonProvider")
      && File(message.interactiveMediaPath!).existsSync();

  bool get minSierra => widget.serverDetails.item1;

  bool get minBigSur => widget.serverDetails.item2;

  bool get supportsOriginalDownload => widget.serverDetails.item3;

  BuildContext get widthContext => widget.widthContext.call() ?? context;

  @override
  void initState() {
    super.initState();
    controller.forward();
    final remainingHeight = max(Get.height - Get.statusBarHeight - 135 - widget.size.height, itemHeight);
    numberToShow = min(remainingHeight ~/ itemHeight, 5);

    updateObx(() {
      currentlySelectedReaction = null;
      reactions = getUniqueReactionMessages(message.associatedMessages
          .where((e) => ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")) && (e.associatedMessagePart ?? 0) == part.part)
          .toList());
      final self = reactions.firstWhereOrNull((e) => e.isFromMe!)?.associatedMessageType;
      if (!(self?.contains("-") ?? true)) {
        selfReaction = self;
        currentlySelectedReaction = selfReaction;
      }
      for (Message m in reactions) {
        if (m.isFromMe!) {
          m.handle = null;
        } else {
          m.handle ??= m.getHandle();
        }
      }
      setState(() {
        if (iOS) messageOffset = itemHeight * numberToShow + 40;
      });
    });
  }

  void popDetails({bool returnVal = true}) {
    bool dialogOpen = Get.isDialogOpen ?? false;
    if (dialogOpen) {
      if (kIsWeb) {
        Get.back();
      } else {
        Navigator.of(context).pop();
      }
    }
    Navigator.of(context).pop(returnVal);
  }

  @override
  Widget build(BuildContext context) {
    double narrowWidth = message.isFromMe! || !ss.settings.alwaysShowAvatars.value ? 330 : 360;
    bool narrowScreen = ns.width(widthContext) < narrowWidth;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness.opposite,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Theme(
        data: context.theme.copyWith(
          // in case some components still use legacy theming
          primaryColor: context.theme.colorScheme.bubble(context, chat.isIMessage),
          colorScheme: context.theme.colorScheme.copyWith(
            primary: context.theme.colorScheme.bubble(context, chat.isIMessage),
            onPrimary: context.theme.colorScheme.onBubble(context, chat.isIMessage),
            surface:
                ss.settings.monetTheming.value == Monet.full ? null : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
            onSurface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
          ),
        ),
        child: TitleBarWrapper(
            child: Scaffold(
                extendBodyBehindAppBar: true,
                backgroundColor: kIsDesktop && iOS && ss.settings.windowEffect.value != WindowEffect.disabled
                    ? context.theme.colorScheme.properSurface.withOpacity(0.6)
                    : Colors.transparent,
                appBar: iOS
                    ? null
                    : AppBar(
                        backgroundColor: ((kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled)
                                ? context.theme.colorScheme.background.withOpacity(0.6)
                                : context.theme.colorScheme.background)
                            .oppositeLightenOrDarken(5),
                        systemOverlayStyle:
                            context.theme.colorScheme.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                        automaticallyImplyLeading: false,
                        leadingWidth: 40,
                        toolbarHeight: kIsDesktop ? 80 : null,
                        leading: Padding(
                          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0, left: 10.0),
                          child: BackButton(
                            color: context.theme.colorScheme.onBackground,
                            onPressed: () {
                              popDetails();
                              return true;
                            },
                          ),
                        ),
                        actions: [
                            //copy
                            //delete
                            //snooze
                            //popup: share, forward, details
                            if (showDownload)
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: IconButton(
                                  icon: Icon(Icons.file_download, color: context.theme.colorScheme.properOnSurface),
                                  onPressed: download,
                                ),
                              ),
                            if ((part.text?.hasUrl ?? false) && !kIsWeb && !kIsDesktop && !ls.isBubble)
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: IconButton(
                                  icon: Icon(Icons.open_in_browser, color: context.theme.colorScheme.properOnSurface),
                                  onPressed: openLink,
                                ),
                              ),
                            if (showDownload && kIsWeb && part.attachments.firstOrNull?.webUrl != null)
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: IconButton(
                                  icon: Icon(Icons.open_in_browser, color: context.theme.colorScheme.properOnSurface),
                                  onPressed: openAttachmentWeb,
                                ),
                              ),
                            if (!isNullOrEmptyString(part.fullText))
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: GestureDetector(
                                  onLongPress: copySelection,
                                  child: IconButton(
                                    icon: Icon(Icons.content_copy, color: context.theme.colorScheme.properOnSurface),
                                    onPressed: copyText,
                                  ),
                                ),
                              ),
                            if (chat.isGroup && !message.isFromMe! && dmChat != null && !ls.isBubble)
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: IconButton(
                                  icon: Icon(Icons.open_in_new, color: context.theme.colorScheme.properOnSurface),
                                  onPressed: openDm,
                                ),
                              ),
                            if (message.threadOriginatorGuid != null || service.struct.threads(message.guid!, part.part, returnOriginator: false).isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: IconButton(
                                  icon: Icon(Icons.forum_outlined, color: context.theme.colorScheme.properOnSurface),
                                  onPressed: showThread,
                                ),
                              ),
                            if (chat.isGroup && !message.isFromMe! && dmChat == null && !ls.isBubble)
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: IconButton(
                                  icon: Icon(Icons.message_outlined, color: context.theme.colorScheme.properOnSurface),
                                  onPressed: newConvo,
                                ),
                              ),
                            if (showDownload)
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: IconButton(
                                  icon: Icon(Icons.refresh, color: context.theme.colorScheme.properOnSurface),
                                  onPressed: redownload,
                                ),
                              ),
                            if (!kIsWeb && !kIsDesktop)
                              Padding(
                                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                                child: IconButton(
                                  icon: Icon(Icons.alarm, color: context.theme.colorScheme.properOnSurface),
                                  onPressed: remindLater,
                                ),
                              ),
                            Padding(
                              padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                              child: IconButton(
                                icon: Icon(Icons.delete_outlined, color: context.theme.colorScheme.properOnSurface),
                                onPressed: delete,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                              child: PopupMenuButton<int>(
                                color: context.theme.colorScheme.properSurface,
                                shape: ss.settings.skin.value != Skins.Material
                                    ? const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(20.0),
                                        ),
                                      )
                                    : null,
                                onSelected: (int value) {
                                  if (value == 0) {
                                    share();
                                  } else if (value == 1) {
                                    forward();
                                  } else if (value == 2) {
                                    selectMultiple();
                                  } else if (value == 3) {
                                    messageInfo();
                                  } else if (value == 4) {
                                    downloadOriginal();
                                  } else if (value == 5) {
                                    createContact();
                                  } else if (value == 6) {
                                    unsend();
                                  } else if (value == 7) {
                                    edit();
                                  } else if (value == 8) {
                                    downloadLivePhoto();
                                  } else if (value == 9) {
                                    toggleBookmark();
                                  }
                                },
                                itemBuilder: (context) {
                                  return <PopupMenuItem<int>>[
                                    if ((part.attachments.isNotEmpty && !kIsWeb && !kIsDesktop) || (part.text!.isNotEmpty && !kIsDesktop))
                                      PopupMenuItem(
                                        value: 0,
                                        child: Text(
                                          'Share',
                                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (!ls.isBubble && !message.isInteractive)
                                      PopupMenuItem(
                                        value: 1,
                                        child: Text(
                                          'Forward',
                                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (ss.isMinVenturaSync &&
                                        message.isFromMe! &&
                                        !message.guid!.startsWith("temp") &&
                                        ss.serverDetailsSync().item4 >= 148)
                                      PopupMenuItem(
                                        value: 6,
                                        child: Text(
                                          'Undo Send',
                                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (ss.isMinVenturaSync &&
                                        message.isFromMe! &&
                                        !message.guid!.startsWith("temp") &&
                                        ss.serverDetailsSync().item4 >= 148 &&
                                        (part.text?.isNotEmpty ?? false))
                                      PopupMenuItem(
                                        value: 7,
                                        child: Text(
                                          'Edit',
                                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (!message.isFromMe! && message.handle != null && message.handle!.contact == null)
                                      PopupMenuItem(
                                        value: 5,
                                        child: Text(
                                          'Create Contact',
                                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 2,
                                      child: Text(
                                        'Select Multiple',
                                        style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 9,
                                      child: Text(
                                        message.isBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
                                        style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 3,
                                      child: Text(
                                        'Message Info',
                                        style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                      ),
                                    ),
                                    if (showDownload &&
                                        supportsOriginalDownload &&
                                        part.attachments
                                            .where((element) =>
                                                (element.uti?.contains("heic") ?? false) ||
                                                (element.uti?.contains("heif") ?? false) ||
                                                (element.uti?.contains("quicktime") ?? false) ||
                                                (element.uti?.contains("coreaudio") ?? false) ||
                                                (element.uti?.contains("tiff") ?? false))
                                            .isNotEmpty)
                                      PopupMenuItem(
                                        value: 4,
                                        child: Text(
                                          'Save Original',
                                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (showDownload && part.attachments.where((e) => e.hasLivePhoto).isNotEmpty)
                                      PopupMenuItem(
                                        value: 8,
                                        child: Text(
                                          'Save Live Photo',
                                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                  ];
                                },
                                icon: Icon(
                                  Icons.more_vert,
                                  color: context.theme.colorScheme.onBackground,
                                ),
                              ),
                            )
                          ]),
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: popDetails,
                      child: iOS
                          ? BackdropFilter(
                              filter: ImageFilter.blur(
                                  sigmaX: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled ? 10 : 30,
                                  sigmaY: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled ? 10 : 30),
                              child: Container(
                                color: context.theme.colorScheme.properSurface.withOpacity(0.3),
                              ),
                            )
                          : null,
                    ),
                    if (iOS)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutBack,
                        left: widget.childPosition.dx,
                        bottom: messageOffset,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.8, end: 1),
                          curve: Curves.easeOutBack,
                          duration: const Duration(milliseconds: 500),
                          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: widget.size.width), child: widget.child),
                          builder: (context, size, child) {
                            return Transform.scale(
                              scale: size.clamp(1, double.infinity),
                              child: child,
                              alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                            );
                          },
                        ),
                      ),
                    if (iOS)
                      Positioned(
                        top: 40,
                        left: 15,
                        right: 15,
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 500),
                          curve: Sprung.underDamped,
                          alignment: Alignment.center,
                          child: reactions.isNotEmpty ? ReactionDetails(reactions: reactions) : const SizedBox.shrink(),
                        ),
                      ),
                    if (ss.settings.enablePrivateAPI.value && isSent && minSierra && chat.isIMessage)
                      Positioned(
                        bottom: iOS ? itemHeight * numberToShow + 35 + widget.size.height : context.height - materialOffset,
                        right: message.isFromMe! ? 15 : null,
                        left: !message.isFromMe! ? widget.childPosition.dx + 10 : null,
                        child: AnimatedSize(
                          curve: Curves.easeInOut,
                          alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                          duration: const Duration(milliseconds: 250),
                          child: currentlySelectedReaction == "init"
                              ? const SizedBox(height: 80)
                              : Material(
                                  clipBehavior: Clip.antiAlias,
                                  color: Colors.transparent,
                                  elevation: !iOS ? 3 : 0,
                                  shadowColor: context.theme.colorScheme.background,
                                  borderRadius: BorderRadius.circular(20.0),
                                  child: ClipPath(
                                    clipper: ReactionPickerClipper(
                                      messageSize: widget.size,
                                      isFromMe: message.isFromMe!,
                                    ),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                      child: Container(
                                        padding: const EdgeInsets.all(5).add(const EdgeInsets.only(bottom: 15)),
                                        color: context.theme.colorScheme.properSurface.withAlpha(iOS ? 150 : 255).lightenOrDarken(iOS ? 0 : 10),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: List.generate(narrowScreen ? 2 : 1, (index) {
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                children: ReactionTypes.toList()
                                                    .slice(narrowScreen && index == 1 ? 3 : 0, narrowScreen && index == 0 ? 3 : null)
                                                    .map((e) {
                                                  return Padding(
                                                    padding: iOS ? const EdgeInsets.all(5.0) : const EdgeInsets.symmetric(horizontal: 5),
                                                    child: Material(
                                                      color: currentlySelectedReaction == e ? context.theme.colorScheme.primary : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(20),
                                                      child: SizedBox(
                                                        width: iOS ? 35 : null,
                                                        height: iOS ? 35 : null,
                                                        child: InkWell(
                                                          borderRadius: BorderRadius.circular(20),
                                                          onTap: () {
                                                            if (currentlySelectedReaction == e) {
                                                              currentlySelectedReaction = null;
                                                            } else {
                                                              currentlySelectedReaction = e;
                                                            }
                                                            setState(() {});
                                                            HapticFeedback.lightImpact();
                                                            widget.sendTapback(selfReaction == e ? "-$e" : e, part.part);
                                                            popDetails();
                                                          },
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.all(6.5).add(EdgeInsets.only(right: e == "emphasize" ? 2.5 : 0)),
                                                            child: iOS
                                                                ? SvgPicture.asset(
                                                                    'assets/reactions/$e-black.svg',
                                                                    colorFilter: ColorFilter.mode(e == "love" && currentlySelectedReaction == e
                                                                        ? Colors.pink
                                                                        : (currentlySelectedReaction == e
                                                                        ? context.theme.colorScheme.onPrimary
                                                                        : context.theme.colorScheme.outline), BlendMode.srcIn),
                                                                  )
                                                                : Center(
                                                                    child: Builder(builder: (context) {
                                                                      final text = Text(
                                                                        ReactionTypes.reactionToEmoji[e] ?? "X",
                                                                        style: const TextStyle(fontSize: 18, fontFamily: 'Apple Color Emoji'),
                                                                        textAlign: TextAlign.center,
                                                                      );
                                                                      // rotate thumbs down to match iOS
                                                                      if (e == "dislike") {
                                                                        return Transform(
                                                                          transform: Matrix4.identity()..rotateY(pi),
                                                                          alignment: FractionalOffset.center,
                                                                          child: text,
                                                                        );
                                                                      }
                                                                      return text;
                                                                    }),
                                                                  ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              );
                                            })),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    if (iOS)
                      Positioned(
                        right: message.isFromMe! ? 15 : null,
                        left: !message.isFromMe! ? widget.childPosition.dx + 10 : null,
                        bottom: 30,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.8, end: 1),
                          curve: Curves.easeOutBack,
                          duration: const Duration(milliseconds: 400),
                          child: FadeTransition(
                            opacity: CurvedAnimation(
                              parent: controller,
                              curve: const Interval(0.0, .9, curve: Curves.ease),
                              reverseCurve: Curves.easeInCubic,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                buildDetailsMenu(context),
                              ],
                            ),
                          ),
                          builder: (context, size, child) {
                            return Transform.scale(
                              scale: size,
                              child: child,
                            );
                          },
                        ),
                      ),
                    if (!iOS && ss.settings.enablePrivateAPI.value && minBigSur && chat.isIMessage && isSent)
                      Positioned(
                        left: !message.isFromMe!
                            ? widget.childPosition.dx + widget.size.width + (reactions.isNotEmpty ? 25 : 10)
                            : widget.childPosition.dx - 45,
                        top: materialOffset,
                        child: Material(
                          color: context.theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: 35,
                            height: 35,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: reply,
                              child: const Center(child: Icon(Icons.reply, size: 20)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ))),
      ),
    );
  }

  void reply() {
    popDetails();
    cvController.replyToMessage = Tuple2(message, part.part);
  }

  Future<void> download() async {
    try {
      dynamic content;
      if (isEmbeddedMedia) {
        content = PlatformFile(
          name: message.interactiveMediaPath!.split("/").last,
          path: message.interactiveMediaPath,
          size: 0,
        );
      } else {
        content = as.getContent(part.attachments.first);
      }
      if (content is PlatformFile) {
        popDetails();
        await as.saveToDisk(content);
      }
    } catch (ex, trace) {
      Logger.error(trace.toString());
      showSnackbar("Save Error", ex.toString());
    }
  }

  void openLink() {
    String? url = part.url;
    mcs.invokeMethod("open-link", {"link": url ?? part.text, "forceBrowser": true});
    popDetails();
  }

  Future<void> openAttachmentWeb() async {
    await launchUrlString("${part.attachments.first.webUrl!}?guid=${ss.settings.guidAuthKey}");
    popDetails();
  }

  void copyText() {
    Clipboard.setData(ClipboardData(text: part.fullText));
    popDetails();
    if (!Platform.isAndroid || (fs.androidInfo?.version.sdkInt ?? 0) < 33) {
      showSnackbar("Copied", "Copied to clipboard!");
    }
  }

  void copySelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text("Copy Selection", style: context.theme.textTheme.titleLarge),
        content: SelectableText(message.fullText, style: context.theme.extension<BubbleText>()!.bubbleText),
      ),
    );
  }

  Future<void> downloadOriginal() async {
    final RxBool downloadingAttachments = true.obs;
    final RxnDouble progress = RxnDouble();
    final Rxn<Attachment> attachmentObs = Rxn<Attachment>();
    final toDownload = part.attachments.where((element) =>
        (element.uti?.contains("heic") ?? false) ||
        (element.uti?.contains("heif") ?? false) ||
        (element.uti?.contains("quicktime") ?? false) ||
        (element.uti?.contains("coreaudio") ?? false) ||
        (element.uti?.contains("tiff") ?? false));
    final length = toDownload.length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text("Downloading attachment${length > 1 ? "s" : ""}...", style: context.theme.textTheme.titleLarge),
        content: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Obx(
            () => Text(
                '${progress.value != null && attachmentObs.value != null ? getSizeString(progress.value! * attachmentObs.value!.totalBytes! / 1000) : ""} / ${getSizeString(attachmentObs.value!.totalBytes!.toDouble() / 1000)} (${((progress.value ?? 0) * 100).floor()}%)',
                style: context.theme.textTheme.bodyLarge),
          ),
          const SizedBox(height: 10.0),
          Obx(
            () => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                backgroundColor: context.theme.colorScheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(Get.context!.theme.colorScheme.primary),
                value: progress.value,
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(
            height: 15.0,
          ),
          Obx(() => Text(
                progress.value == 1
                    ? "Download Complete!"
                    : "You can close this dialog. The attachment(s) will continue to download in the background.",
                maxLines: 2,
                textAlign: TextAlign.center,
                style: context.theme.textTheme.bodyLarge,
              )),
        ]),
        actions: [
          Obx(
            () => downloadingAttachments.value
                ? Container(height: 0, width: 0)
                : TextButton(
                    child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                    onPressed: () async {
                      if (Get.isSnackbarOpen ?? false) {
                        Get.close(1);
                      }
                      Navigator.of(context).pop();
                      popDetails();
                    },
                  ),
          ),
        ],
      ),
    );
    try {
      for (Attachment? element in toDownload) {
        attachmentObs.value = element;
        final response = await http.downloadAttachment(element!.guid!,
            original: true, onReceiveProgress: (count, total) => progress.value = kIsWeb ? (count / total) : (count / element.totalBytes!));
        final file = PlatformFile(
          name: element.transferName!,
          size: response.data.length,
          bytes: response.data,
        );
        await as.saveToDisk(file);
      }
      progress.value = 1;
      downloadingAttachments.value = false;
    } catch (ex, trace) {
      Logger.error(trace.toString());
      showSnackbar("Download Error", ex.toString());
    }
  }

  Future<void> downloadLivePhoto() async {
    final RxBool downloadingAttachments = true.obs;
    final RxnDouble progress = RxnDouble();
    final Rxn<Attachment> attachmentObs = Rxn<Attachment>();
    final toDownload = part.attachments.where((element) => element.hasLivePhoto);
    final length = toDownload.length;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.theme.colorScheme.properSurface,
        title: Text("Downloading live photo${length > 1 ? "s" : ""}...", style: context.theme.textTheme.titleLarge),
        content: Column(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Obx(
                () => Text(
                '${progress.value != null && attachmentObs.value != null ? getSizeString(progress.value! * attachmentObs.value!.totalBytes! / 1000) : ""} / ${getSizeString(attachmentObs.value!.totalBytes!.toDouble() / 1000)} (${((progress.value ?? 0) * 100).floor()}%)',
                style: context.theme.textTheme.bodyLarge),
          ),
          const SizedBox(height: 10.0),
          Obx(
                () => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                backgroundColor: context.theme.colorScheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(Get.context!.theme.colorScheme.primary),
                value: progress.value,
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(
            height: 15.0,
          ),
          Obx(() => Text(
            progress.value == 1
                ? "Download Complete!"
                : "You can close this dialog. The live photo(s) will continue to download in the background.",
            maxLines: 2,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.bodyLarge,
          )),
        ]),
        actions: [
          Obx(
                () => downloadingAttachments.value
                ? Container(height: 0, width: 0)
                : TextButton(
              child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
              onPressed: () async {
                if (Get.isSnackbarOpen ?? false) {
                  Get.close(1);
                }
                Navigator.of(context).pop();
                popDetails();
              },
            ),
          ),
        ],
      ),
    );
    try {
      for (Attachment? element in toDownload) {
        attachmentObs.value = element;
        final response = await http.downloadLivePhoto(element!.guid!,
            onReceiveProgress: (count, total) => progress.value = kIsWeb ? (count / total) : (count / element.totalBytes!));
        final nameSplit = element.transferName!.split(".");
        final file = PlatformFile(
          name: "${nameSplit.take(nameSplit.length - 1).join(".")}.mov",
          size: response.data.length,
          bytes: response.data,
        );
        await as.saveToDisk(file);
      }
      progress.value = 1;
      downloadingAttachments.value = false;
    } catch (ex, trace) {
      Logger.error(trace.toString());
      showSnackbar("Download Error", ex.toString());
    }
  }

  void openDm() {
    popDetails();
    Navigator.pushReplacement(
      context,
      cupertino.CupertinoPageRoute(
        builder: (BuildContext context) {
          return ConversationView(
            chat: dmChat!,
          );
        },
      ),
    );
  }

  void createContact() async {
    popDetails();
    await mcs
        .invokeMethod("open-contact-form", {'address': message.handle!.address, 'addressType': message.handle!.address.isEmail ? 'email' : 'phone'});
  }

  void showThread() {
    popDetails();
    if (message.threadOriginatorGuid != null) {
      final mwc = getActiveMwc(message.threadOriginatorGuid!);
      if (mwc == null) return showSnackbar("Error", "Failed to find thread!");
      showReplyThread(context, mwc.message, mwc.parts[message.normalizedThreadPart], service, cvController);
    } else {
      showReplyThread(context, message, part, service, cvController);
    }
  }

  void newConvo() {
    Handle? handle = message.handle;
    if (handle == null) return;
    popDetails();
    ns.pushAndRemoveUntil(
      context,
      ChatCreator(initialSelected: [SelectedContact(displayName: handle.displayName, address: handle.address)]),
      (route) => route.isFirst,
    );
  }

  void forward() async {
    popDetails();
    List<PlatformFile> attachments = [];
    final _attachments = message.attachments
        .where((e) => as.getContent(e!, autoDownload: false) is PlatformFile)
        .map((e) => as.getContent(e!, autoDownload: false) as PlatformFile);
    for (PlatformFile a in _attachments) {
      Uint8List? bytes = a.bytes;
      bytes ??= await File(a.path!).readAsBytes();
      attachments.add(PlatformFile(
        name: a.name,
        path: a.path,
        size: bytes.length,
        bytes: bytes,
      ));
    }
    if (attachments.isNotEmpty || !isNullOrEmpty(message.text)!) {
      ns.pushAndRemoveUntil(
        context,
        ChatCreator(
          initialText: message.text,
          initialAttachments: attachments,
        ),
        (route) => route.isFirst,
      );
    }
  }

  void redownload() {
    if (isEmbeddedMedia) {
      popDetails();
      getActiveMwc(message.guid!)?.updateWidgets<EmbeddedMedia>(null);
    } else {
      for (Attachment? element in part.attachments) {
        widget.cvController.imageData.remove(element!.guid!);
        as.redownloadAttachment(element);
      }
      popDetails();
      getActiveMwc(message.guid!)?.updateWidgets<AttachmentHolder>(null);
    }
  }

  void share() {
    if (part.attachments.isNotEmpty && !message.isLegacyUrlPreview && !kIsWeb && !kIsDesktop) {
      for (Attachment? element in part.attachments) {
        Share.file(
          "${element!.mimeType!.split("/")[0].capitalizeFirst} shared from BlueBubbles: ${element.transferName}",
          element.path,
        );
      }
    } else if (part.text!.isNotEmpty) {
      Share.text(
        "Text shared from BlueBubbles",
        part.text!,
      );
    }
    popDetails();
  }

  Future<void> remindLater() async {
    final finalDate = await showTimeframePicker("Select Reminder Time", context, presetsAhead: true);
    if (finalDate != null) {
      if (!finalDate.isAfter(DateTime.now().toLocal())) {
        showSnackbar("Error", "Select a date in the future");
        return;
      }
      await notif.createReminder(chat, message, finalDate);
      popDetails();
      showSnackbar("Notice", "Scheduled reminder for ${buildDate(finalDate)}");
    }
  }

  void unsend() {
    http.unsend(message.guid!, partIndex: part.part);
    popDetails();
  }

  void edit() async {
    final node = FocusNode();
    cvController.editing.add(Tuple4(message, part, TextEditingController(text: part.text!), node));
    popDetails();
  }

  void delete() {
    service.removeMessage(message);
    Message.softDelete(message.guid!);
    popDetails();
  }

  void selectMultiple() {
    cvController.inSelectMode.toggle();
    if (iOS) {
      cvController.selected.add(message);
    }
    popDetails(returnVal: false);
  }

  void toggleBookmark() {
    message.isBookmarked = !message.isBookmarked;
    message.save(updateIsBookmarked: true);
    popDetails();
  }

  void messageInfo() {
    const encoder = JsonEncoder.withIndent("     ");
    final str = encoder.convert(message.toMap(includeObjects: true));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Message Info",
          style: context.theme.textTheme.titleLarge,
        ),
        backgroundColor: context.theme.colorScheme.properSurface,
        content: SizedBox(
          width: ns.width(widthContext) * 3 / 5,
          height: context.height * 1 / 4,
          child: Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(color: context.theme.colorScheme.background, borderRadius: const BorderRadius.all(Radius.circular(10))),
            child: SingleChildScrollView(
              child: SelectableText(
                str,
                style: context.theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget buildDetailsMenu(BuildContext context) {
    double maxMenuWidth = min(max(ns.width(widthContext) * 3 / 5, 200), ns.width(widthContext) * 4 / 5);

    List<Widget> allActions = [
      if (ss.settings.enablePrivateAPI.value && minBigSur && chat.isIMessage && isSent)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: reply,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Reply",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.reply : Icons.reply,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: download,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Save",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.cloud_download : Icons.file_download,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if ((part.text?.hasUrl ?? false) && !kIsWeb && !kIsDesktop && !ls.isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openLink,
            child: ListTile(
              mouseCursor: MouseCursor.defer,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Open In Browser",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.macwindow : Icons.open_in_browser,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload && kIsWeb && part.attachments.firstOrNull?.webUrl != null)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openAttachmentWeb,
            child: ListTile(
              mouseCursor: MouseCursor.defer,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Open In New Tab",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.macwindow : Icons.open_in_browser,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (!isNullOrEmptyString(part.fullText))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: copyText,
            onLongPress: copySelection,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text("Copy", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.doc_on_clipboard : Icons.content_copy,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload &&
          supportsOriginalDownload &&
          part.attachments
              .where((element) =>
                  (element.uti?.contains("heic") ?? false) ||
                  (element.uti?.contains("heif") ?? false) ||
                  (element.uti?.contains("quicktime") ?? false) ||
                  (element.uti?.contains("coreaudio") ?? false) ||
                  (element.uti?.contains("tiff") ?? false))
              .isNotEmpty)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: downloadOriginal,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Save Original",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.cloud_download : Icons.file_download,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload && part.attachments.where((e) => e.hasLivePhoto).isNotEmpty)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: downloadLivePhoto,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Save Live Photo",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.photo : Icons.motion_photos_on_outlined,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (chat.isGroup && !message.isFromMe! && dmChat != null && !ls.isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: openDm,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Open Direct Message",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.arrow_up_right_square : Icons.open_in_new,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (message.threadOriginatorGuid != null || service.struct.threads(message.guid!, part.part, returnOriginator: false).isNotEmpty)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: showThread,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "View Thread",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.bubble_left_bubble_right : Icons.forum,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (chat.isGroup && !message.isFromMe! && dmChat == null && !ls.isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: newConvo,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Start Conversation",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.chat_bubble : Icons.message,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (!ls.isBubble && !message.isInteractive)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: forward,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Forward",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.arrow_right : Icons.forward,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if ((part.attachments.isNotEmpty && !kIsWeb && !kIsDesktop) || (!kIsWeb && !kIsDesktop && !isNullOrEmpty(part.text)!))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: share,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Share",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.share : Icons.share,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: redownload,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Re-download from Server",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.refresh : Icons.refresh,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (!kIsWeb && !kIsDesktop)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: remindLater,
            child: ListTile(
              mouseCursor: MouseCursor.defer,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Remind Later",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.alarm : Icons.alarm,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (!message.isFromMe! && message.handle != null && message.handle!.contact == null)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: createContact,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Create Contact",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.person_crop_circle_badge_plus : Icons.contact_page_outlined,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (ss.isMinVenturaSync && message.isFromMe! && !message.guid!.startsWith("temp") && ss.serverDetailsSync().item4 >= 148)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: unsend,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Undo Send",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.arrow_uturn_left : Icons.undo,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (ss.isMinVenturaSync &&
          message.isFromMe! &&
          !message.guid!.startsWith("temp") &&
          ss.serverDetailsSync().item4 >= 148 &&
          (part.text?.isNotEmpty ?? false))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: edit,
            child: ListTile(
              mouseCursor: SystemMouseCursors.click,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Edit",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.pencil : Icons.edit_outlined,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: delete,
          child: ListTile(
            mouseCursor: SystemMouseCursors.click,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              "Delete",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.trash : Icons.delete,
              color: context.theme.colorScheme.properOnSurface,
            ),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: toggleBookmark,
          child: ListTile(
            mouseCursor: SystemMouseCursors.click,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              message.isBookmarked ? "Remove Bookmark" : "Add Bookmark",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.bookmark : Icons.bookmark_outlined,
              color: context.theme.colorScheme.properOnSurface,
            ),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selectMultiple,
          child: ListTile(
            mouseCursor: SystemMouseCursors.click,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              "Select Multiple",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.checkmark_square : Icons.check_box_outlined,
              color: context.theme.colorScheme.properOnSurface,
            ),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: messageInfo,
          child: ListTile(
            mouseCursor: SystemMouseCursors.click,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              "Message Info",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.info : Icons.info,
              color: context.theme.colorScheme.properOnSurface,
            ),
          ),
        ),
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: context.theme.colorScheme.properSurface.withAlpha(150),
          width: maxMenuWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: allActions.sublist(0, numberToShow - 1)
              ..add(
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      Widget content = Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: allActions.sublist(numberToShow - 1),
                      );
                      Get.dialog(
                          ss.settings.skin.value == Skins.iOS
                              ? CupertinoAlertDialog(
                                  backgroundColor: context.theme.colorScheme.properSurface,
                                  content: content,
                                )
                              : AlertDialog(
                                  backgroundColor: context.theme.colorScheme.properSurface,
                                  content: content,
                                ),
                          name: 'Popup Menu');
                    },
                    child: ListTile(
                      mouseCursor: SystemMouseCursors.click,
                      dense: !kIsDesktop && !kIsWeb,
                      title: Text("More...", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)),
                      trailing: Icon(
                        ss.settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.ellipsis : Icons.more_vert,
                        color: context.theme.colorScheme.properOnSurface,
                      ),
                    ),
                  ),
                ),
              ),
          ),
        ),
      ),
    );
  }
}

class ReactionDetails extends StatelessWidget {
  const ReactionDetails({
    Key? key,
    required this.reactions,
  }) : super(key: key);

  final List<Message> reactions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          alignment: Alignment.center,
          height: 120,
          color: context.theme.colorScheme.properSurface.withAlpha(ss.settings.skin.value == Skins.iOS ? 150 : 255),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: ListView.builder(
              shrinkWrap: true,
              physics: ThemeSwitcher.getScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final message = reactions[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
                      child: ContactAvatarWidget(
                        handle: message.handle,
                        borderThickness: 0.1,
                        editable: false,
                        fontSize: 22,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        message.isFromMe! ? "You" : (message.handle?.displayName ?? "Unknown"),
                        style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                      ),
                    ),
                    Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: message.isFromMe! ? context.theme.colorScheme.primary : context.theme.colorScheme.properSurface,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 1.0,
                            color: context.theme.colorScheme.outline,
                          )
                        ],
                      ),
                      child: Padding(
                        padding: ss.settings.skin.value == Skins.iOS
                            ? const EdgeInsets.only(top: 8.0, left: 7.0, right: 7.0, bottom: 7.0)
                                .add(EdgeInsets.only(right: message.associatedMessageType == "emphasize" ? 1 : 0))
                            : EdgeInsets.zero,
                        child: ss.settings.skin.value == Skins.iOS
                            ? SvgPicture.asset(
                                'assets/reactions/${message.associatedMessageType}-black.svg',
                                colorFilter: ColorFilter.mode(message.associatedMessageType == "love"
                                    ? Colors.pink
                                    : message.isFromMe!
                                    ? context.theme.colorScheme.onPrimary
                                    : context.theme.colorScheme.properOnSurface, BlendMode.srcIn),
                              )
                            : Center(
                                child: Builder(builder: (context) {
                                  final text = Text(
                                    ReactionTypes.reactionToEmoji[message.associatedMessageType] ?? "X",
                                    style: const TextStyle(fontSize: 18, fontFamily: 'Apple Color Emoji'),
                                    textAlign: TextAlign.center,
                                  );
                                  // rotate thumbs down to match iOS
                                  if (message.associatedMessageType == "dislike") {
                                    return Transform(
                                      transform: Matrix4.identity()..rotateY(pi),
                                      alignment: FractionalOffset.center,
                                      child: text,
                                    );
                                  }
                                  return text;
                                }),
                              ),
                      ),
                    )
                  ],
                );
              },
              itemCount: reactions.length,
            ),
          ),
        ),
      ),
    );
  }
}
