import 'dart:async';
import 'dart:math';

import 'package:bluebubbles/helpers/models/constants.dart';
import 'package:bluebubbles/helpers/models/extensions.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/layouts/conversation_list/dialogs/conversation_peek_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/pinned_tile_text_bubble.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/reactions_widget.dart';
import 'package:bluebubbles/app/widgets/message_widget/typing_indicator.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/core/managers/chat/chat_controller.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class PinnedConversationTile extends CustomStateful<ConversationTileController> {
  PinnedConversationTile({
    Key? key,
    required Chat chat,
    required ConversationListController controller,
  }) : super(key: key, parentController: Get.isRegistered<ConversationTileController>(tag: chat.guid)
      ? Get.find<ConversationTileController>(tag: chat.guid)
      : Get.put(ConversationTileController(
      chat: chat,
      listController: controller,
    ), tag: "${chat.guid}-pinned")
  );

  @override
  State<PinnedConversationTile> createState() => _PinnedConversationTileState();
}

class _PinnedConversationTileState extends CustomState<PinnedConversationTile, void, ConversationTileController> {
  ConversationListController get listController => controller.listController;
  Offset? longPressPosition;

  @override
  void initState() {
    super.initState();

    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;

    if (kIsDesktop || kIsWeb) {
      controller.shouldHighlight.value =
          ChatManager().activeChat?.chat.guid == controller.chat.guid;
    }

    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'update-highlight' && mounted) {
        if ((kIsDesktop || kIsWeb) && event.item2 == controller.chat.guid) {
          controller.shouldHighlight.value = true;
        } else if (controller.shouldHighlight.value = true) {
          controller.shouldHighlight.value = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 7, right: 7, top: 1, bottom: 3),
      child: MouseRegion(
        onEnter: (event) => controller.hoverHighlight.value = true,
        onExit: (event) => controller.hoverHighlight.value = false,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) {
            longPressPosition = details.globalPosition;
          },
          onTap: () => controller.onTap(context),
          onLongPress: kIsDesktop || kIsWeb ? null : () async {
            await peekChat(context, controller.chat, longPressPosition ?? Offset.zero);
          },
          onSecondaryTapUp: (details) => controller.onSecondaryTap(context, details),
          child: Obx(() => AnimatedContainer(
            duration: Duration(milliseconds: 100),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(
              top: 4,
              left: 8,
              right: 8,
              bottom: 2,
            ),
            decoration: BoxDecoration(
              color: controller.shouldPartialHighlight.value
                  ? context.theme.colorScheme.properSurface.lightenOrDarken(10)
                  : controller.shouldHighlight.value
                  ? context.theme.colorScheme.bubble(context, controller.chat.isIMessage)
                  : controller.hoverHighlight.value
                  ? context.theme.colorScheme.properSurface
                  : null,
              borderRadius: BorderRadius.circular(
                  controller.shouldHighlight.value
                      || controller.shouldPartialHighlight.value
                      || controller.hoverHighlight.value
                      ? 8 : 0
              ),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Great math right here
                final availableWidth = constraints.maxWidth;
                final colCount = kIsDesktop
                    ? ss.settings.pinColumnsLandscape.value
                    : ss.settings.pinColumnsPortrait.value;
                final spaceBetween = (colCount - 1) * 30;
                final maxWidth = max(((availableWidth - spaceBetween) / colCount).floorToDouble(), 0).toDouble();

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: <Widget>[
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            children: <Widget>[
                              ContactAvatarGroupWidget(
                                chat: controller.chat,
                                size: maxWidth,
                                editable: false,
                                onTap: () => controller.onTap(context),
                              ),
                              UnreadIcon(width: maxWidth, parentController: controller),
                              MuteIcon(width: maxWidth, parentController: controller),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: maxWidth * 0.075,
                            ),
                            child: ChatTitle(parentController: controller),
                          ),
                        ],
                      ),
                      PinnedIndicators(width: maxWidth, controller: controller),
                      ReactionIcon(width: maxWidth, parentController: controller),
                      Positioned(
                        bottom: context.textTheme.bodyMedium!.fontSize! * 3,
                        width: maxWidth,
                        child: PinnedTileTextBubble(
                          chat: controller.chat,
                          size: maxWidth,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          )),
        ),
      ),
    );
  }
}

class UnreadIcon extends CustomStateful<ConversationTileController> {
  const UnreadIcon({Key? key, required this.width, required super.parentController});
  
  final double width;

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends CustomState<UnreadIcon, void, ConversationTileController> {
  bool unread = false;
  late final StreamSubscription<Query<Chat>> sub;

  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    unread = controller.chat.hasUnreadMessage ?? false;
    updateObx(() {
      final unreadQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
          .watch();
      sub = unreadQuery.listen((Query<Chat> query) {
        final chat = query.findFirst()!;
        if (chat.hasUnreadMessage != unread) {
          setState(() {
            unread = chat.hasUnreadMessage!;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return unread ? Positioned(
      left: sqrt(widget.width) - widget.width * 0.05 * sqrt(2),
      top: sqrt(widget.width) - widget.width * 0.05 * sqrt(2),
      child: Container(
        width: widget.width * 0.2,
        height: widget.width * 0.2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.theme.colorScheme.primary,
        ),
        margin: const EdgeInsets.only(right: 3),
      ),
    ) : const SizedBox.shrink();
  }
}

class MuteIcon extends CustomStateful<ConversationTileController> {
  const MuteIcon({Key? key, required this.width, required super.parentController});
  
  final double width;

  @override
  State<StatefulWidget> createState() => _MuteIconState();
}

class _MuteIconState extends CustomState<MuteIcon, void, ConversationTileController> {
  bool unread = false;
  String muteType = "";
  late final StreamSubscription<Query<Chat>> sub;

  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    // run query after render has completed
    updateObx(() {
      final unreadQuery = chatBox.query((Chat_.hasUnreadMessage.equals(true)
          .or(Chat_.muteType.equals("mute")))
          .and(Chat_.guid.equals(controller.chat.guid)))
          .watch();
      sub = unreadQuery.listen((Query<Chat> query) {
        final chat = query.findFirst();
        final newUnread = chat?.hasUnreadMessage ?? false;
        final newMute = chat?.muteType ?? "";
        if (chat != null && unread != newUnread) {
          setState(() {
            unread = newUnread;
          });
        } else if (chat == null && unread) {
          setState(() {
            unread = false;
          });
        } else if (muteType != newMute) {
          setState(() {
            muteType = newMute;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return muteType == "mute" ? Positioned(
      left: sqrt(widget.width) - widget.width * 0.05 * sqrt(2),
      top: sqrt(widget.width) - widget.width * 0.05 * sqrt(2),
      child: Container(
        width: widget.width * 0.2,
        height: widget.width * 0.2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: unread
              ? context.theme.colorScheme.primaryContainer
              : context.theme.colorScheme.tertiaryContainer,
        ),
        child: Icon(
          CupertinoIcons.bell_slash_fill,
          size: widget.width * 0.14,
          color: unread
              ? context.theme.colorScheme.onPrimaryContainer
              : context.theme.colorScheme.onTertiaryContainer,
        ),
      ),
    ) : const SizedBox.shrink();
  }
}

class ChatTitle extends CustomStateful<ConversationTileController> {
  const ChatTitle({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _ChatTitleState();
}

class _ChatTitleState extends CustomState<ChatTitle, void, ConversationTileController> {
  String title = "Unknown";
  late final StreamSubscription<Query<Chat>> sub;
  String? cachedDisplayName = "";
  List<Handle> cachedParticipants = [];

  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    cachedDisplayName = controller.chat.displayName;
    cachedParticipants = controller.chat.handles;
    title = controller.chat.getTitle() ?? title;
    // run query after render has completed
    updateObx(() {
      final titleQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
          .watch();
      sub = titleQuery.listen((Query<Chat> query) {
        final chat = query.findFirst()!;
        // check if we really need to update this widget
        if (chat.displayName != cachedDisplayName
            || chat.handles.length != cachedParticipants.length) {
          final newTitle = getFullChatTitle(chat);
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
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hideInfo = ss.settings.redactedMode.value
          && ss.settings.hideContactInfo.value;
      final generateNames = ss.settings.redactedMode.value
          && ss.settings.generateFakeContactNames.value;
      
      final style = context.theme.textTheme.bodyMedium!.apply(
          color: controller.shouldHighlight.value
              ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
              : context.theme.colorScheme.outline
      );

      if (hideInfo) return const SizedBox.shrink();

      String _title = title;
      if (generateNames) {
        _title = controller.chat.participants.length > 1 ? "Group Chat" : controller.chat.participants[0].fakeName;
      }

      return SizedBox(
        height: style.height! * style.fontSize! * 2,
        child: Align(
          alignment: Alignment.center,
          child: RichText(
            text: TextSpan(
              children: MessageHelper.buildEmojiText(
                _title,
                style,
              ),
            ),
            overflow: TextOverflow.ellipsis,
          )
        ),
      );
    });
  }
}

class PinnedIndicators extends StatelessWidget {
  final ConversationTileController controller;
  final double width;

  PinnedIndicators({required this.width, required this.controller});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
        stream: ChatManager().getChatController(controller.chat.guid)?.stream as Stream<Map<String, dynamic>>?,
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          bool showTypingIndicator = false;
          if (snapshot.connectionState == ConnectionState.active
              && snapshot.hasData
              && snapshot.data["type"] == ChatControllerEvent.TypingStatus) {
            showTypingIndicator = snapshot.data["data"];
          }
          MessageMarkers? markers = ChatManager().getChatController(controller.chat.guid)?.messageMarkers;

          return Obx(() {
            if (showTypingIndicator) {
              return Positioned(
                top: -sqrt(width / 2),
                right: -sqrt(width / 2) - width * 0.25,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 32),
                  child: const FittedBox(
                    child: TypingIndicator(
                      visible: true,
                    ),
                  ),
                ),
              );
            }

            final showMarker = shouldShow(
                controller.chat.latestMessageGetter,
                markers?.myLastMessage.value,
                markers?.lastReadMessage.value,
                markers?.lastDeliveredMessage.value
            );
            if (ss.settings.statusIndicatorsOnChats.value
                && !controller.chat.isGroup()
                && showMarker != Indicator.NONE) {
              return Positioned(
                left: sqrt(width) - width * 0.05 * sqrt(2),
                top: width - width * 0.13 * 2,
                child: Container(
                  width: width * 0.27,
                  height: width * 0.27,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.theme.colorScheme.background, width: 1),
                    borderRadius: BorderRadius.circular(30),
                    color: context.theme.colorScheme.tertiaryContainer,
                  ),
                  child: Transform.rotate(
                    angle: showMarker != Indicator.SENT
                        ? pi / 2 : 0,
                    child: Icon(
                      showMarker == Indicator.DELIVERED
                          ? CupertinoIcons.location_north_fill
                          : showMarker == Indicator.READ
                          ? CupertinoIcons.location_north
                          : CupertinoIcons.location_fill,
                      color: context.theme.colorScheme.onTertiaryContainer,
                      size: width * 0.14,
                    ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          });
        }
    );
  }
}

class ReactionIcon extends CustomStateful<ConversationTileController> {
  const ReactionIcon({Key? key, required this.width, required super.parentController});

  final double width;

  @override
  State<StatefulWidget> createState() => _ReactionIconState();
}

class _ReactionIconState extends CustomState<ReactionIcon, void, ConversationTileController> {
  bool unread = false;
  late Message? latestMessage;
  late final StreamSubscription<Query<Chat>> sub;

  @override
  void initState() {
    super.initState();
    tag = "${controller.chat.guid}-pinned";
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    unread = controller.chat.hasUnreadMessage ?? false;
    latestMessage = controller.chat.latestMessageGetter;
    updateObx(() {
      final unreadQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
          .watch();
      sub = unreadQuery.listen((Query<Chat> query) {
        final chat = query.findFirst()!;
        latestMessage = chat.latestMessageGetter;
        if (chat.hasUnreadMessage != unread) {
          setState(() {
            unread = chat.hasUnreadMessage!;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return unread
        && !isNullOrEmpty(latestMessage?.associatedMessageGuid)!
        && !(latestMessage?.isFromMe ?? true) ? Positioned(
      top: -sqrt(widget.width / 2),
      right: -sqrt(widget.width / 2) - widget.width * 0.15,
      child: ReactionsWidget(
        associatedMessages: [latestMessage!],
        bigPin: true,
        size: widget.width * 0.3,
      ),
    ) : const SizedBox.shrink();
  }
}