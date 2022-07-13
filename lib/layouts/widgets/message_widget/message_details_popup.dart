import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/api_manager.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/custom_cupertino_alert_dialog.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reaction_detail_widget.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/show_reply_thread.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat/chat_controller.dart';
import 'package:bluebubbles/managers/chat/chat_manager.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/message/message_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sprung/sprung.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MessageDetailsPopup extends StatefulWidget {
  MessageDetailsPopup({
    Key? key,
    required this.message,
    required this.newerMessage,
    required this.childOffsetY,
    required this.childSize,
    required this.child,
    required this.currentChat,
    required this.messageBloc,
  }) : super(key: key);

  final Message message;
  final Message? newerMessage;
  final double childOffsetY;
  final Size? childSize;
  final Widget child;
  final ChatController? currentChat;
  final MessageBloc? messageBloc;

  @override
  MessageDetailsPopupState createState() => MessageDetailsPopupState();
}

class MessageDetailsPopupState extends State<MessageDetailsPopup> {
  List<Widget> reactionWidgets = <Widget>[];
  bool showTools = false;
  String? selfReaction;
  String? currentlySelectedReaction;
  ChatController? currentChat;
  Chat? dmChat;

  late double messageTopOffset;
  late double topMinimum;
  double? detailsMenuHeight;
  bool isSierra = true;
  bool isBigSur = true;
  bool supportsOriginalDownload = false;

  @override
  void initState() {
    super.initState();
    currentChat = widget.currentChat;

    topMinimum = (widget.message.hasReactions ? 250 : 110);
    messageTopOffset = max(topMinimum, min(widget.childOffsetY, Get.height - widget.childSize!.height - 200));

    dmChat = ChatBloc().chats.firstWhereOrNull(
          (chat) =>
              !chat.isGroup() && chat.participants.where((handle) => handle.id == widget.message.handleId).length == 1,
        );

    fetchReactions();

    SettingsManager().getServerVersionCode().then((version) async {
      if (mounted) {
        final minSierra = await SettingsManager().isMinSierra;
        final minBigSur = await SettingsManager().isMinBigSur;
        setState(() {
          isSierra = minSierra;
          isBigSur = minBigSur;
          showTools = true;
          supportsOriginalDownload = version > 100;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchReactions();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          messageTopOffset = max(topMinimum, min(widget.childOffsetY, context.height - widget.childSize!.height - 200));
        });
      }
    });
  }

  void fetchReactions() {
    // If there are no associated messages, return now
    List<Message> reactions = widget.message.getReactions();

    // Filter down the messages to the unique ones (one per user, newest)
    List<Message> reactionMessages = Reaction.getUniqueReactionMessages(reactions);

    reactionWidgets = [];
    for (Message reaction in reactionMessages) {
      reaction.handle ??= reaction.getHandle();
      if (reaction.isFromMe!) {
        selfReaction = reaction.associatedMessageType;
        currentlySelectedReaction = selfReaction;
      }
      reactionWidgets.add(
        ReactionDetailWidget(
          handle: reaction.handle,
          message: reaction,
        ),
      );
    }
  }

  void sendReaction(String type) {
    Logger.info("Sending reaction type: $type");
    ActionHandler.sendReaction(widget.message.getChat() ?? widget.currentChat!.chat, widget.message, type);
    Navigator.of(context).pop();
  }

  void popDetails() {
    bool dialogOpen = Get.isDialogOpen ?? false;
    if (dialogOpen) {
      if (kIsWeb) {
        Get.back();
      } else {
        Get.close(1);
      }
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    bool isSent = !widget.message.guid!.startsWith('temp') && !widget.message.guid!.startsWith('error');
    bool hideReactions =
        (SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideReactions.value) || !isSierra;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: TitleBarWrapper(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    popDetails();
                  },
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: oledDarkTheme.colorScheme.properSurface.withOpacity(0.3),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  top: messageTopOffset,
                  left: widget.message.isFromMe! ? null : 10,
                  right: widget.message.isFromMe! ? 10 : null,
                  child: Container(
                    width: widget.childSize!.width,
                    height: widget.childSize!.height + 5,
                    child: widget.child,
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 10,
                  right: 10,
                  child: AnimatedSize(
                    duration: Duration(milliseconds: 500),
                    curve: Sprung.underDamped,
                    alignment: Alignment.center,
                    child: reactionWidgets.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                alignment: Alignment.center,
                                height: 120,
                                color: context.theme.colorScheme.properSurface,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 0),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    physics: ThemeSwitcher.getScrollPhysics(),
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (context, index) {
                                      if (index >= 0 && index < reactionWidgets.length) {
                                        return reactionWidgets[index];
                                      } else {
                                        return Container();
                                      }
                                    },
                                    itemCount: reactionWidgets.length,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Container(),
                  ),
                ),
                // Only show the reaction menu if it's enabled and the message isn't temporary
                if (SettingsManager().settings.enablePrivateAPI.value &&
                    isSent &&
                    !hideReactions &&
                    (currentChat?.chat.isIMessage ?? true))
                  buildReactionMenu(),
                buildDetailsMenu(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildReactionMenu() {
    double narrowWidth = widget.message.isFromMe! || !SettingsManager().settings.alwaysShowAvatars.value ? 330 : 360;
    bool narrowScreen = CustomNavigator.width(context) < narrowWidth;
    double reactionIconSize = 50;
    double menuHeight = (reactionIconSize * 2).toDouble();
    if (topMinimum > context.height - 120 - menuHeight) {
      topMinimum = context.height - 120 - menuHeight;
    }
    bool shiftRight = !widget.message.isFromMe! && (currentChat!.chat.isGroup() || SettingsManager().settings.alwaysShowAvatars.value);

    double offset = 20 + (shiftRight ? 35 : 0);

    return Positioned(
      bottom: context.height - messageTopOffset + 10,
      left: widget.message.isFromMe! ? null : offset,
      right: widget.message.isFromMe! ? offset : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.properSurface.withAlpha(150),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: ReactionTypes.toList()
                      .slice(0, narrowScreen ? 3 : null)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7.5, horizontal: 7.5),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              sendReaction(selfReaction == e ? "-$e" : e);
                            },
                            onTapDown: (TapDownDetails details) {
                              if (currentlySelectedReaction == e) {
                                currentlySelectedReaction = null;
                              } else {
                                currentlySelectedReaction = e;
                              }
                              if (mounted) setState(() {});
                            },
                            onTapUp: (details) {},
                            onTapCancel: () {
                              currentlySelectedReaction = selfReaction;
                              if (mounted) setState(() {});
                            },
                            child: Container(
                              width: reactionIconSize - 15,
                              height: reactionIconSize - 15,
                              decoration: BoxDecoration(
                                color: currentlySelectedReaction == e
                                    ? context.theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Reaction.getReactionIcon(e, currentlySelectedReaction == e
                                    ? context.theme.colorScheme.onPrimary
                                    : context.theme.colorScheme.outline, usePink: currentlySelectedReaction == e),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (narrowScreen)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: ReactionTypes.toList()
                        .slice(3)
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7.5, horizontal: 7.5),
                            child: Container(
                              width: reactionIconSize - 15,
                              height: reactionIconSize - 15,
                              decoration: BoxDecoration(
                                color: currentlySelectedReaction == e
                                    ? context.theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  sendReaction(selfReaction == e ? "-$e" : e);
                                },
                                onTapDown: (TapDownDetails details) {
                                  if (currentlySelectedReaction == e) {
                                    currentlySelectedReaction = null;
                                  } else {
                                    currentlySelectedReaction = e;
                                  }
                                  if (mounted) setState(() {});
                                },
                                onTapUp: (details) {},
                                onTapCancel: () {
                                  currentlySelectedReaction = selfReaction;
                                  if (mounted) setState(() {});
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Reaction.getReactionIcon(e, currentlySelectedReaction == e
                                      ? context.theme.colorScheme.onPrimary
                                      : context.theme.colorScheme.outline, usePink: false),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get showDownload =>
      widget.message.hasAttachments &&
      widget.message.attachments.where((element) => element!.mimeStart != null).isNotEmpty &&
      widget.message.attachments.where((element) => AttachmentHelper.getContent(element!) is PlatformFile).isNotEmpty;

  bool get isSent => !widget.message.guid!.startsWith('temp') && !widget.message.guid!.startsWith('error');

  Widget buildDetailsMenu() {
    bool showAltLayout =
        SettingsManager().settings.tabletMode.value && (!context.isPhone || context.isLandscape) && context.width > 600 && !LifeCycleManager().isBubble;
    double maxMenuWidth = min(max(CustomNavigator.width(context) * 3 / 5, 200), CustomNavigator.width(context) * 4 / 5) * (showAltLayout ? 0.5 : 1);
    double maxHeight = context.height - messageTopOffset - widget.childSize!.height;

    List<Widget> allActions = [
      if (SettingsManager().settings.enablePrivateAPI.value &&
          isBigSur &&
          (currentChat?.chat.isIMessage ?? true) &&
          !widget.message.guid!.startsWith("temp"))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              popDetails();
              EventDispatcher().emit("focus-keyboard", widget.message);
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Reply",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.reply : Icons.reply,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              try {
                for (Attachment? element in widget.message.attachments) {
                  dynamic content = AttachmentHelper.getContent(element!);
                  if (content is PlatformFile) {
                    if (element.guid == widget.message.attachments.last?.guid) {
                      popDetails();
                    }
                    await AttachmentHelper.saveToGallery(content);
                  }
                }
              } catch (ex, trace) {
                Logger.error(trace.toString());
                showSnackbar("Download Error", ex.toString());
              }
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Download to Device",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.cloud_download
                    : Icons.file_download,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (widget.message.fullText.replaceAll("\n", " ").hasUrl &&
          !kIsWeb &&
          !kIsDesktop &&
          !LifeCycleManager().isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              String? url = widget.message.getUrl();
              MethodChannelInterface().invokeMethod("open-link", {"link": url ?? widget.message.text, "forceBrowser": true});
              popDetails();
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Open In Browser",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.macwindow
                    : Icons.open_in_browser,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload && kIsWeb && widget.message.attachments.first?.webUrl != null)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await launchUrlString(
                  "${widget.message.attachments.first!.webUrl!}?guid=${SettingsManager().settings.guidAuthKey}");
              popDetails();
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Open In New Tab",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.macwindow
                    : Icons.open_in_browser,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (!isEmptyString(widget.message.fullText))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.message.fullText));
              popDetails();
              showSnackbar("Copied", "Copied to clipboard!", durationMs: 1000);
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text("Copy", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.doc_on_clipboard
                    : Icons.content_copy,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload &&
          supportsOriginalDownload &&
          widget.message.attachments
              .where((element) =>
                  (element?.uti?.contains("heic") ?? false) ||
                  (element?.uti?.contains("heif") ?? false) ||
                  (element?.uti?.contains("quicktime") ?? false) ||
                  (element?.uti?.contains("coreaudio") ?? false) ||
                  (element?.uti?.contains("tiff") ?? false))
              .isNotEmpty)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final RxBool downloadingAttachments = true.obs;
              final RxnDouble progress = RxnDouble();
              final Rxn<Attachment> attachmentObs = Rxn<Attachment>();
              final toDownload = widget.message.attachments.where((element) =>
                  (element?.uti?.contains("heic") ?? false) ||
                  (element?.uti?.contains("heif") ?? false) ||
                  (element?.uti?.contains("quicktime") ?? false) ||
                  (element?.uti?.contains("coreaudio") ?? false) ||
                  (element?.uti?.contains("tiff") ?? false));
              final length = toDownload.length;
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: context.theme.colorScheme.properSurface,
                  title: Text("Downloading attachment${length > 1 ? "s" : ""}...", style: context.theme.textTheme.titleLarge),
                  content: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Obx(
                              () => Text(
                              '${progress.value != null && attachmentObs.value != null ? getSizeString(progress.value! * attachmentObs.value!.totalBytes! / 1000) : ""} / ${getSizeString(attachmentObs.value!.totalBytes!.toDouble() / 1000)} (${((progress.value ?? 0) * 100).floor()}%)',
                              style: context.theme.textTheme.bodyLarge),
                        ),
                        SizedBox(height: 10.0),
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
                        SizedBox(
                          height: 15.0,
                        ),
                        Obx(() => Text(
                          progress.value == 1 ? "Download Complete!" : "You can close this dialog. The attachments will continue to download in the background.",
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: context.theme.textTheme.bodyLarge,
                        )),
                      ]),
                  actions: [
                    Obx(() => downloadingAttachments.value
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
                  final response = await api.downloadAttachment(element!.guid!,
                      original: true,
                      onReceiveProgress: (count, total) =>
                          progress.value = kIsWeb ? (count / total) : (count / element.totalBytes!));
                  final file = PlatformFile(
                    name: element.transferName!,
                    path: kIsWeb ? null : element.getPath(),
                    size: response.data.length,
                    bytes: response.data,
                  );
                  bool lastAttachment = element.guid == toDownload.last?.guid;
                  await AttachmentHelper.saveToGallery(file, showAlert: lastAttachment);
                }
                progress.value = 1;
                downloadingAttachments.value = false;
              } catch (ex, trace) {
                Logger.error(trace.toString());
                showSnackbar("Download Error", ex.toString());
              }
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Download Original to Device",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.cloud_download
                    : Icons.file_download,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (widget.currentChat!.chat.isGroup() &&
          !widget.message.isFromMe! &&
          dmChat != null &&
          !LifeCycleManager().isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              popDetails();
              Navigator.pushReplacement(
                context,
                cupertino.CupertinoPageRoute(
                  builder: (BuildContext context) {
                    return ConversationView(
                      chat: dmChat,
                    );
                  },
                ),
              );
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Open Direct Message",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.arrow_up_right_square
                    : Icons.open_in_new,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if ((widget.message.threadOriginatorGuid != null ||
              widget.messageBloc?.threadOriginators.values.firstWhereOrNull((e) => e == widget.message.guid) != null) &&
          isBigSur)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              popDetails();
              showReplyThread(context, widget.message, widget.messageBloc);
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "View Thread",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.bubble_left_bubble_right
                    : Icons.forum,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (widget.currentChat!.chat.isGroup() &&
          !widget.message.isFromMe! &&
          dmChat == null &&
          !LifeCycleManager().isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () async {
              Handle? handle = widget.message.handle;
              String? address = handle?.address ?? "";
              Contact? contact = ContactManager().getContact(address);
              UniqueContact uniqueContact;
              if (contact == null) {
                uniqueContact = UniqueContact(address: address, displayName: (await formatPhoneNumber(handle)));
              } else {
                uniqueContact = UniqueContact(address: address, displayName: contact.displayName);
              }
              popDetails();
              Navigator.pushReplacement(
                context,
                cupertino.CupertinoPageRoute(
                  builder: (BuildContext context) {
                    EventDispatcher().emit("update-highlight", null);
                    return ConversationView(
                      isCreator: true,
                      selected: [uniqueContact],
                    );
                  },
                ),
              );
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Start Conversation",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.chat_bubble
                    : Icons.message,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (!LifeCycleManager().isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              popDetails();
              Navigator.pushReplacement(
                context,
                cupertino.CupertinoPageRoute(
                  builder: (BuildContext context) {
                    List<PlatformFile> existingAttachments = [];
                    if (!widget.message.isUrlPreview()) {
                      existingAttachments = widget.message.attachments
                          .map((attachment) => PlatformFile(
                                name: attachment!.transferName!,
                                path: kIsWeb ? null : attachment.getPath(),
                                bytes: attachment.bytes,
                                size: attachment.totalBytes!,
                              ))
                          .toList();
                    }
                    EventDispatcher().emit("update-highlight", null);
                    return ConversationView(
                      isCreator: true,
                      existingText: widget.message.text,
                      existingAttachments: existingAttachments,
                      previousChat: widget.currentChat?.chat,
                    );
                  },
                ),
              );
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Forward",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.arrow_right
                    : Icons.forward,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (showDownload && isSent)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              for (Attachment? element in widget.message.attachments) {
                ChatManager().activeChat?.clearImageData(element!);
                AttachmentHelper.redownloadAttachment(element!);
              }
              setState(() {});
              popDetails();
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Re-download from Server",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.refresh : Icons.refresh,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if ((widget.message.hasAttachments && !kIsWeb && !kIsDesktop) || (widget.message.text!.isNotEmpty && !kIsDesktop))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.message.hasAttachments && !widget.message.isUrlPreview() && !kIsWeb && !kIsDesktop) {
                for (Attachment? element in widget.message.attachments) {
                  Share.file(
                    "${element!.mimeType!.split("/")[0].capitalizeFirst} shared from BlueBubbles: ${element.transferName}",
                    element.getPath(),
                  );
                }
              } else if (widget.message.text!.isNotEmpty) {
                Share.text(
                  "Text shared from BlueBubbles",
                  widget.message.text!,
                );
              }
              popDetails();
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Share",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.share : Icons.share,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      if (!kIsWeb && !kIsDesktop)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              DateTime? finalDate;
              await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      "Select Reminder Time",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: Text("1 Hour", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                            onPressed: () {
                              finalDate = DateTime.now().toLocal().add(Duration(hours: 1));
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: Text("1 Day", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                            onPressed: () {
                              finalDate = DateTime.now().toLocal().add(Duration(days: 1));
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: Text("1 Week", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                            onPressed: () {
                              finalDate = DateTime.now().toLocal().add(Duration(days: 7));
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: Text("Custom", style: context.theme.textTheme.bodyLarge!.copyWith(color: Get.context!.theme.colorScheme.primary)),
                            onPressed: () async {
                              final messageDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().toLocal(),
                                  firstDate: DateTime.now().toLocal(),
                                  lastDate: DateTime.now().toLocal().add(Duration(days: 365)));
                              if (messageDate != null) {
                                final messageTime =
                                    await showTimePicker(context: context, initialTime: TimeOfDay.now());
                                if (messageTime != null) {
                                  finalDate = DateTime(messageDate.year, messageDate.month, messageDate.day,
                                      messageTime.hour, messageTime.minute);
                                }
                              }
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      )
                    ]),
                    backgroundColor: context.theme.colorScheme.properSurface,
                  );
                },
              );
              if (finalDate != null) {
                if (!finalDate!.isAfter(DateTime.now().toLocal())) {
                  showSnackbar("Error", "Select a date in the future");
                  return;
                }
                NotificationManager().scheduleNotification(widget.currentChat!.chat, widget.message, finalDate!);
                popDetails();
                showSnackbar("Notice", "Scheduled reminder for ${buildDate(finalDate)}");
              }
            },
            child: ListTile(
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                "Remind Later",
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.alarm : Icons.alarm,
                color: context.theme.colorScheme.properOnSurface,
              ),
            ),
          ),
        ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            MessageManager().removeMessage(widget.currentChat!.chat, widget.message.guid);
            Message.softDelete(widget.message.guid!);
            popDetails();
          },
          child: ListTile(
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              "Delete",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.trash : Icons.delete,
              color: context.theme.colorScheme.properOnSurface,
            ),
          ),
        ),
      ),
    ];

    List<Widget> detailsActions = [];
    List<Widget> moreActions = [];
    double itemHeight = kIsDesktop || kIsWeb ? 56 : 48;

    double actualHeight = itemHeight;
    int index = 0;

    int maxToShow = 0;
    if (!isEmptyString(widget.message.fullText)) maxToShow++;
    if (widget.message.fullText.replaceAll("\n", " ").hasUrl &&
        !kIsWeb &&
        !kIsDesktop &&
        !LifeCycleManager().isBubble) {
      maxToShow++;
    }
    if (showDownload && kIsWeb && widget.message.attachments.first?.webUrl != null) maxToShow++;
    if (showDownload) maxToShow++;
    if (SettingsManager().settings.enablePrivateAPI.value &&
        isBigSur &&
        (currentChat?.chat.isIMessage ?? true) &&
        !widget.message.guid!.startsWith("temp")) {
      maxToShow++;
    }

    while (actualHeight <= maxHeight - itemHeight && index < (maxToShow == 0 ? allActions.length : maxToShow)) {
      actualHeight += itemHeight;
      detailsActions.add(allActions[index++]);
    }
    detailsMenuHeight = (detailsActions.length + 1) * itemHeight;
    moreActions.addAll(allActions.getRange(index, allActions.length));

    // If there is only one 'more' action then it can replace the 'more' button
    if (moreActions.length == 1) {
      detailsActions.add(moreActions.removeAt(0));
    }

    Widget menu = ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: context.theme.colorScheme.properSurface.withAlpha(150),
          width: maxMenuWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...detailsActions,
              if (moreActions.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      Widget content = Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: moreActions,
                      );
                      Get.dialog(
                          SettingsManager().settings.skin.value == Skins.iOS
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
                      dense: !kIsDesktop && !kIsWeb,
                      title: Text("More...", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface)),
                      trailing: Icon(
                        SettingsManager().settings.skin.value == Skins.iOS
                            ? cupertino.CupertinoIcons.ellipsis
                            : Icons.more_vert,
                        color: context.theme.colorScheme.properOnSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    double upperLimit = context.height - detailsMenuHeight!;
    if (topMinimum > upperLimit) {
      topMinimum = upperLimit;
    }

    double topOffset = (messageTopOffset + widget.childSize!.height).toDouble().clamp(topMinimum, upperLimit);
    bool shiftRight = !widget.message.isFromMe! && (currentChat!.chat.isGroup() || SettingsManager().settings.alwaysShowAvatars.value);

    double offset = 20 + (shiftRight ? 35 : 0);
    return Positioned(
      top: topOffset > context.height - 100 ? null : topOffset + (widget.message.isFromMe! ? 5 : 10),
      bottom: topOffset > context.height - 100 ? 45 : null,
      left: widget.message.isFromMe! ? null : offset,
      right: widget.message.isFromMe! ? offset : null,
      child: menu,
    );
  }
}
