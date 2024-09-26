import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/typing/typing_indicator.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/cupertino_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/material_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/samsung_conversation_tile.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/reactivity/reactive_chat.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class ConversationTileController extends StatefulController {
  final RxBool shouldHighlight = false.obs;
  final RxBool shouldPartialHighlight = false.obs;
  final RxBool hoverHighlight = false.obs;
  final String chatGuid;
  final ConversationListController listController;
  final Function(bool)? onSelect;
  final bool inSelectMode;
  final Widget? subtitle;

  bool get isSelected => listController.selectedChats
      .firstWhereOrNull((e) => e == chatGuid) != null;

  ReactiveChat get reactiveChat => GlobalChatService.getChat(chatGuid)!;

  Chat get chat => reactiveChat.chat;

  ConversationTileController({
    Key? key,
    required this.chatGuid,
    required this.listController,
    this.onSelect,
    this.inSelectMode = false,
    this.subtitle,
  });

  void onTap(BuildContext context) {
    if ((inSelectMode || listController.selectedChats.isNotEmpty) && onSelect != null) {
      onLongPress();
    } else if ((!kIsDesktop && !kIsWeb) || GlobalChatService.activeGuid.value != chatGuid) {
      GlobalChatService.openChat(chatGuid);
    } else if (ns.isTabletMode(context) && !GlobalChatService.hasActiveChat) {
      // Pops chat details
      Get.back(id: 2);
    } else {
      cvc(chatGuid).lastFocusedNode.requestFocus();
    }
  }

  Future<void> onSecondaryTap(BuildContext context, TapUpDetails details) async {
    if (kIsWeb) {
      (await html.document.onContextMenu.first).preventDefault();
    }
    shouldPartialHighlight.value = true;
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
    onSelect!.call(!isSelected);
    if (ss.settings.skin.value == Skins.Material) {
      updateWidgets<MaterialConversationTile>(null);
    }
    if (ss.settings.skin.value == Skins.Samsung) {
      updateWidgets<SamsungConversationTile>(null);
    }
  }
}

class ConversationTile extends CustomStateful<ConversationTileController> {
  ConversationTile({
    super.key,
    required String chatGuid,
    required ConversationListController controller,
    Function(bool)? onSelect,
    bool inSelectMode = false,
    Widget? subtitle,
  }) : super(parentController: !inSelectMode && Get.isRegistered<ConversationTileController>(tag: chatGuid)
      ? Get.find<ConversationTileController>(tag: chatGuid)
      : Get.put(ConversationTileController(
        chatGuid: chatGuid,
        listController: controller,
        onSelect: onSelect,
        inSelectMode: inSelectMode,
        subtitle: subtitle,
      ), tag: inSelectMode ? randomString(8) : chatGuid, permanent: kIsDesktop || kIsWeb)
  );

  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends CustomState<ConversationTile, void, ConversationTileController> with AutomaticKeepAliveClientMixin {
  ConversationListController get listController => controller.listController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;

    if (kIsDesktop || kIsWeb) {
      controller.shouldHighlight.value =
          GlobalChatService.activeGuid.value == controller.chatGuid;
    }

    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'update-highlight' && mounted) {
        if ((kIsDesktop || kIsWeb) && event.item2 == controller.chatGuid) {
          controller.shouldHighlight.value = true;
        } else if (controller.shouldHighlight.value) {
          controller.shouldHighlight.value = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MouseRegion(
      onEnter: (event) => controller.hoverHighlight.value = true,
      onExit: (event) => controller.hoverHighlight.value = false,
      cursor: SystemMouseCursors.click,
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
  const ChatTitle({Key? key, required super.parentController, required this.style});

  final TextStyle style;

  @override
  State<StatefulWidget> createState() => _ChatTitleState();
}

class _ChatTitleState extends CustomState<ChatTitle, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    // run query after render has completed
    if (!kIsWeb) {
      // listen for contacts update (if tile is active, we can update it)
      eventDispatcher.stream.listen((event) {
        if (event.item1 != 'update-contacts') return;
        if (event.item2.isNotEmpty) {
          for (Handle h in controller.chat.participants) {
            if (event.item2.first.contains(h.contactRelation.targetId)) {
              h.contactRelation.target = Database.contacts.get(h.contactRelation.targetId);
            }
            if (event.item2.last.contains(h.id)) {
              h = Database.handles.get(h.id!)!;
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
      String _title = controller.reactiveChat.title.value ?? "Unknown";
      if (hideInfo) {
        _title = controller.chat.participants.length > 1 ? "Group Chat" : controller.chat.participants[0].fakeName;
      }

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
  const ChatSubtitle({Key? key, required super.parentController, required this.style});

  final TextStyle style;

  @override
  State<StatefulWidget> createState() => _ChatSubtitleState();
}

class _ChatSubtitleState extends CustomState<ChatSubtitle, void, ConversationTileController> {

  @override
  void initState() {
    super.initState();
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideContent = ss.settings.redactedMode.value && ss.settings.hideMessageContent.value;
      final latestMessage = controller.reactiveChat.latestMessage.value;
      final isFromMe = latestMessage?.isFromMe ?? false;
      final isDelivered = controller.chat.isGroup || !isFromMe || latestMessage?.dateDelivered != null || latestMessage?.dateRead != null;
      String _subtitle = (hideContent ? latestMessage?.obfuscatedText : latestMessage?.notificationText) ?? "No messages";

      return RichText(
        text: TextSpan(
          children: MessageHelper.buildEmojiText(
            "${!iOS && isFromMe ? "You: " : ""}$_subtitle",
            widget.style.copyWith(fontStyle: !iOS && !isDelivered ? FontStyle.italic : null),
          ),
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: ss.settings.denseChatTiles.value ? 1 : material ? 3 : 2,
      );
    });
  }
}

class ChatLeading extends StatefulWidget {
  final ConversationTileController controller;
  final Widget? unreadIcon;

  ChatLeading({required this.controller, this.unreadIcon});

  @override
  ChatLeadingState createState() => ChatLeadingState();
}

class ChatLeadingState extends OptimizedState<ChatLeading> {

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.unreadIcon != null && iOS)
          widget.unreadIcon!,
        Obx(() {
          final showTypingIndicator = cvc(widget.controller.chatGuid).showTypingIndicator.value;
          double height = Theme.of(context).textTheme.labelLarge!.fontSize! * 1.25;
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 2),
                child: widget.controller.isSelected ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: context.theme.colorScheme.primary,
                  ),
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Icon(
                      Icons.check,
                      color: context.theme.colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                ) : ContactAvatarGroupWidget(
                  chatGuid: widget.controller.chatGuid,
                  size: 40,
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