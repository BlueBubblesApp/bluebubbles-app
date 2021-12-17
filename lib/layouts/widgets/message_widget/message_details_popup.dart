import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/show_reply_thread.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'dart:ui';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/metadata_helper.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/notification_manager.dart';
import 'package:collection/collection.dart';

import 'package:bluebubbles/action_handler.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/reaction.dart';
import 'package:bluebubbles/helpers/share.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/widgets/custom_cupertino_alert_dialog.dart';
import 'package:bluebubbles/layouts/widgets/custom_cupertino_nav_bar.dart';
import 'package:bluebubbles/layouts/widgets/message_widget/reaction_detail_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/helpers/darty.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:sprung/sprung.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final CurrentChat? currentChat;
  final MessageBloc? messageBloc;

  @override
  MessageDetailsPopupState createState() => MessageDetailsPopupState();
}

class MessageDetailsPopupState extends State<MessageDetailsPopup> {
  List<Widget> reactionWidgets = <Widget>[];
  bool showTools = false;
  String? selfReaction;
  String? currentlySelectedReaction;
  CurrentChat? currentChat;
  Chat? dmChat;

  late double messageTopOffset;
  late double topMinimum;
  double? height;
  bool isBigSur = true;

  @override
  void initState() {
    super.initState();
    currentChat = widget.currentChat;

    messageTopOffset = widget.childOffsetY;
    topMinimum = CupertinoNavigationBar().preferredSize.height + 60 + (widget.message.hasReactions ? 110 : 50);

    dmChat = ChatBloc().chats.firstWhereOrNull(
          (chat) =>
              !chat.isGroup() && chat.participants.where((handle) => handle.id == widget.message.handleId).length == 1,
        );

    fetchReactions();

    SettingsManager().getMacOSVersion().then((val) {
      if (mounted) {
        setState(() {
          isBigSur = (val ?? 0) >= 11;
          showTools = true;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchReactions();
    SchedulerBinding.instance!.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          double totalHeight = context.height - detailsMenuHeight! - 20;
          double offset = (widget.childOffsetY + widget.childSize!.height) - totalHeight;
          messageTopOffset = widget.childOffsetY.clamp(topMinimum + 40, double.infinity);
          if (offset > 0) {
            messageTopOffset -= offset;
            messageTopOffset = messageTopOffset.clamp(topMinimum + 40, double.infinity);
          }
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
    Logger.info("Sending reaction type: " + type);
    ActionHandler.sendReaction(widget.currentChat!.chat, widget.message, type);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    bool isSent = !widget.message.guid!.startsWith('temp') && !widget.message.guid!.startsWith('error');
    bool hideReactions =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideReactions.value;

    double offsetX = widget.message.isFromMe! ? CustomNavigator.width(context) - widget.childSize!.width - 10 : 10;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value
            ? Colors.transparent
            : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    color: oledDarkTheme.colorScheme.secondary.withOpacity(0.3),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: Duration(milliseconds: 250),
                curve: Curves.easeOut,
                top: messageTopOffset + 50,
                left: offsetX,
                child: Container(
                  width: widget.childSize!.width,
                  height: widget.childSize!.height,
                  child: widget.child,
                ),
              ),
              Positioned(
                top: 40,
                left: 10,
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
                              width: CustomNavigator.width(context) - 20,
                              color: Theme.of(context).colorScheme.secondary,
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
              buildCopyPasteMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildReactionMenu() {
    double narrowWidth = widget.message.isFromMe! || !SettingsManager().settings.alwaysShowAvatars.value ? 330 : 360;
    bool narrowScreen = CustomNavigator.width(context) < narrowWidth;
    double reactionIconSize = 50;
    double maxMenuWidth = (ReactionTypes.toList().length / (narrowScreen ? 2 : 1) * reactionIconSize).toDouble();
    double menuHeight = (reactionIconSize * 2).toDouble();
    double topPadding = -10;
    if (topMinimum > context.height - 120 - menuHeight) {
      topMinimum = context.height - 120 - menuHeight;
    }
    double topOffset = (messageTopOffset + 50 - menuHeight).toDouble().clamp(topMinimum, context.height - 120 - menuHeight);
    bool shiftRight = currentChat!.chat.isGroup() || SettingsManager().settings.alwaysShowAvatars.value;
    double leftOffset =
        (widget.message.isFromMe! ? CustomNavigator.width(context) - maxMenuWidth - 25 : 20 + (shiftRight ? 35 : 0))
            .toDouble();
    Color iconColor = Colors.white;

    if (Theme.of(context).colorScheme.secondary.computeLuminance() >= 0.179) {
      iconColor = Colors.black.withAlpha(95);
    }

    return Positioned(
      bottom: context.height - topOffset - topPadding - menuHeight,
      left: leftOffset,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withAlpha(150),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: ReactionTypes.toList().slice(0, narrowScreen ? 3 : null)
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7.5, horizontal: 7.5),
                          child: Container(
                            width: reactionIconSize - 15,
                            height: reactionIconSize - 15,
                            decoration: BoxDecoration(
                              color: currentlySelectedReaction == e
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).colorScheme.secondary.withAlpha(150),
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
                                child: Reaction.getReactionIcon(e, iconColor),
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
                  children: ReactionTypes.toList().slice(3)
                      .map(
                        (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7.5, horizontal: 7.5),
                      child: Container(
                        width: reactionIconSize - 15,
                        height: reactionIconSize - 15,
                        decoration: BoxDecoration(
                          color: currentlySelectedReaction == e
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).colorScheme.secondary.withAlpha(150),
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
                            child: Reaction.getReactionIcon(e, iconColor),
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

  double? get detailsMenuHeight {
    return height;
  }

  set detailsMenuHeight(double? value) {
    height = value;
  }

  Widget buildCopyPasteMenu() {
    double maxMenuWidth = CustomNavigator.width(context) * 2 / 3;

    double maxHeight = context.height - topMinimum - widget.childSize!.height - 100;

    List<Widget> allActions = [
      if (widget.currentChat!.chat.isGroup() &&
          !widget.message.isFromMe! &&
          dmChat != null &&
          !LifeCycleManager().isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
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
              title: Text(
                "Open Direct Message",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.arrow_up_right_square
                    : Icons.open_in_new,
                color: Theme.of(context).textTheme.bodyText1!.color,
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
              Metadata? data = await MetadataHelper.fetchMetadata(widget.message);
              MethodChannelInterface().invokeMethod(
                "open-link",
                {"link": data?.url ?? widget.message.text, "forceBrowser": true},
              );
            },
            child: ListTile(
              title: Text(
                "Open In Browser",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.macwindow
                    : Icons.open_in_browser,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
            ),
          ),
        ),
      if (showDownload && kIsWeb && widget.message.attachments.first?.webUrl != null)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await launch(
                  widget.message.attachments.first!.webUrl! + "?guid=${SettingsManager().settings.guidAuthKey}");
            },
            child: ListTile(
              title: Text(
                "Open In New Tab",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.macwindow
                    : Icons.open_in_browser,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
            ),
          ),
        ),
      if (SettingsManager().settings.enablePrivateAPI.value && isBigSur && (currentChat?.chat.isIMessage ?? true))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              Navigator.of(context).pop();
              EventDispatcher().emit("focus-keyboard", widget.message);
            },
            child: ListTile(
              title: Text(
                "Reply",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.reply : Icons.reply,
                color: Theme.of(context).textTheme.bodyText1!.color,
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
              showReplyThread(context, widget.message, widget.messageBloc);
            },
            child: ListTile(
              title: Text(
                "View Thread",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.bubble_left_bubble_right
                    : Icons.forum,
                color: Theme.of(context).textTheme.bodyText1!.color,
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
              Contact? contact = ContactManager().getCachedContact(address: address);
              UniqueContact uniqueContact;
              if (contact == null) {
                uniqueContact = UniqueContact(address: address, displayName: (await formatPhoneNumber(handle)));
              } else {
                uniqueContact = UniqueContact(address: address, displayName: contact.displayName);
              }
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
              title: Text(
                "Start Conversation",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.chat_bubble
                    : Icons.message,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
            ),
          ),
        ),
      if (!LifeCycleManager().isBubble)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
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
                    );
                  },
                ),
              );
            },
            child: ListTile(
              title: Text(
                "Forward",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.arrow_right
                    : Icons.forward,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
            ),
          ),
        ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            NewMessageManager().removeMessage(widget.currentChat!.chat, widget.message.guid);
            Message.softDelete(widget.message.guid!);
            Navigator.of(context).pop();
          },
          child: ListTile(
            title: Text(
              "Delete",
              style: Theme.of(context).textTheme.bodyText1,
            ),
            trailing: Icon(
              SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.trash : Icons.delete,
              color: Theme.of(context).textTheme.bodyText1!.color,
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
              Navigator.of(context).pop();
              showSnackbar("Copied", "Copied to clipboard!", durationMs: 1000);
            },
            child: ListTile(
              title: Text("Copy", style: Theme.of(context).textTheme.bodyText1),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.doc_on_clipboard
                    : Icons.content_copy,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
            ),
          ),
        ),
      if (!isEmptyString(widget.message.fullText))
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (isEmptyString(widget.message.fullText)) return;
              showDialog(
                  context: context,
                  builder: (_) {
                    Widget title = Text(
                      "Copy",
                      style: Theme.of(context).textTheme.headline1,
                    );
                    Widget content = Container(
                      constraints: BoxConstraints(
                        maxHeight: context.height * 2 / 3,
                      ),
                      child: SingleChildScrollView(
                        physics: ThemeSwitcher.getScrollPhysics(),
                        child: SelectableText(
                          widget.message.fullText,
                          style: Theme.of(context).textTheme.bodyText1,
                        ),
                      ),
                    );
                    List<Widget> actions = <Widget>[
                      TextButton(
                        child: Text(
                          "Done",
                          // style: Theme.of(context).textTheme.bodyText1,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop('dialog');
                        },
                      ),
                    ];
                    if (SettingsManager().settings.skin.value == Skins.iOS) {
                      return CupertinoAlertDialog(
                        title: title,
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        content: content,
                      );
                    }
                    return AlertDialog(
                      title: title,
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      content: content,
                      actions: actions,
                    );
                  });
            },
            child: ListTile(
              title: Text(
                "Copy Selection",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.doc_on_clipboard
                    : Icons.content_copy,
                color: Theme.of(context).textTheme.bodyText1!.color,
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
                CurrentChat.activeChat?.clearImageData(element!);
                AttachmentHelper.redownloadAttachment(element!);
              }
              setState(() {});
              Navigator.of(context).pop();
            },
            child: ListTile(
              title: Text(
                "Re-download from Server",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.refresh : Icons.refresh,
                color: Theme.of(context).textTheme.bodyText1!.color,
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
                    await AttachmentHelper.saveToGallery(content);
                  }
                }
              } catch (ex, trace) {
                Logger.error(trace.toString());
                showSnackbar("Download Error", ex.toString());
              }
            },
            child: ListTile(
              title: Text(
                "Download to Device",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS
                    ? cupertino.CupertinoIcons.cloud_download
                    : Icons.file_download,
                color: Theme.of(context).textTheme.bodyText1!.color,
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
            },
            child: ListTile(
              title: Text(
                "Share",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.share : Icons.share,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
            ),
          ),
        ),
      if (!kIsWeb && !kIsDesktop)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final messageDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().toLocal(),
                  firstDate: DateTime.now().toLocal(),
                  lastDate: DateTime.now().toLocal().add(Duration(days: 365)));
              if (messageDate != null) {
                final messageTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (messageTime != null) {
                  final finalDate = DateTime(
                      messageDate.year, messageDate.month, messageDate.day, messageTime.hour, messageTime.minute);
                  if (!finalDate.isAfter(DateTime.now().toLocal())) {
                    showSnackbar("Error", "Select a date in the future");
                    return;
                  }
                  NotificationManager().scheduleNotification(widget.currentChat!.chat, widget.message, finalDate);
                  Get.back();
                  showSnackbar("Notice", "Scheduled reminder for ${buildDate(finalDate)}");
                }
              }
            },
            child: ListTile(
              title: Text(
                "Remind Later",
                style: Theme.of(context).textTheme.bodyText1,
              ),
              trailing: Icon(
                SettingsManager().settings.skin.value == Skins.iOS ? cupertino.CupertinoIcons.alarm : Icons.alarm,
                color: Theme.of(context).textTheme.bodyText1!.color,
              ),
            ),
          ),
        ),
    ];

    List<Widget> detailsActions = [];
    List<Widget> moreActions = [];
    double itemHeight = 56;

    double actualHeight = 2 * itemHeight;
    int index = 0;
    while (actualHeight <= maxHeight - itemHeight && index < allActions.length) {
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
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: Theme.of(context).colorScheme.secondary.withAlpha(150),
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
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (_) {
                            Widget content = Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: moreActions,
                            );
                            if (SettingsManager().settings.skin.value == Skins.iOS) {
                              return CupertinoAlertDialog(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                content: content,
                              );
                            }
                            return AlertDialog(
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              content: content,
                            );
                          });
                    },
                    child: ListTile(
                      title: Text("More...", style: Theme.of(context).textTheme.bodyText1),
                      trailing: Icon(
                        SettingsManager().settings.skin.value == Skins.iOS
                            ? cupertino.CupertinoIcons.ellipsis
                            : Icons.more_vert,
                        color: Theme.of(context).textTheme.bodyText1!.color,
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
    bool shiftRight = currentChat!.chat.isGroup() || SettingsManager().settings.alwaysShowAvatars.value;
    double leftOffset =
        (widget.message.isFromMe! ? CustomNavigator.width(context) - maxMenuWidth - 15 : 20 + (shiftRight ? 35 : 0))
            .toDouble();
    return Positioned(
      top: topOffset + 55,
      left: leftOffset,
      child: menu,
    );
  }
}
