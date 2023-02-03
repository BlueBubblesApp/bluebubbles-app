import 'dart:async';
import 'dart:ui';

import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

class CupertinoHeader extends StatelessWidget implements PreferredSizeWidget {
  const CupertinoHeader({Key? key, required this.controller});

  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: context.theme.colorScheme.properSurface.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(color: context.theme.colorScheme.properSurface, width: 1),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
                  padding: EdgeInsets.only(
                    left: 20.0,
                    right: 20,
                    top: (MediaQuery.of(context).viewPadding.top - 2).clamp(0, double.infinity)
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (controller.inSelectMode.value) {
                              controller.inSelectMode.value = false;
                              controller.selected.clear();
                              return;
                            }
                            if (ls.isBubble) {
                              SystemNavigator.pop();
                              return;
                            }
                            controller.close();
                            while (Get.isOverlaysOpen) {
                              Get.back();
                            }
                            Navigator.of(context).pop();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: _UnreadIcon(controller: controller),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              ThemeSwitcher.buildPageRoute(
                                builder: (context) => ConversationDetails(
                                  chat: controller.chat,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: _ChatIconAndTitle(parentController: controller),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ManualMark(controller: controller)
                      ),
                    ]
                  ),
                ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight((Get.context!.orientation == Orientation.landscape && Platform.isAndroid ? 55 : 75) * ss.settings.avatarScale.value);
}

class _UnreadIcon extends StatefulWidget {
  const _UnreadIcon({required this.controller});

  final ConversationViewController controller;

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends OptimizedState<_UnreadIcon> {
  int count = 0;
  late final StreamSubscription<Query<Chat>> sub;
  bool hasStream = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      updateObx(() {
        final unreadQuery = chatBox.query(Chat_.hasUnreadMessage.equals(true)).watch(triggerImmediately: true);
        sub = unreadQuery.listen((Query<Chat> query) {
          final c = query.count();
          if (count != c) {
            setState(() {
              count = c;
            });
          }
        });

        hasStream = true;
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && hasStream) sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3.0, right: 3),
          child: Obx(() {
            final icon = widget.controller.inSelectMode.value ? CupertinoIcons.xmark : CupertinoIcons.back;
            return Text(
              String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                fontSize: 35,
                color: context.theme.colorScheme.primary,
              ),
            );
          }),
        ),
        Obx(() {
          final _count = widget.controller.inSelectMode.value ? widget.controller.selected.length : count;
          if (_count == 0) return const SizedBox.shrink();
          return Container(
            height: 20.0,
            constraints: const BoxConstraints(minWidth: 20),
            decoration: BoxDecoration(
              color: context.theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.only(left: 1),
            child: Padding(
              padding: _count > 99 ? const EdgeInsets.symmetric(horizontal: 2.5) : EdgeInsets.zero,
              child: Text(
                _count.toString(),
                style: context.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.onPrimary, fontSize: _count > 9 ?
                  context.textTheme.bodyMedium!.fontSize! - 1.0 : context.textTheme.bodyMedium!.fontSize),
              ),
            )
          );
        }),
      ],
    );
  }
}

class _ChatIconAndTitle extends CustomStateful<ConversationViewController> {
  const _ChatIconAndTitle({required super.parentController});

  @override
  State<StatefulWidget> createState() => _ChatIconAndTitleState();
}

class _ChatIconAndTitleState extends CustomState<_ChatIconAndTitle, void, ConversationViewController> {
  String title = "Unknown";
  late final StreamSubscription<Query<Chat>> sub;
  bool hasStream = false;
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
        final titleQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
            .watch();
        sub = titleQuery.listen((Query<Chat> query) async {
          final chat = await runAsync(() {
            return chatBox.get(controller.chat.id!)!;
          });
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

        hasStream = true;
      });
    }
  }

  @override
  void dispose() {
    if (hasStream) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
    String _title = title;
    if (hideInfo) {
      _title = controller.chat.participants.length > 1 ? "Group Chat" : controller.chat.participants[0].fakeName;
    }
    final children = [
      IgnorePointer(
        ignoring: true,
        child: ContactAvatarGroupWidget(
          chat: controller.chat,
          size: !controller.chat.isGroup ? 40 : 45,
        ),
      ),
      const SizedBox(height: 5, width: 5),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: ns.width(context) / 2.5,
            ),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              text: TextSpan(
                style: context.theme.textTheme.bodyMedium,
                children: MessageHelper.buildEmojiText(
                  _title,
                  context.theme.textTheme.bodyMedium!,
                ),
              ),
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: context.theme.textTheme.bodyMedium!.fontSize!,
            color: context.theme.colorScheme.outline,
          ),
        ]
      ),
    ];

    if (context.orientation == Orientation.landscape && Platform.isAndroid) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }
  }
}