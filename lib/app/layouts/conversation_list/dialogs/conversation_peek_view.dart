import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/mixins/messages_service_mixin.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/services/backend/interfaces/custom_group_interface.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

final GlobalKey<NavigatorState> _peekNavigator = GlobalKey<NavigatorState>();

/// Closes the open peek, if any: a hold that turned into a drag.
void closeChatPeek() => _peekNavigator.currentState?.maybePop();

/// Shows [ConversationPeekView] over everything.
///
/// It lives in its own navigator in an overlay entry rather than as a route on the app's navigator, because pushing a
/// route cancels every pointer that navigator is tracking: the finger still holding the chat would lose its drag. The
/// view's own pops land on that navigator, so they still just close the peek.
Future<void> peekChat(BuildContext context, Chat c, Offset offset) async {
  // Not in tablet mode, where the chat opens beside the list anyway, as on desktop.
  if (_peekNavigator.currentState != null || NavigationSvc.isTabletMode(context)) return;
  HapticFeedback.mediumImpact();
  final messages = Chat.getMessages(c, getDetails: true).where((e) => !e.isReaction).toList();
  final peek = PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: animation,
        child: ConversationPeekView(
          position: offset,
          chat: c,
          messages: messages,
        ),
      );
    },
    fullscreenDialog: true,
    opaque: false,
  );
  // Something for the peek to pop back to; a navigator can't pop its last route.
  final base = PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
    opaque: false,
    transitionDuration: Duration.zero,
  );
  final overlay = Overlay.of(Get.context!, rootOverlay: true);
  // An overlay entry only inherits what's above the root overlay, so bring the caller's themes along, as dialogs do.
  final themes = InheritedTheme.capture(from: context, to: overlay.context);
  final entry = OverlayEntry(
    builder: (context) => themes.wrap(Navigator(
      key: _peekNavigator,
      onGenerateInitialRoutes: (navigator, initialRoute) => [base, peek],
    )),
  );
  overlay.insert(entry);

  // Back goes to the app's navigator, which knows nothing of the peek. Once the finger is up (pushing earlier would
  // cancel it), an empty route there takes the back press and closes the peek.
  Route<void>? backGuard;
  var listening = true;
  late final void Function(PointerEvent) onPointer;
  void stopListening() {
    if (!listening) return;
    listening = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(onPointer);
  }

  // Fingers that touched down after the peek opened; only the one holding the chat ends the hold.
  final laterPointers = <int>{};
  onPointer = (PointerEvent event) {
    if (event is PointerDownEvent) laterPointers.add(event.pointer);
    if (event is! PointerUpEvent && event is! PointerCancelEvent) return;
    if (laterPointers.remove(event.pointer)) return;
    stopListening();
    if (_peekNavigator.currentState == null) return;
    backGuard = PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      opaque: false,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
    Navigator.of(Get.context!, rootNavigator: true).push(backGuard!).then((_) => closeChatPeek());
  };

  GestureBinding.instance.pointerRouter.addGlobalRoute(onPointer);
  try {
    await peek.completed;
  } finally {
    // Whatever happens, the entry goes: left behind, its empty route would swallow every touch.
    stopListening();
    entry.remove();
    final guard = backGuard;
    if (guard != null && guard.isActive) guard.navigator!.removeRoute(guard);
  }
}

class ConversationPeekView extends StatefulWidget {
  final Offset position;
  final Chat chat;
  final List<Message> messages;

  const ConversationPeekView({super.key, required this.position, required this.chat, required this.messages});

  @override
  State<StatefulWidget> createState() => _ConversationPeekViewState();
}

class _ConversationPeekViewState extends State<ConversationPeekView>
    with SingleTickerProviderStateMixin, MessagesServiceMixin, ThemeHelpers {
  late final AnimationController controller;
  late final ConversationViewController cvController = cvc(widget.chat);
  final double itemHeight = kIsDesktop || kIsWeb ? 56 : 48;
  bool disposed = false;

  @override
  void initState() {
    super.initState();

    // Initialize messages service with message states for proper reactivity
    initializeMessagesService(
      widget.chat,
      widget.messages,
      cvController,
    );

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      animationBehavior: AnimationBehavior.preserve,
    );
    controller.forward();
  }

  void popPeekView() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (!disposed) {
      cvController.close();
      disposeMessagesService();
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: context.theme.copyWith(
        // in case some components still use legacy theming
        primaryColor: context.theme.colorScheme.bubble(context, widget.chat.isIMessage),
        colorScheme: context.theme.colorScheme.copyWith(
          primary: context.theme.colorScheme.bubble(context, widget.chat.isIMessage),
          onPrimary: context.theme.colorScheme.onBubble(context, widget.chat.isIMessage),
          surface: ThemeSvc.isMaterialYouActive(context)
              ? null
              : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
          onSurface: ThemeSvc.isMaterialYouActive(context)
              ? null
              : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
        ),
      ),
      child: BBScaffold(
        backgroundColor: Colors.transparent,
        safeAreaTop: false,
        safeAreaLeft: false,
        safeAreaRight: false,
        body: TitleBarWrapper(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final availableHeight = constraints.maxHeight;
              final previewWidth = min(max(availableWidth - 50, 0.0), 500.0);
              final menuItemCount = 5 + (CustomGroupsSvc.groups.isNotEmpty ? 1 : 0);
              final menuHeight = itemHeight * menuItemCount + 5;
              final previewHeight = min(
                  max(min(availableHeight / 2, availableHeight - menuHeight - 25), itemHeight * 2), availableHeight);
              final maxLeft = max(availableWidth - previewWidth - 25, 0.0);
              final maxTop = max(availableHeight - previewHeight - menuHeight - 25, 0.0);

              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        color:
                            context.theme.colorScheme.surfaceContainerHighest.darkenPercent(30).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  Positioned(
                    left: min(widget.position.dx, maxLeft),
                    top: min(widget.position.dy, maxTop),
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
                            GestureDetector(
                              onTap: () async {
                                cvController.close();
                                MessagesSvc(widget.chat.guid).close();
                                // Controllers are disposed by MessagesService.onClose()
                                controller.dispose();
                                disposed = true;
                                Navigator.of(context).pop();
                                NavigationSvc.pushAndRemoveUntil(
                                  Get.context!,
                                  ConversationView(
                                    chat: widget.chat,
                                  ),
                                  (route) => route.isFirst,
                                );
                              },
                              child: ChatStateScope(
                                chatState: ChatsSvc.getOrCreateChatState(widget.chat),
                                child: DeferredPointerHandler(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: ThemeSvc.inDarkMode(context)
                                          ? context.theme.colorScheme.surfaceContainerHighest.darkenPercent(30)
                                          : context.theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    width: previewWidth,
                                    height: previewHeight,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        reverse: true,
                                        physics: ThemeSwitcher.getScrollPhysics(),
                                        findChildIndexCallback: (key) =>
                                            findChildIndexByKey(widget.messages, key, (item) => item.guid),
                                        itemBuilder: (context, index) {
                                          return AbsorbPointer(
                                            absorbing: true,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 5.0, right: 5.0),
                                                child: MessageHolder(
                                                  key: Key(widget.messages[index].guid!),
                                                  cvController: cvController,
                                                  message: widget.messages[index],
                                                  oldMessage: index == widget.messages.length - 1
                                                      ? null
                                                      : widget.messages[index + 1],
                                                  newMessage: index == 0 ? null : widget.messages[index - 1],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        itemCount: widget.messages.length,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget buildDetailsMenu(BuildContext context) {
    double maxMenuWidth = min(max(context.width * 3 / 5, 200), context.width * 4 / 5);
    bool ios = SettingsSvc.settings.skin.value == Skins.iOS;

    List<Widget> allActions = [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final chatState = ChatsSvc.getChatState(widget.chat.guid);
            await ChatsSvc.setChatPinned(chatState?.chat ?? widget.chat, !widget.chat.isPinned!);
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              widget.chat.isPinned! ? "Unpin" : "Pin",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(
                widget.chat.isPinned!
                    ? (ios ? cupertino.CupertinoIcons.pin_slash : Icons.star_outline)
                    : (ios ? cupertino.CupertinoIcons.pin : Icons.star),
                color: context.theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final chatState = ChatsSvc.getChatState(widget.chat.guid);
            if (chatState != null) {
              await ChatsSvc.setChatMuted(chatState.chat, widget.chat.muteType != "mute");
            } else {
              await widget.chat.toggleMuteAsync(widget.chat.muteType != "mute");
            }
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              widget.chat.muteType == "mute" ? 'Show Alerts' : 'Hide Alerts',
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(
                widget.chat.muteType == "mute"
                    ? (ios ? cupertino.CupertinoIcons.bell : Icons.notifications_active)
                    : (ios ? cupertino.CupertinoIcons.bell_slash : Icons.notifications_off),
                color: context.theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final chatState = ChatsSvc.getChatState(widget.chat.guid);
            if (chatState != null) {
              await ChatsSvc.setChatHasUnread(chatState.chat, !widget.chat.hasUnreadMessage!, force: true);
            } else {
              await widget.chat.toggleHasUnreadAsync(!widget.chat.hasUnreadMessage!, force: true);
            }
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              widget.chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(
                widget.chat.hasUnreadMessage!
                    ? (ios ? cupertino.CupertinoIcons.person_crop_circle_badge_xmark : Icons.mark_chat_unread)
                    : (ios ? cupertino.CupertinoIcons.person_crop_circle_badge_checkmark : Icons.mark_chat_read),
                color: context.theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final chatState = ChatsSvc.getChatState(widget.chat.guid);
            await ChatsSvc.setChatArchived(chatState?.chat ?? widget.chat, !widget.chat.isArchived!);
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              widget.chat.isArchived! ? 'Unarchive' : 'Archive',
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(
                widget.chat.isArchived!
                    ? (ios ? cupertino.CupertinoIcons.tray_arrow_up : Icons.unarchive)
                    : (ios ? cupertino.CupertinoIcons.tray_arrow_down : Icons.archive),
                color: context.theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      if (CustomGroupsSvc.groups.isNotEmpty)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              // The peek sits above the app's routes, so it closes before the dialog opens on them.
              final chat = widget.chat;
              popPeekView();
              final group = await showBBListSelector<CustomGroup>(
                context: Get.context!,
                title: "Add to Custom Group",
                options: CustomGroupsSvc.groups
                    .map((g) => BBListSelectorOption(label: g.name, value: g))
                    .toList(),
              );
              if (group != null) {
                final chatGuids = group.chats.map((c) => c.guid).toSet();
                chatGuids.add(chat.guid);
                await CustomGroupInterface.updateChats(id: group.id!, chatGuids: chatGuids.toList());
              }
            },
            child: ListTile(
              mouseCursor: MouseCursor.defer,
              dense: !kIsDesktop && !kIsWeb,
              title: Text(
                'Add to Custom Group',
                style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
              ),
              trailing: Icon(
                  ios ? cupertino.CupertinoIcons.folder_badge_plus : Icons.playlist_add,
                  color: context.theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // The peek sits above the app's routes, so it closes before the dialog opens on them.
            final chat = widget.chat;
            final appContext = Get.context!;
            popPeekView();
            await showBBDialog(
              barrierDismissible: false,
              context: appContext,
              title: "Are you sure?",
              body: "This chat will be deleted from this device only",
              actions: [
                BBDialogAction(
                  text: "No",
                  onPressed: () => Navigator.of(appContext, rootNavigator: true).pop(),
                ),
                BBDialogAction(
                  text: "Yes",
                  isDefault: true,
                  onPressed: () {
                    ChatsSvc.removeChat(chat);
                    ChatsSvc.softDeleteChat(chat);
                    Navigator.of(appContext, rootNavigator: true).pop();
                  },
                ),
              ],
            );
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              'Delete',
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(cupertino.CupertinoIcons.trash, color: context.theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          color: (ThemeSvc.inDarkMode(context)
                  ? context.theme.colorScheme.surfaceContainerHighest
                  : context.theme.colorScheme.surface)
              .withAlpha(150),
          width: maxMenuWidth,
          child:
              Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: allActions),
        ),
      ),
    );
  }
}
