import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_details/dialogs/timeframe_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/embedded_media.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/reaction_picker_clipper.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/components/custom/custom_cupertino_alert_dialog.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_pin_clipper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' hide context;
import 'package:permission_handler/permission_handler.dart';
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
    super.key,
    required this.childPosition,
    required this.size,
    required this.child,
    required this.part,
    required this.controller,
    required this.cvController,
    required this.serverDetails,
    required this.sendTapback,
    required this.widthContext,
  });

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
      EdgeInsets.fromViewPadding(
        View.of(context).viewInsets,
        View.of(context).devicePixelRatio,
      ).bottom;
  late int numberToShow = 5;
  late Chat? dmChat = GlobalChatService.chats.firstWhereOrNull((chat) =>
      !chat.isGroup &&
      chat.participants.firstWhereOrNull((handle) => handle.address == message.handle?.address) != null);
  String? selfReaction;
  String? currentlySelectedReaction = "init";

  ConversationViewController get cvController => widget.cvController;

  MessagesService get service => ms(chat.guid);

  Chat get chat => GlobalChatService.getChat(widget.cvController.chatGuid)!.chat;

  MessagePart get part => widget.part;

  Message get message => widget.controller.message;

  bool get isSent => !message.guid!.startsWith('temp') && !message.guid!.startsWith('error');

  bool get showDownload =>
      (isSent &&
          part.attachments.isNotEmpty &&
          part.attachments.where((element) => as.getContent(element) is PlatformFile).isNotEmpty) ||
      isEmbeddedMedia;

  late bool isEmbeddedMedia = (message.balloonBundleId == "com.apple.Handwriting.HandwritingProvider" ||
          message.balloonBundleId == "com.apple.DigitalTouchBalloonProvider") &&
      File(message.interactiveMediaPath!).existsSync();

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
          .where((e) =>
              ReactionTypes.toList().contains(e.associatedMessageType?.replaceAll("-", "")) &&
              (e.associatedMessagePart ?? 0) == part.part)
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
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent
            : context.theme.colorScheme.background, // navigation bar color
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
            surface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
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
                        systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
                            ? SystemUiOverlayStyle.light
                            : SystemUiOverlayStyle.dark,
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
                            if (message.threadOriginatorGuid != null ||
                                service.struct.threads(message.guid!, part.part, returnOriginator: false).isNotEmpty)
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
                                  } else if (value == 10) {
                                    copySelection();
                                  }
                                },
                                itemBuilder: (context) {
                                  return <PopupMenuItem<int>>[
                                    if ((part.attachments.isNotEmpty && !kIsWeb && !kIsDesktop) ||
                                        (part.text!.isNotEmpty && !kIsDesktop))
                                      PopupMenuItem(
                                        value: 0,
                                        child: Text(
                                          'Share',
                                          style: context.textTheme.bodyLarge!
                                              .apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (!ls.isBubble && !message.isInteractive)
                                      PopupMenuItem(
                                        value: 1,
                                        child: Text(
                                          'Forward',
                                          style: context.textTheme.bodyLarge!
                                              .apply(color: context.theme.colorScheme.properOnSurface),
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
                                          style: context.textTheme.bodyLarge!
                                              .apply(color: context.theme.colorScheme.properOnSurface),
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
                                          style: context.textTheme.bodyLarge!
                                              .apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (!message.isFromMe! && message.handle != null && message.handle!.contact == null)
                                      PopupMenuItem(
                                        value: 5,
                                        child: Text(
                                          'Create Contact',
                                          style: context.textTheme.bodyLarge!
                                              .apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 2,
                                      child: Text(
                                        'Select Multiple',
                                        style: context.textTheme.bodyLarge!
                                            .apply(color: context.theme.colorScheme.properOnSurface),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 9,
                                      child: Text(
                                        message.isBookmarked ? 'Remove Bookmark' : 'Add Bookmark',
                                        style: context.textTheme.bodyLarge!
                                            .apply(color: context.theme.colorScheme.properOnSurface),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 3,
                                      child: Text(
                                        'Message Info',
                                        style: context.textTheme.bodyLarge!
                                            .apply(color: context.theme.colorScheme.properOnSurface),
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
                                          style: context.textTheme.bodyLarge!
                                              .apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (showDownload && part.attachments.where((e) => e.hasLivePhoto).isNotEmpty)
                                      PopupMenuItem(
                                        value: 8,
                                        child: Text(
                                          'Save Live Photo',
                                          style: context.textTheme.bodyLarge!
                                              .apply(color: context.theme.colorScheme.properOnSurface),
                                        ),
                                      ),
                                    if (!isNullOrEmptyString(part.fullText) && (kIsDesktop || kIsWeb))
                                      PopupMenuItem(
                                        value: 10,
                                        child: Text(
                                          'Copy Selection',
                                          style: context.textTheme.bodyLarge!
                                              .apply(color: context.theme.colorScheme.properOnSurface),
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
                          ? (ss.settings.highPerfMode.value
                              ? Container(color: context.theme.colorScheme.background.withOpacity(0.8))
                              : BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled
                                          ? 10
                                          : 30,
                                      sigmaY: kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled
                                          ? 10
                                          : 30),
                                  child: Container(
                                    color: context.theme.colorScheme.properSurface.withOpacity(0.3),
                                  ),
                                ))
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
                          child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: widget.size.width), child: widget.child),
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
                        bottom: (iOS
                                ? itemHeight * numberToShow + 35 + widget.size.height
                                : context.height - materialOffset)
                            .clamp(0, context.height - (narrowScreen ? 200 : 125)),
                        right: message.isFromMe! ? 15 : null,
                        left: !message.isFromMe! ? widget.childPosition.dx + 10 : null,
                        child: AnimatedSize(
                          curve: Curves.easeInOut,
                          alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                          duration: const Duration(milliseconds: 250),
                          child: currentlySelectedReaction == "init"
                              ? const SizedBox(height: 80)
                              : ClipShadowPath(
                                  shadow: iOS
                                      ? BoxShadow(
                                          color: context.theme.colorScheme.properSurface
                                              .withAlpha(iOS ? 150 : 255)
                                              .lightenOrDarken(iOS ? 0 : 10))
                                      : BoxShadow(
                                          color: context.theme.colorScheme.shadow,
                                          blurRadius: 2,
                                        ),
                                  clipper: ReactionPickerClipper(
                                    messageSize: widget.size,
                                    isFromMe: message.isFromMe!,
                                  ),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                    child: Container(
                                      padding: const EdgeInsets.all(5).add(const EdgeInsets.only(bottom: 15)),
                                      color: context.theme.colorScheme.properSurface
                                          .withAlpha(iOS ? 150 : 255)
                                          .lightenOrDarken(iOS ? 0 : 10),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(narrowScreen ? 2 : 1, (index) {
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              children: ReactionTypes.toList()
                                                  .slice(narrowScreen && index == 1 ? 3 : 0,
                                                      narrowScreen && index == 0 ? 3 : null)
                                                  .map((e) {
                                                return Padding(
                                                  padding: iOS
                                                      ? const EdgeInsets.all(5.0)
                                                      : const EdgeInsets.symmetric(horizontal: 5),
                                                  child: Material(
                                                    color: currentlySelectedReaction == e
                                                        ? context.theme.colorScheme.primary
                                                        : Colors.transparent,
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
                                                          padding: const EdgeInsets.all(6.5)
                                                              .add(EdgeInsets.only(right: e == "emphasize" ? 2.5 : 0)),
                                                          child: iOS
                                                              ? SvgPicture.asset(
                                                                  'assets/reactions/$e-black.svg',
                                                                  colorFilter: ColorFilter.mode(
                                                                      e == "love" && currentlySelectedReaction == e
                                                                          ? Colors.pink
                                                                          : (currentlySelectedReaction == e
                                                                              ? context.theme.colorScheme.onPrimary
                                                                              : context.theme.colorScheme.outline),
                                                                      BlendMode.srcIn),
                                                                )
                                                              : Center(
                                                                  child: Builder(builder: (context) {
                                                                    final text = Text(
                                                                      ReactionTypes.reactionToEmoji[e] ?? "X",
                                                                      style: const TextStyle(
                                                                          fontSize: 18,
                                                                          fontFamily: 'Apple Color Emoji'),
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
          name: basename(message.interactiveMediaPath!),
          path: message.interactiveMediaPath,
          size: 0,
        );
      } else {
        content = as.getContent(part.attachments.first);
      }
      if (content is PlatformFile) {
        popDetails();
        await as.saveToDisk(content,
            isDocument: part.attachments.first.mimeStart != "image" && part.attachments.first.mimeStart != "video");
      }
    } catch (ex, trace) {
      Logger.error("Error downloading attachment: ${ex.toString()}", error: ex, trace: trace);
      showSnackbar("Save Error", ex.toString());
    }
  }

  void openLink() {
    String? url = part.url;
    mcs.invokeMethod("open-browser", {"link": url ?? part.text});
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
        content: SelectableText(part.fullText, style: context.theme.extension<BubbleText>()!.bubbleText),
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
                '${progress.value != null && attachmentObs.value != null ? (progress.value! * attachmentObs.value!.totalBytes! / 1000).getFriendlySize(withSuffix: false) : ""} / ${(attachmentObs.value!.totalBytes!.toDouble() / 1000).getFriendlySize()} (${((progress.value ?? 0) * 100).floor()}%)',
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
                    child: Text("Close",
                        style:
                            context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                    onPressed: () async {
                      Get.closeAllSnackbars();
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
            original: true,
            onReceiveProgress: (count, total) =>
                progress.value = kIsWeb ? (count / total) : (count / element.totalBytes!));
        final file = PlatformFile(
          name: element.transferName!,
          size: response.data.length,
          bytes: response.data,
        );
        await as.saveToDisk(file, isDocument: element.mimeStart != "image" && element.mimeStart != "video");
      }
      progress.value = 1;
      downloadingAttachments.value = false;
    } catch (ex, trace) {
      Logger.error("Failed to download original attachment!", error: ex, trace: trace);
      showSnackbar("Download Error", ex.toString());
    }
  }

  Future<void> downloadLivePhoto() async {
    final RxBool downloadingAttachments = true.obs;
    final RxnInt progress = RxnInt();
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
                progress.value?.toDouble().getFriendlySize() ?? "",
                style: context.theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 10.0),
          Obx(() => ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                backgroundColor: context.theme.colorScheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(Get.context!.theme.colorScheme.primary),
                value: downloadingAttachments.value ? null : 1,
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(
            height: 15.0,
          ),
          Obx(() => Text(
                !downloadingAttachments.value
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
                    child: Text("Close",
                        style:
                            context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                    onPressed: () async {
                      Get.closeAllSnackbars();
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
            onReceiveProgress: (count, total) => progress.value = count);
        final nameSplit = element.transferName!.split(".");
        final file = PlatformFile(
          name: "${nameSplit.take(nameSplit.length - 1).join(".")}.mov",
          size: response.data.length,
          bytes: response.data,
        );
        await as.saveToDisk(file, isDocument: true);
      }
      downloadingAttachments.value = false;
    } catch (ex, trace) {
      Logger.error("Failed to download live photo!", error: ex, trace: trace);
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
            chatGuid: dmChat!.guid,
          );
        },
      ),
    );
  }

  void createContact() async {
    popDetails();
    await mcs.invokeMethod("open-contact-form",
        {'address': message.handle!.address, 'address_type': message.handle!.address.isEmail ? 'email' : 'phone'});
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
    if (attachments.isNotEmpty || !isNullOrEmpty(message.text)) {
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
    if (Platform.isAndroid) {
      bool denied = await Permission.scheduleExactAlarm.isDenied;;
      bool permanentlyDenied = await Permission.scheduleExactAlarm.isPermanentlyDenied;
      if (denied && !permanentlyDenied) {
        await Permission.scheduleExactAlarm.request();
      } else if (permanentlyDenied) {
        showSnackbar("Error", "You must enable the manage alarm permission to use this feature");
        return;
      }
    }

    final finalDate = await showTimeframePicker("Select Reminder Time", context,
        presetsAhead: true, additionalTimeframes: {"3 Hours": 3, "6 Hours": 6}, useTodayYesterday: true);
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

  void unsend() async {
    popDetails();
    final response = await http.unsend(message.guid!, partIndex: part.part);
    if (response.statusCode == 200) {
      final updatedMessage = Message.fromMap(response.data['data']);
      ah.handleUpdatedMessage(chat, updatedMessage, null);
    }
  }

  void edit() {
    popDetails();
    final FocusNode? node = kIsDesktop || kIsWeb ? FocusNode() : null;
    cvController.editing.add(Tuple3(message, part, SpellCheckTextEditingController(text: part.text!, focusNode: node)));
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
    Map map = message.toMap(includeObjects: true);
    if (map["dateCreated"] is int) {
      map["dateCreated"] =
          DateFormat("MMMM d, yyyy h:mm:ss a").format(DateTime.fromMillisecondsSinceEpoch(map["dateCreated"]));
    }
    if (map["dateDelivered"] is int) {
      map["dateDelivered"] =
          DateFormat("MMMM d, yyyy h:mm:ss a").format(DateTime.fromMillisecondsSinceEpoch(map["dateDelivered"]));
    }
    if (map["dateRead"] is int) {
      map["dateRead"] =
          DateFormat("MMMM d, yyyy h:mm:ss a").format(DateTime.fromMillisecondsSinceEpoch(map["dateRead"]));
    }
    if (map["dateEdited"] is int) {
      map["dateEdited"] =
          DateFormat("MMMM d, yyyy h:mm:ss a").format(DateTime.fromMillisecondsSinceEpoch(map["dateEdited"]));
    }
    String str = encoder.convert(map);
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
            decoration: BoxDecoration(
                color: context.theme.colorScheme.background, borderRadius: const BorderRadius.all(Radius.circular(10))),
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
            child: Text("Close",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget buildDetailsMenu(BuildContext context) {
    double maxMenuWidth = min(max(ns.width(widthContext) * 3 / 5, 200), ns.width(widthContext) * 4 / 5);

    List<DetailsMenuActionWidget> allActions = [
      if (ss.settings.enablePrivateAPI.value && minBigSur && chat.isIMessage && isSent)
        DetailsMenuActionWidget(
          onTap: reply,
          action: DetailsMenuAction.Reply,
        ),
      if (showDownload)
        DetailsMenuActionWidget(
          onTap: download,
          action: DetailsMenuAction.Save,
        ),
      if ((part.text?.hasUrl ?? false) && !kIsWeb && !kIsDesktop && !ls.isBubble)
        DetailsMenuActionWidget(
          onTap: openLink,
          action: DetailsMenuAction.OpenInBrowser,
        ),
      if (showDownload && kIsWeb && part.attachments.firstOrNull?.webUrl != null)
        DetailsMenuActionWidget(
          onTap: openAttachmentWeb,
          action: DetailsMenuAction.OpenInNewTab,
        ),
      if (!isNullOrEmptyString(part.fullText))
        DetailsMenuActionWidget(
          onTap: copyText,
          action: DetailsMenuAction.CopyText,
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
        DetailsMenuActionWidget(
          onTap: downloadOriginal,
          action: DetailsMenuAction.SaveOriginal,
        ),
      if (showDownload && part.attachments.where((e) => e.hasLivePhoto).isNotEmpty)
        DetailsMenuActionWidget(
          onTap: downloadLivePhoto,
          action: DetailsMenuAction.SaveLivePhoto,
        ),
      if (chat.isGroup && !message.isFromMe! && dmChat != null && !ls.isBubble)
        DetailsMenuActionWidget(
          onTap: openDm,
          action: DetailsMenuAction.OpenDirectMessage,
        ),
      if (message.threadOriginatorGuid != null ||
          service.struct.threads(message.guid!, part.part, returnOriginator: false).isNotEmpty)
        DetailsMenuActionWidget(
          onTap: showThread,
          action: DetailsMenuAction.ViewThread,
        ),
      if ((part.attachments.isNotEmpty && !kIsWeb && !kIsDesktop) ||
          (!kIsWeb && !kIsDesktop && !isNullOrEmpty(part.text)))
        DetailsMenuActionWidget(
          onTap: share,
          action: DetailsMenuAction.Share,
        ),
      if (showDownload)
        DetailsMenuActionWidget(
          onTap: redownload,
          action: DetailsMenuAction.ReDownloadFromServer,
        ),
      if (!kIsWeb && !kIsDesktop)
        DetailsMenuActionWidget(
          onTap: remindLater,
          action: DetailsMenuAction.RemindLater,
        ),
      if (!kIsWeb && !kIsDesktop && !message.isFromMe! && message.handle != null && message.handle!.contact == null)
        DetailsMenuActionWidget(
          onTap: createContact,
          action: DetailsMenuAction.CreateContact,
        ),
      if (ss.isMinVenturaSync &&
          message.isFromMe! &&
          !message.guid!.startsWith("temp") &&
          ss.serverDetailsSync().item4 >= 148)
        DetailsMenuActionWidget(
          onTap: unsend,
          action: DetailsMenuAction.UndoSend,
        ),
      if (ss.isMinVenturaSync &&
          message.isFromMe! &&
          !message.guid!.startsWith("temp") &&
          ss.serverDetailsSync().item4 >= 148 &&
          (part.text?.isNotEmpty ?? false))
        DetailsMenuActionWidget(
          onTap: edit,
          action: DetailsMenuAction.Edit,
        ),
      if (!ls.isBubble && !message.isInteractive)
        DetailsMenuActionWidget(
          onTap: forward,
          action: DetailsMenuAction.Forward,
        ),
      if (chat.isGroup && !message.isFromMe! && dmChat == null && !ls.isBubble)
        DetailsMenuActionWidget(
          onTap: newConvo,
          action: DetailsMenuAction.StartConversation,
        ),
      if (!isNullOrEmptyString(part.fullText) && (kIsDesktop || kIsWeb))
        DetailsMenuActionWidget(
          onTap: copySelection,
          action: DetailsMenuAction.CopySelection,
        ),
      DetailsMenuActionWidget(
        onTap: delete,
        action: DetailsMenuAction.Delete,
      ),
      DetailsMenuActionWidget(
        onTap: toggleBookmark,
        action: DetailsMenuAction.Bookmark,
        customTitle: message.isBookmarked ? "Remove Bookmark" : "Add Bookmark",
      ),
      DetailsMenuActionWidget(
        onTap: selectMultiple,
        action: DetailsMenuAction.SelectMultiple,
      ),
      DetailsMenuActionWidget(
        onTap: messageInfo,
        action: DetailsMenuAction.MessageInfo,
      ),
    ];

    allActions.sort((a, b) => ss.settings.detailsMenuActions.indexOf(a.action).compareTo(ss.settings.detailsMenuActions.indexOf(b.action)));

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
            children: allActions.cast<CustomDetailsMenuActionWidget>().sublist(0, numberToShow - 1)
              ..add(
                CustomDetailsMenuActionWidget(
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
                  title: 'More...',
                  iosIcon: cupertino.CupertinoIcons.ellipsis,
                  nonIosIcon: Icons.more_vert,
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
    super.key,
    required this.reactions,
  });

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
            child: ListView.separated(
              shrinkWrap: true,
              physics: ThemeSwitcher.getScrollPhysics(),
              scrollDirection: Axis.horizontal,
              findChildIndexCallback: (key) => findChildIndexByKey(reactions, key, (item) => item.guid),
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final message = reactions[index];
                return Column(
                  key: ValueKey(message.guid!),
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
                    if (!ss.settings.hideNamesForReactions.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          message.isFromMe! ? ss.settings.userName.value : (message.handle?.displayName ?? "Unknown"),
                          style: context.theme.textTheme.bodySmall!
                              .copyWith(color: context.theme.colorScheme.properOnSurface),
                        ),
                      ),
                    if (ss.settings.hideNamesForReactions.value)
                      const SizedBox(
                        height: 8,
                      ),
                    Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: message.isFromMe!
                            ? context.theme.colorScheme.primary
                            : context.theme.colorScheme.properSurface,
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
                                colorFilter: ColorFilter.mode(
                                    message.associatedMessageType == "love"
                                        ? Colors.pink
                                        : message.isFromMe!
                                            ? context.theme.colorScheme.onPrimary
                                            : context.theme.colorScheme.properOnSurface,
                                    BlendMode.srcIn),
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
