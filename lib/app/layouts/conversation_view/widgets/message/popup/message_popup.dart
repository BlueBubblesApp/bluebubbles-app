import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/actions/media_actions.dart'
    as popup_media_actions;
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/actions/message_actions.dart'
    as popup_message_actions;
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/actions/navigation_actions.dart'
    as popup_navigation_actions;
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/actions/text_actions.dart'
    as popup_text_actions;
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/details_menu_action.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_action_context.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/reaction_picker_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/widgets/reaction_details.dart';
import 'package:bluebubbles/app/layouts/findmy/findmy_pin_clipper.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:sprung/sprung.dart';
import 'package:universal_io/io.dart';

export 'package:bluebubbles/app/layouts/conversation_view/widgets/message/popup/message_popup_action_context.dart'
    show MessagePopupServerDetails;

class MessagePopup extends StatefulWidget {
  final Offset childPosition;
  final Size size;
  final Widget child;
  final MessagePart part;
  final MessageState controller;
  final ConversationViewController cvController;
  final MessagePopupServerDetails serverDetails;
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

class _MessagePopupState extends State<MessagePopup> with SingleTickerProviderStateMixin, ThemeHelpers {
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
  late Chat? dmChat = ChatsSvc.allChats.firstWhereOrNull((chat) =>
      !chat.isGroup &&
      chat.handles.firstWhereOrNull((handle) => handle.address == message.handleRelation.target?.address) != null);
  String? selfReaction;
  String? currentlySelectedReaction = "init";
  final GlobalKey _childKey = GlobalKey();
  double? _measuredChildHeight;

  ConversationViewController get cvController => widget.cvController;

  MessagesService get service => MessagesSvc(chat.guid);

  Chat get chat => widget.cvController.chat;

  MessagePart get part => widget.part;

  Message get message => widget.controller.message;

  bool get isSent {
    final isSending = widget.controller.isSending.value;
    final hasError = widget.controller.hasError.value;
    return !isSending && !hasError;
  }

  bool get showDownload =>
      (isSent &&
          part.attachments.isNotEmpty &&
          part.attachments.where((element) => AttachmentsSvc.getContent(element) is PlatformFile).isNotEmpty) ||
      isEmbeddedMedia;

  bool get canOpenInImageViewer =>
      kIsDesktop && !kIsWeb && part.attachments.length == 1 && part.attachments.first.mimeStart == "image";

  late bool isEmbeddedMedia = (message.balloonBundleId == "com.apple.Handwriting.HandwritingProvider" ||
          message.balloonBundleId == "com.apple.DigitalTouchBalloonProvider") &&
      File(message.interactiveMediaPath!).existsSync();

  bool get minSierra => widget.serverDetails.minSierra;

  bool get minBigSur => widget.serverDetails.minBigSur;

  bool get supportsOriginalDownload => widget.serverDetails.supportsOriginalDownload;

  BuildContext get widthContext => widget.widthContext.call() ?? context;

  @override
  void initState() {
    super.initState();
    controller.forward();
    if (iOS) {
      final remainingHeight = max(Get.height - Get.statusBarHeight - 135 - widget.size.height, itemHeight);
      numberToShow = min(remainingHeight ~/ itemHeight, 5);
    } else {
      // Potentially make this dynamic in the future
      numberToShow = 5;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final measuredHeight = _childKey.currentContext?.size?.height;
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
      setState(() {
        if (iOS) {
          if (measuredHeight != null) {
            _measuredChildHeight = measuredHeight;
            final remainingHeight = max(Get.height - Get.statusBarHeight - 135 - measuredHeight, itemHeight);
            numberToShow = min(remainingHeight ~/ itemHeight, 5);
          }
          messageOffset = itemHeight * numberToShow + 40;
        }
      });
    });
  }

  void _remeasureChild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = _childKey.currentContext?.size?.height;
      if (h != null && h != _measuredChildHeight) {
        setState(() => _measuredChildHeight = h);
      }
    });
  }

  void popDetails({bool returnVal = true}) {
    Navigator.popUntil(context, (route) => route is! DialogRoute);
    Navigator.of(context).pop(returnVal);
  }

  @override
  Widget build(BuildContext context) {
    double narrowWidth = message.isFromMe! || !SettingsSvc.settings.alwaysShowAvatars.value ? 330 : 360;
    bool narrowScreen = NavigationSvc.width(widthContext) < narrowWidth;

    return Theme(
      data: context.theme.copyWith(
        // in case some components still use legacy theming
        primaryColor: context.theme.colorScheme.bubble(context, chat.isIMessage),
        colorScheme: context.theme.colorScheme.copyWith(
          primary: context.theme.colorScheme.bubble(context, chat.isIMessage),
          onPrimary: context.theme.colorScheme.onBubble(context, chat.isIMessage),
          surface: ThemeSvc.isMaterialYouActive(context)
              ? null
              : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
          onSurface: ThemeSvc.isMaterialYouActive(context)
              ? null
              : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
        ),
      ),
      child: TitleBarWrapper(
          child: BBScaffold(
              extendBodyBehindAppBar: true,
              safeAreaLeft: false,
              safeAreaRight: false,
              // The popup opens over a still-collapsing keyboard. Keep the body
              // full-screen and its bottom edge fixed so Positioned offsets are
              // screen-anchored and don't ride the inset animation down.
              resizeToAvoidBottomInset: false,
              safeAreaMaintainBottomViewPadding: true,
              backgroundColor: kIsDesktop && iOS && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
                  ? context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                  : Colors.transparent,
              appBar: iOS
                  ? null
                  : BBAppBar(
                      backgroundColor: context.theme.colorScheme.surface.oppositeLightenOrDarken(5),
                      automaticallyImplyLeading: false,
                      leadingWidth: 40,
                      toolbarHeight: kIsDesktop ? 80 : 50,
                      leading: Padding(
                        padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0, left: 10.0),
                        child: BackButton(
                          color: context.theme.colorScheme.onSurface,
                          onPressed: () {
                            popDetails();
                            return true;
                          },
                        ),
                      ),
                      actions: buildMaterialDetailsMenu(context),
                    ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: popDetails,
                    child: iOS
                        ? (SettingsSvc.settings.highPerfMode.value
                            ? Container(color: context.theme.colorScheme.surface.withValues(alpha: 0.5))
                            : BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX:
                                        kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
                                            ? 10
                                            : 30,
                                    sigmaY:
                                        kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled
                                            ? 10
                                            : 30),
                                child: Container(
                                  color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
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
                        child: NotificationListener<SizeChangedLayoutNotification>(
                          onNotification: (_) {
                            _remeasureChild();
                            return false;
                          },
                          child: SizeChangedLayoutNotifier(
                            child: ConstrainedBox(
                              key: _childKey,
                              constraints: BoxConstraints(maxWidth: widget.size.width),
                              child: MessageStateScope(
                                messageState: widget.controller,
                                child: widget.child,
                              ),
                            ),
                          ),
                        ),
                        builder: (context, size, child) {
                          return Transform.scale(
                            scale: size.clamp(1, double.infinity),
                            alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
                            child: child,
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
                  if (SettingsSvc.settings.enablePrivateAPI.value && isSent && minSierra && chat.isIMessage)
                    Positioned(
                      bottom: (iOS
                              ? itemHeight * numberToShow + 35 + (_measuredChildHeight ?? widget.size.height)
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
                                        color: context.theme.colorScheme.surfaceContainerHighest
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
                                    color: context.theme.colorScheme.surfaceContainerHighest
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
                                                                        fontSize: 18, fontFamily: 'Apple Color Emoji'),
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
                  if (!iOS && SettingsSvc.settings.enablePrivateAPI.value && minBigSur && chat.isIMessage && isSent)
                    Positioned(
                      left: !message.isFromMe!
                          ? widget.childPosition.dx + widget.size.width + (reactions.isNotEmpty ? 20 : 5)
                          : widget.childPosition.dx - 55,
                      top: materialOffset,
                      child: Material(
                        color: context.theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width: 35,
                          height: 35,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => popup_navigation_actions.reply(_buildActionContext(DetailsMenuAction.Reply)),
                            child: const Center(child: Icon(Icons.reply, size: 20)),
                          ),
                        ),
                      ),
                    ),
                ],
              ))),
    );
  }

  MessagePopupActionContext _buildActionContext(DetailsMenuAction action) {
    return MessagePopupActionContext(
      context: context,
      widthContext: widthContext,
      cvController: cvController,
      messageState: widget.controller,
      message: message,
      part: part,
      chat: chat,
      service: service,
      serverDetails: widget.serverDetails,
      action: action,
      popDetails: ({bool returnVal = true}) => popDetails(returnVal: returnVal),
      showSnack: showSnackbar,
      dmChat: dmChat,
      isEmbeddedMedia: isEmbeddedMedia,
    );
  }

  List<DetailsMenuActionWidget> get _allActions {
    final canEdit = (message.dateCreated?.toUtc().isWithin(DateTime.now().toUtc(), minutes: 15) ?? false);
    final canUnsend = (message.dateCreated?.toUtc().isWithin(DateTime.now().toUtc(), minutes: 2) ?? false);
    return [
      if (SettingsSvc.settings.enablePrivateAPI.value && minBigSur && chat.isIMessage && isSent)
        DetailsMenuActionWidget(
          onTap: () => popup_navigation_actions.reply(_buildActionContext(DetailsMenuAction.Reply)),
          action: DetailsMenuAction.Reply,
        ),
      if (showDownload)
        DetailsMenuActionWidget(
          onTap: () => popup_media_actions.downloadAttachment(_buildActionContext(DetailsMenuAction.Save)),
          action: DetailsMenuAction.Save,
        ),
      if (canOpenInImageViewer)
        DetailsMenuActionWidget(
          onTap: () => popup_media_actions.openInImageViewer(_buildActionContext(DetailsMenuAction.OpenInImageViewer)),
          action: DetailsMenuAction.OpenInImageViewer,
        ),
      if ((part.text?.hasUrl ?? false) && !kIsWeb && !kIsDesktop && !LifecycleSvc.isBubble)
        DetailsMenuActionWidget(
          onTap: () => popup_text_actions.openLink(_buildActionContext(DetailsMenuAction.OpenInBrowser)),
          action: DetailsMenuAction.OpenInBrowser,
        ),
      if (showDownload && kIsWeb && part.attachments.firstOrNull?.webUrl != null)
        DetailsMenuActionWidget(
          onTap: () => popup_media_actions.openAttachmentWeb(_buildActionContext(DetailsMenuAction.OpenInNewTab)),
          action: DetailsMenuAction.OpenInNewTab,
        ),
      if (!isNullOrEmptyString(part.fullText))
        DetailsMenuActionWidget(
          onTap: () => popup_text_actions.copyText(_buildActionContext(DetailsMenuAction.CopyText)),
          action: DetailsMenuAction.CopyText,
        ),
      if (showDownload && kIsDesktop)
        DetailsMenuActionWidget(
          onTap: () => popup_media_actions.copyAttachment(_buildActionContext(DetailsMenuAction.CopyAttachment)),
          action: DetailsMenuAction.CopyAttachment,
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
          onTap: () =>
              popup_media_actions.downloadOriginalAttachments(_buildActionContext(DetailsMenuAction.SaveOriginal)),
          action: DetailsMenuAction.SaveOriginal,
        ),
      if (showDownload && part.attachments.where((e) => e.hasLivePhoto).isNotEmpty)
        DetailsMenuActionWidget(
          onTap: () => popup_media_actions.downloadLivePhoto(_buildActionContext(DetailsMenuAction.SaveLivePhoto)),
          action: DetailsMenuAction.SaveLivePhoto,
        ),
      if (chat.isGroup && !message.isFromMe! && dmChat != null && !LifecycleSvc.isBubble)
        DetailsMenuActionWidget(
          onTap: () => popup_navigation_actions.openDm(_buildActionContext(DetailsMenuAction.OpenDirectMessage)),
          action: DetailsMenuAction.OpenDirectMessage,
        ),
      if (message.threadOriginatorGuid != null ||
          service.struct.threads(message.guid!, part.part, returnOriginator: false).isNotEmpty)
        DetailsMenuActionWidget(
          onTap: () => popup_navigation_actions.showThread(_buildActionContext(DetailsMenuAction.ViewThread)),
          action: DetailsMenuAction.ViewThread,
        ),
      if ((part.attachments.isNotEmpty && !kIsWeb && !(kIsDesktop && Platform.isLinux)) ||
          (!kIsWeb && !(kIsDesktop && Platform.isLinux) && !isNullOrEmpty(part.text)))
        DetailsMenuActionWidget(
          onTap: () => popup_media_actions.sharePart(_buildActionContext(DetailsMenuAction.Share)),
          action: DetailsMenuAction.Share,
        ),
      if (showDownload)
        DetailsMenuActionWidget(
          onTap: () => popup_media_actions.redownload(_buildActionContext(DetailsMenuAction.ReDownloadFromServer)),
          action: DetailsMenuAction.ReDownloadFromServer,
        ),
      if (!kIsWeb && !kIsDesktop)
        DetailsMenuActionWidget(
          onTap: () => popup_message_actions.remindLater(_buildActionContext(DetailsMenuAction.RemindLater)),
          action: DetailsMenuAction.RemindLater,
        ),
      if (!kIsWeb &&
          !kIsDesktop &&
          !message.isFromMe! &&
          message.handleRelation.target != null &&
          message.handleRelation.target!.contactsV2.isEmpty)
        DetailsMenuActionWidget(
          onTap: () => popup_message_actions.createContact(_buildActionContext(DetailsMenuAction.CreateContact)),
          action: DetailsMenuAction.CreateContact,
        ),
      if (SettingsSvc.serverDetails.isMinVentura &&
          message.isFromMe! &&
          !widget.controller.isSending.value &&
          SettingsSvc.serverDetails.supportsEditAndUnsend)
        DetailsMenuActionWidget(
          onTap: () => popup_message_actions.unsend(_buildActionContext(DetailsMenuAction.UndoSend)),
          customTitle: canUnsend ? 'Undo Send' : 'Undo Send (too old)',
          shouldDisableBtn: !canUnsend,
          action: DetailsMenuAction.UndoSend,
        ),
      if (message.isFromMe! && widget.controller.isSending.value && OutgoingMsgHandler.hasPendingMessage(message.guid!))
        DetailsMenuActionWidget(
          onTap: () => popup_message_actions.cancelSend(_buildActionContext(DetailsMenuAction.CancelSend)),
          action: DetailsMenuAction.CancelSend,
        ),
      if (SettingsSvc.serverDetails.isMinVentura &&
          message.isFromMe! &&
          !widget.controller.isSending.value &&
          SettingsSvc.serverDetails.supportsEditAndUnsend &&
          (part.text?.isNotEmpty ?? false))
        DetailsMenuActionWidget(
          onTap: () => popup_message_actions.edit(_buildActionContext(DetailsMenuAction.Edit)),
          customTitle: canEdit ? 'Edit' : 'Edit (too old)',
          shouldDisableBtn: !canEdit,
          action: DetailsMenuAction.Edit,
        ),
      if (!LifecycleSvc.isBubble && !message.isInteractive)
        DetailsMenuActionWidget(
          onTap: () => popup_navigation_actions.forward(_buildActionContext(DetailsMenuAction.Forward)),
          action: DetailsMenuAction.Forward,
        ),
      if (chat.isGroup && !message.isFromMe! && dmChat == null && !LifecycleSvc.isBubble)
        DetailsMenuActionWidget(
          onTap: () => popup_navigation_actions.newConvo(_buildActionContext(DetailsMenuAction.StartConversation)),
          action: DetailsMenuAction.StartConversation,
        ),
      if (!isNullOrEmptyString(part.fullText) && (kIsDesktop || kIsWeb))
        DetailsMenuActionWidget(
          onTap: () => popup_text_actions.copySelection(_buildActionContext(DetailsMenuAction.CopySelection)),
          action: DetailsMenuAction.CopySelection,
        ),
      DetailsMenuActionWidget(
        onTap: () => popup_message_actions.delete(_buildActionContext(DetailsMenuAction.Delete)),
        action: DetailsMenuAction.Delete,
      ),
      DetailsMenuActionWidget(
        onTap: () => popup_message_actions.toggleBookmark(_buildActionContext(DetailsMenuAction.Bookmark)),
        action: DetailsMenuAction.Bookmark,
        customTitle: message.isBookmarked ? "Remove Bookmark" : "Add Bookmark",
      ),
      DetailsMenuActionWidget(
        onTap: () => popup_message_actions.selectMultiple(_buildActionContext(DetailsMenuAction.SelectMultiple)),
        action: DetailsMenuAction.SelectMultiple,
      ),
      DetailsMenuActionWidget(
        onTap: () => popup_message_actions.messageInfo(_buildActionContext(DetailsMenuAction.MessageInfo)),
        action: DetailsMenuAction.MessageInfo,
      ),
    ].sorted((a, b) => SettingsSvc.settings.detailsMenuActions
        .indexOf(a.action)
        .compareTo(SettingsSvc.settings.detailsMenuActions.indexOf(b.action)));
  }

  Widget buildDetailsMenu(BuildContext context) {
    double maxMenuWidth =
        min(max(NavigationSvc.width(widthContext) * 3 / 5, 200), NavigationSvc.width(widthContext) * 4 / 5);

    List<DetailsMenuActionWidget> allActions = _allActions;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: context.theme.colorScheme.surfaceContainerHighest.withAlpha(150),
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
                    showBBDialog(
                      useRootNavigator: false,
                      context: context,
                      content: content,
                    );
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

  List<Widget> buildMaterialDetailsMenu(BuildContext context) {
    List<DetailsMenuActionWidget> allActions = _allActions;

    return [
      ...allActions.slice(0, numberToShow - 1).map((action) {
        bool isDisabled = false;
        if (action.action == DetailsMenuAction.Edit) {
          isDisabled = !((message.dateCreated?.toUtc().isWithin(DateTime.now().toUtc(), minutes: 15) ?? false));
        }

        Color color = isDisabled
            ? context.theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
            : context.theme.colorScheme.onSurfaceVariant;
        return Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: IconButton(
              icon: Icon(action.nonIosIcon, color: color),
              onPressed: isDisabled ? null : action.onTap,
              tooltip: action.title,
            ));
      }),
      Padding(
          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
          child: PopupMenuButton<int>(
              color: context.theme.colorScheme.surfaceContainerHighest,
              shape: SettingsSvc.settings.skin.value != Skins.Material
                  ? const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20.0)),
                    )
                  : null,
              onSelected: (int value) {
                allActions[value + numberToShow - 1].onTap?.call();
              },
              itemBuilder: (context) {
                return allActions.slice(numberToShow - 1).mapIndexed((index, action) {
                  return PopupMenuItem(
                    value: index,
                    child: Text(
                      action.title,
                      style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onSurfaceVariant),
                    ),
                  );
                }).toList();
              }))
    ];
  }
}
