import 'dart:math';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/message_holder.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

Future<void> peekChat(BuildContext context, Chat c, Offset offset) async {
  HapticFeedback.mediumImpact();
  final messages = Chat.getMessages(c, getDetails: true).where((e) => e.associatedMessageGuid == null).toList();
  await Navigator.push(
    Get.context!,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: ConversationPeekView(position: offset, chat: c, messages: messages),
        );
      },
      fullscreenDialog: true,
      opaque: false,
    ),
  );
}

class ConversationPeekView extends StatefulWidget {
  final Offset position;
  final Chat chat;
  final List<Message> messages;

  const ConversationPeekView({Key? key, required this.position, required this.chat, required this.messages}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ConversationPeekViewState();
}

class _ConversationPeekViewState extends OptimizedState<ConversationPeekView> with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final ConversationViewController cvController = cvc(widget.chat);
  final double itemHeight = kIsDesktop || kIsWeb ? 56 : 48;
  bool disposed = false;

  @override
  void initState() {
    super.initState();
    cm.setActiveChat(widget.chat, clearNotifications: false);
    cm.activeChat!.controller = cvController;
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      animationBehavior: AnimationBehavior.preserve,
    );
    controller.forward();
  }

  void popPeekView() {
    bool dialogOpen = Get.isDialogOpen ?? false;
    if (dialogOpen) {
      if (kIsWeb) {
        Get.back();
      } else {
        Navigator.of(context).pop();
      }
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    if (!disposed) {
      cvController.close();
      ms(widget.chat.guid).close();
      for (Message m in widget.messages) {
        getActiveMwc(m.guid!)?.close();
      }
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Theme(
        data: context.theme.copyWith(
          // in case some components still use legacy theming
          primaryColor: context.theme.colorScheme.bubble(context, widget.chat.isIMessage),
          colorScheme: context.theme.colorScheme.copyWith(
            primary: context.theme.colorScheme.bubble(context, widget.chat.isIMessage),
            onPrimary: context.theme.colorScheme.onBubble(context, widget.chat.isIMessage),
            surface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
            onSurface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
          ),
        ),
        child: TitleBarWrapper(
          child: Container(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      color: context.theme.colorScheme.properSurface.darkenPercent(30).withOpacity(0.2),
                    ),
                  ),
                ),
                Positioned(
                  left: min(widget.position.dx, context.width - min(context.width - 50, 500) - 25),
                  top: min(widget.position.dy, context.height - min(context.height / 2, context.height - itemHeight * 5) - itemHeight * 5 - 25),
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
                              ms(widget.chat.guid).close();
                              for (Message m in widget.messages) {
                                getActiveMwc(m.guid!)?.close();
                              }
                              controller.dispose();
                              disposed = true;
                              Navigator.of(context).pop();
                              ns.pushAndRemoveUntil(
                                Get.context!,
                                ConversationView(
                                  chat: widget.chat,
                                ),
                                (route) => route.isFirst,
                              );
                            },
                            child: DeferredPointerHandler(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: ts.inDarkMode(context) ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                width: min(context.width - 50, 500),
                                height: min(context.height / 2, context.height - itemHeight * 5),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    reverse: true,
                                    physics: ThemeSwitcher.getScrollPhysics(),
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
                                              oldMessageGuid: index == widget.messages.length - 1 ? null : widget.messages[index + 1].guid,
                                              newMessageGuid: index == 0 ? null : widget.messages[index - 1].guid,
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
            ),
          )
        ),
      ),
    );
  }

  Widget buildDetailsMenu(BuildContext context) {
    double maxMenuWidth = min(max(context.width * 3 / 5, 200), context.width * 4 / 5);
    bool ios = ss.settings.skin.value == Skins.iOS;

    List<Widget> allActions = [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            widget.chat.togglePin(!widget.chat.isPinned!);
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              widget.chat.isPinned! ? "Unpin" : "Pin",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              widget.chat.isPinned!
                  ? (ios ? cupertino.CupertinoIcons.pin_slash : Icons.star_outline)
                  : (ios ? cupertino.CupertinoIcons.pin : Icons.star),
              color: context.theme.colorScheme.properOnSurface
            ),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            widget.chat.toggleMute(widget.chat.muteType != "mute");
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              widget.chat.muteType == "mute" ? 'Show Alerts' : 'Hide Alerts',
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              widget.chat.muteType == "mute"
                  ? (ios ? cupertino.CupertinoIcons.bell : Icons.notifications_active)
                  : (ios ? cupertino.CupertinoIcons.bell_slash : Icons.notifications_off),
              color: context.theme.colorScheme.properOnSurface
            ),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            widget.chat.toggleHasUnread(!widget.chat.hasUnreadMessage!, force: true);
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              widget.chat.hasUnreadMessage! ? 'Mark Read' : 'Mark Unread',
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              widget.chat.hasUnreadMessage!
                  ? (ios ? cupertino.CupertinoIcons.person_crop_circle_badge_xmark : Icons.mark_chat_unread)
                  : (ios ? cupertino.CupertinoIcons.person_crop_circle_badge_checkmark : Icons.mark_chat_read),
              color: context.theme.colorScheme.properOnSurface
            ),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            widget.chat.toggleArchived(!widget.chat.isArchived!);
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              widget.chat.isArchived! ? 'Unarchive' : 'Archive',
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              widget.chat.isArchived!
                  ? (ios ? cupertino.CupertinoIcons.tray_arrow_up : Icons.unarchive)
                  : (ios ? cupertino.CupertinoIcons.tray_arrow_down : Icons.archive),
              color: context.theme.colorScheme.properOnSurface
            ),
          ),
        ),
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            chats.removeChat(widget.chat);
            Chat.softDelete(widget.chat);
            popPeekView();
          },
          child: ListTile(
            mouseCursor: MouseCursor.defer,
            dense: !kIsDesktop && !kIsWeb,
            title: Text(
              'Delete',
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.properOnSurface),
            ),
            trailing: Icon(
              cupertino.CupertinoIcons.trash,
              color: context.theme.colorScheme.properOnSurface
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
          color: (ts.inDarkMode(context) ? context.theme.colorScheme.properSurface : context.theme.colorScheme.background).withAlpha(150),
          width: maxMenuWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: allActions
          ),
        ),
      ),
    );
  }
}