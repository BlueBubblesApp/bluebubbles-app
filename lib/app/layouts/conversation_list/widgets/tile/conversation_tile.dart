import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/typing/typing_indicator.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/cupertino_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/material_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/samsung_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/database/database.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:faker/faker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as html;

class ConversationTileController extends StatefulController {
  final RxBool shouldHighlight = false.obs;
  final RxBool shouldPartialHighlight = false.obs;
  final RxBool hoverHighlight = false.obs;
  final Chat chat;
  final ConversationListController listController;
  final Function(bool)? onSelect;
  final bool inSelectMode;
  final Widget? subtitle;

  bool get isSelected => listController.selectedChats
      .firstWhereOrNull((e) => e.guid == chat.guid) != null;

  ConversationTileController({
    Key? key,
    required this.chat,
    required this.listController,
    this.onSelect,
    this.inSelectMode = false,
    this.subtitle,
  });

  void onTap(BuildContext context) {
    if ((inSelectMode || listController.selectedChats.isNotEmpty) && onSelect != null) {
      onLongPress();
    } else if ((!kIsDesktop && !kIsWeb) || cm.activeChat?.chat.guid != chat.guid) {
      ns.pushAndRemoveUntil(
        context,
        ConversationView(
          chat: chat,
        ),
        (route) => route.isFirst,
      );
    } else if (ns.isTabletMode(context) && cm.activeChat?.isAlive == false) {
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
    required Chat chat,
    required ConversationListController controller,
    Function(bool)? onSelect,
    bool inSelectMode = false,
    Widget? subtitle,
  }) : super(parentController: !inSelectMode && Get.isRegistered<ConversationTileController>(tag: chat.guid)
      ? Get.find<ConversationTileController>(tag: chat.guid)
      : Get.put(ConversationTileController(
        chat: chat,
        listController: controller,
        onSelect: onSelect,
        inSelectMode: inSelectMode,
        subtitle: subtitle,
      ), tag: inSelectMode ? randomString(8) : chat.guid, permanent: kIsDesktop || kIsWeb)
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
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;

    if (kIsDesktop || kIsWeb) {
      controller.shouldHighlight.value =
          cm.activeChat?.chat.guid == controller.chat.guid;
    }

    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'update-highlight' && mounted) {
        if ((kIsDesktop || kIsWeb) && event.item2 == controller.chat.guid) {
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
  String title = "Unknown";
  StreamSubscription? sub;
  String? cachedDisplayName = "";
  List<Handle> cachedParticipants = [];

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    cachedDisplayName = controller.chat.displayName;
    cachedParticipants = controller.chat.handles;
    title = controller.chat.getTitle();
    // run query after render has completed
    if (!kIsWeb) {
      updateObx(() {
        final titleQuery = Database.chats.query(Chat_.guid.equals(controller.chat.guid))
            .watch();
        sub = titleQuery.listen((Query<Chat> query) async {
          final chat = controller.chat.id == null ? null : await runAsync(() {
            return Database.chats.get(controller.chat.id!);
          });
          if (chat == null) return;
          // check if we really need to update this widget
          if (chat.displayName != cachedDisplayName
              || chat.handles.length != cachedParticipants.length) {
            final newTitle = chat.getTitle();
            if (newTitle != title) {
              setState(() {
                title = newTitle;
              });
            }
          }
          cachedDisplayName = chat.displayName;
          cachedParticipants = chat.handles;
        });
      });
      // listen for contacts update (if tile is active, we can update it)
      eventDispatcher.stream.listen((event) {
        if (event.item1 != 'update-contacts') return;
        if (event.item2.isNotEmpty) {
          bool changed = false;
          for (Handle h in controller.chat.participants) {
            if (event.item2.first.contains(h.contactRelation.targetId)) {
              changed = true;
              h.contactRelation.target = Database.contacts.get(h.contactRelation.targetId);
            }
            if (event.item2.last.contains(h.id)) {
              changed = true;
              h = Database.handles.get(h.id!)!;
            }
          }
          if (changed) {
            final newTitle = controller.chat.getTitle();
            if (newTitle != title) {
              setState(() {
                title = newTitle;
              });
            }
          }
        }
      });
    } else {
      sub = WebListeners.chatUpdate.listen((chat) {
        if (chat.guid == controller.chat.guid) {
          // check if we really need to update this widget
          if (chat.displayName != cachedDisplayName
              || chat.participants.length != cachedParticipants.length) {
            final newTitle = chat.getTitle();
            if (newTitle != title) {
              setState(() {
                title = newTitle;
              });
            }
          }
          cachedDisplayName = chat.displayName;
          cachedParticipants = chat.participants;
        }
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
      String _title = title;
      if (hideInfo) {
        _title = controller.chat.isGroup ? controller.chat.fakeName : controller.chat.participants[0].fakeName;
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
  String subtitle = "Unknown";
  String fakeText = faker.lorem.words(1).join(" ");
  StreamSubscription? sub;
  String? cachedLatestMessageGuid = "";
  DateTime? cachedDateCreated;
  DateTime? cachedDateEdited;
  bool isDelivered = false;
  bool isFromMe = false;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    subtitle = MessageHelper.getNotificationText(controller.chat.latestMessage);
    cachedLatestMessageGuid = controller.chat.latestMessage.guid!;
    cachedDateEdited = controller.chat.latestMessage.dateEdited;
    isFromMe = controller.chat.latestMessage.isFromMe!;
    isDelivered = controller.chat.isGroup || !isFromMe || controller.chat.latestMessage.dateDelivered != null
        || controller.chat.latestMessage.dateRead != null;
    fakeText = faker.lorem.words(subtitle.split(" ").length).join(" ");
    // run query after render has completed
    if (!kIsWeb) {
      updateObx(() {
        final latestMessageQuery = (Database.messages.query(Message_.dateDeleted.isNull())
          ..link(Message_.chat, Chat_.guid.equals(controller.chat.guid))
          ..order(Message_.dateCreated, flags: Order.descending))
            .watch();

        sub = latestMessageQuery.listen((Query<Message> query) async {
          final message = await runAsync(() {
            return query.findFirst();
          });
          isFromMe = message?.isFromMe ?? false;
          isDelivered = controller.chat.isGroup || !isFromMe || message?.dateDelivered != null || message?.dateRead != null;
          // check if we really need to update this widget
          if (message != null && (message.guid != cachedLatestMessageGuid || message.dateEdited != cachedDateEdited)) {
            message.handle = message.getHandle();
            String newSubtitle = MessageHelper.getNotificationText(message);
            if (newSubtitle != subtitle) {
              setState(() {
                subtitle = newSubtitle;
                fakeText = faker.lorem.words(subtitle.split(" ").length).join(" ");
              });
            }
          } else if (!controller.chat.isGroup
              && message != null
              && message.isFromMe!
              && (message.dateDelivered != null || message.dateRead != null)) {
            // update delivered status
            setState(() {});
          }
          cachedLatestMessageGuid = message?.guid;
          cachedDateEdited = message?.dateEdited;
        });
      });
    } else {
      // listen for contacts update (if tile is active, we can update it)
      eventDispatcher.stream.listen((event) {
        if (event.item1 != 'update-contacts') return;
        if (event.item2.isNotEmpty) {
          String newSubtitle = MessageHelper.getNotificationText(controller.chat.latestMessage);
          if (newSubtitle != subtitle) {
            setState(() {
              subtitle = newSubtitle;
              fakeText = faker.lorem.words(subtitle.split(" ").length).join(" ");
            });
          }
        }
      });
      sub = WebListeners.newMessage.listen((tuple) {
        final message = tuple.item1;
        if (tuple.item2?.guid == controller.chat.guid && (cachedDateCreated == null || message.dateCreated!.isAfter(cachedDateCreated!))) {
          isFromMe = message.isFromMe ?? false;
          isDelivered = controller.chat.isGroup || !isFromMe || message.dateDelivered != null || message.dateRead != null;
          if (message.guid != cachedLatestMessageGuid || message.dateEdited != cachedDateEdited) {
            String newSubtitle = MessageHelper.getNotificationText(message);
            if (newSubtitle != subtitle) {
              setState(() {
                subtitle = newSubtitle;
                fakeText = faker.lorem.words(subtitle.split(" ").length).join(" ");
              });
            }
          } else if (!controller.chat.isGroup
              && message.isFromMe!
              && (message.dateDelivered != null || message.dateRead != null)) {
            // update delivered status
            setState(() {});
          }
          cachedDateCreated = message.dateCreated;
          cachedLatestMessageGuid = message.guid;
          cachedDateEdited = message.dateEdited;
        }
      });
    }
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideContent = ss.settings.redactedMode.value && ss.settings.hideMessageContent.value;
      final hideContacts = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
      String _subtitle = hideContent ? fakeText : hideContacts && !kIsWeb ? MessageHelper.getNotificationText(Message.findOne(guid: cachedLatestMessageGuid!)!) : subtitle;

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
          final showTypingIndicator = cvc(widget.controller.chat).showTypingIndicator.value;
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
                  chat: widget.controller.chat,
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