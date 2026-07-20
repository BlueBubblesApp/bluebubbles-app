import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/typing/typing_indicator.dart';
import 'package:bluebubbles/app/state/chat_state.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/cupertino_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/material_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/samsung_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class ConversationTileController extends StatefulController {
  final RxBool shouldHighlight = false.obs;
  final RxBool shouldPartialHighlight = false.obs;
  final ChatState chatState;
  final ConversationListController listController;
  final Function(bool)? onSelect;
  final bool inSelectMode;
  final Widget? subtitle;

  Chat get chat => chatState.chat;

  bool get isSelected => listController.selectedChats.firstWhereOrNull((e) => e.guid == chat.guid) != null;

  ConversationTileController({
    Key? key,
    required this.chatState,
    required this.listController,
    this.onSelect,
    this.inSelectMode = false,
    this.subtitle,
  });

  void onTap(BuildContext context) {
    if ((inSelectMode || listController.selectedChats.isNotEmpty) && onSelect != null) {
      onLongPress();
    } else if ((!kIsDesktop && !kIsWeb) || ChatsSvc.activeChat?.chat.guid != chat.guid) {
      NavigationSvc.pushAndRemoveUntil(
        context,
        ConversationView(
          chat: chat,
        ),
        (route) => route.isFirst,
      );
    } else if (NavigationSvc.isTabletMode(context) && ChatsSvc.activeChat?.isAlive.value == false) {
      // Pops chat details
      Get.back(id: 2);
    } else {
      cvc(chat).lastFocusedNode.requestFocus();
    }
  }

  Future<void> onSecondaryTap(BuildContext context, TapUpDetails details) async {
    if (kIsWeb) {
      (await html.document.onContextMenu.first).preventDefault();
    }
    shouldPartialHighlight.value = true;
    if (!context.mounted) return;
    await showConversationTileMenu(
      context,
      this,
      chat,
      details.globalPosition,
      context.textTheme,
    );
    shouldPartialHighlight.value = false;
  }

  void onLongPress() {
    onSelected();
    HapticFeedback.lightImpact();
  }

  void onSelected() {
    onSelect?.call(!isSelected);
    if (SettingsSvc.settings.skin.value == Skins.Material) {
      updateWidgets<MaterialConversationTile>(null);
    }
    if (SettingsSvc.settings.skin.value == Skins.Samsung) {
      updateWidgets<SamsungConversationTile>(null);
    }
  }
}

class ConversationTile extends CustomStateful<ConversationTileController> {
  ConversationTile({
    super.key,
    required Chat chat,
    required ConversationListController controller,
    Function(bool)? onSelect,
    bool inSelectMode = false,
    Widget? subtitle,
  }) : super(
            parentController: !inSelectMode && Get.isRegistered<ConversationTileController>(tag: chat.guid)
                ? Get.find<ConversationTileController>(tag: chat.guid)
                : Get.put(
                    ConversationTileController(
                      chatState: ChatsSvc.getOrCreateChatState(chat),
                      listController: controller,
                      onSelect: onSelect,
                      inSelectMode: inSelectMode,
                      subtitle: subtitle,
                    ),
                    tag: inSelectMode ? randomString(8) : chat.guid,
                    permanent: kIsDesktop || kIsWeb));

  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends CustomState<ConversationTile, void, ConversationTileController>
    with AutomaticKeepAliveClientMixin {
  ConversationListController get listController => controller.listController;
  StreamSubscription? _activeSub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;


    controller.shouldHighlight.value = ChatsSvc.activeChatGuid.value == controller.chat.guid;
    _activeSub = ChatsSvc.activeChatGuid.listen((guid) {
      Future.microtask(() {
        if (mounted) controller.shouldHighlight.value = guid == controller.chat.guid;
      });
    });
  }

  @override
  void dispose() {
    _activeSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MouseRegion(
      child: ThemeSwitcher(
        iOSSkin: CupertinoConversationTile(
          parentController: controller,
        ),
        materialSkin: MaterialConversationTile(
          parentController: controller,
        ),
        samsungSkin: SamsungConversationTile(
          parentController: controller,
        ),
      ),
    );
  }
}

class ChatTitle extends CustomStateful<ConversationTileController> {
  const ChatTitle({super.key, required super.parentController, required this.style});

  final TextStyle style;

  @override
  State<StatefulWidget> createState() => _ChatTitleState();
}

class _ChatTitleState extends CustomState<ChatTitle, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Get title from ChatState - it handles all title logic including redacted mode
      final _title = controller.chatState.title.value ?? controller.chat.getTitle();

      return RichText(
        text: TextSpan(
          children: MessageHelper.buildEmojiText(
            _title,
            widget.style,
          ),
        ),
        overflow: TextOverflow.ellipsis,
      );
    });
  }
}

class ChatSubtitle extends CustomStateful<ConversationTileController> {
  const ChatSubtitle({super.key, required super.parentController, required this.style});

  final TextStyle style;

  @override
  State<StatefulWidget> createState() => _ChatSubtitleState();
}

class _ChatSubtitleState extends CustomState<ChatSubtitle, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chatState = controller.chatState;
      final latestMessage = chatState.latestMessage.value;
      final isFromMe = latestMessage?.isFromMe ?? false;
      final isDelivered =
          controller.chat.isGroup || !isFromMe || latestMessage?.isDelivered == true || latestMessage?.dateRead != null;

      // subtitle.value is already contact-info-free when redacted mode is on
      // (ChatState.redactContactInfo / updateChatLatestMessage ensure this).
      final String _subtitle = chatState.subtitle.value ?? '';

      // Draft detection — show "Draft: ..." when there is staged text or attachments.
      final draftText = chatState.textFieldText.value ?? '';
      final hasDraftText = draftText.isNotEmpty;
      final hasDraftAttachments = chatState.textFieldAttachments.isNotEmpty;
      final hasDraft = hasDraftText || hasDraftAttachments;

      final maxLines = SettingsSvc.settings.denseChatTiles.value ? 1 : 2;
      final lineHeight = (widget.style.fontSize ?? 14) * (widget.style.height ?? 1.5);

      // For material DMs with a message from me, show a delivery check icon
      // instead of italic styling — mirrors the Google Messages visual pattern.
      // Suppress when showing a draft so the layout stays clean.
      final showDeliveryIcon = material && isFromMe && !controller.chat.isGroup && !hasDraft;
      final isMonet = ThemeSvc.isAnyMaterialYouSelected;
      final iconColor = isMonet ? context.theme.colorScheme.primary : context.theme.colorScheme.outline;

      final TextSpan subtitleSpan;
      if (hasDraft) {
        final draftBody = hasDraftText ? draftText : 'Attachment';
        subtitleSpan = TextSpan(children: [
          TextSpan(
            text: 'Draft: ',
            style: widget.style.copyWith(
              color: context.theme.colorScheme.error,
              fontStyle: FontStyle.normal,
            ),
          ),
          ...MessageHelper.buildEmojiText(draftBody, widget.style),
        ]);
      } else {
        subtitleSpan = TextSpan(
          children: MessageHelper.buildEmojiText(
            "${!iOS && isFromMe ? "You: " : ""}$_subtitle",
            widget.style.copyWith(fontStyle: !iOS && !material && !isDelivered ? FontStyle.italic : null),
          ),
        );
      }

      final richText = RichText(
        text: subtitleSpan,
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
      );

      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: lineHeight * (material ? 1 : maxLines)),
          child: showDeliveryIcon
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                          right: 4, top: ((widget.style.fontSize ?? 14) * (widget.style.height ?? 1.5) - 14) / 2),
                      child: Opacity(
                        opacity: isDelivered ? 1.0 : 0.35,
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: iconColor,
                        ),
                      ),
                    ),
                    Expanded(child: richText),
                  ],
                )
              : richText,
        ),
      );
    });
  }
}

class ChatLeading extends StatefulWidget {
  final ConversationTileController controller;
  final Widget? unreadIcon;

  const ChatLeading({super.key, required this.controller, this.unreadIcon});

  @override
  ChatLeadingState createState() => ChatLeadingState();
}

class ChatLeadingState extends State<ChatLeading> with ThemeHelpers {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.unreadIcon != null && iOS) widget.unreadIcon!,
        Obx(() {
          final showTypingIndicator = cvc(widget.controller.chat).showTypingIndicator.value;
          double height = Theme.of(context).textTheme.labelLarge!.fontSize! * 1.25;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 2),
                child: widget.controller.isSelected
                    ? Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: context.theme.colorScheme.primary,
                        ),
                        width: SettingsSvc.settings.denseChatTiles.value ? 36 : (material ? 50 : 45),
                        height: SettingsSvc.settings.denseChatTiles.value ? 36 : (material ? 50 : 45),
                        child: Center(
                          child: Icon(
                            Icons.check,
                            color: context.theme.colorScheme.onPrimary,
                            size: 26,
                          ),
                        ),
                      )
                    : ContactAvatarGroupWidget(
                        chat: widget.controller.chat,
                        size: SettingsSvc.settings.denseChatTiles.value ? 36 : (material ? 50 : 45),
                        editable: false,
                      ),
              ),
              if (showTypingIndicator)
                Positioned(
                  top: 30,
                  left: 20,
                  height: height,
                  child: const FittedBox(
                    alignment: Alignment.centerLeft,
                    child: TypingIndicator(
                      visible: true,
                    ),
                  ),
                ),
              if (widget.unreadIcon != null && samsung)
                Positioned(
                  top: 0,
                  right: 0,
                  height: height * 0.75,
                  child: FittedBox(
                    alignment: Alignment.centerRight,
                    child: widget.unreadIcon,
                  ),
                ),
            ],
          );
        })
      ],
    );
  }
}
