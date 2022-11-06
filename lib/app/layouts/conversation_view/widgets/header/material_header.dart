import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialHeader extends StatelessWidget implements PreferredSizeWidget {
  const MaterialHeader({Key? key, required this.controller});

  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppBar(
          backgroundColor: context.theme.colorScheme.background
              .withOpacity(ss.settings.skin.value == Skins.Samsung ? 1 : 0.9),
          automaticallyImplyLeading: false,
          leadingWidth: 40,
          leading: Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: BackButton(
              color: context.theme.colorScheme.onBackground,
              onPressed: () {
                if (ls.isBubble) {
                  SystemNavigator.pop();
                  return;
                }
                eventDispatcher.emit("update-highlight", null);
              },
            ),
          ),
          title: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: controller.chat.isGroup ? null : () async {
              final handle = controller.chat.participants.first;
              final contact = handle.contact;
              if (contact == null) {
                await mcs.invokeMethod("open-contact-form",
                    {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
              } else {
                await mcs.invokeMethod("view-contact-form", {'id': contact.id});
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: _ChatIconAndTitle(parentController: controller),
            ),
          ),
          actions: [
            ManualMark(chat: controller.chat),
            if (Platform.isAndroid && !controller.chat.isGroup && controller.chat.participants.first.address.isPhoneNumber)
              IconButton(
                icon: Icon(Icons.call_outlined, color: context.theme.colorScheme.onBackground),
                onPressed: () {
                  launchUrl(Uri(scheme: "tel", path: controller.chat.participants.first.address));
                },
              ),
            if (Platform.isAndroid && !controller.chat.isGroup && controller.chat.participants.first.address.isEmail)
              IconButton(
                icon: Icon(Icons.mail_outlined, color: context.theme.colorScheme.onBackground),
                onPressed: () {
                  launchUrl(Uri(scheme: "mailto", path: controller.chat.participants.first.address));
                },
              ),
            PopupMenuButton<int>(
              color: context.theme.colorScheme.properSurface,
              shape: ss.settings.skin.value != Skins.Material ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(20.0),
                ),
              ) : null,
              onSelected: (int value) {
                if (value == 0) {
                  Navigator.of(context).push(
                    ThemeSwitcher.buildPageRoute(
                      builder: (context) => ConversationDetails(
                        chat: controller.chat,
                      ),
                    ),
                  );
                } else if (value == 1) {
                  controller.chat.toggleArchived(!controller.chat.isArchived!);
                  while (Get.isOverlaysOpen) {
                    Get.back();
                  }
                  Navigator.of(context).pop();
                } else if (value == 2) {
                  chats.removeChat(controller.chat);
                  Chat.deleteChat(controller.chat);
                  while (Get.isOverlaysOpen) {
                    Get.back();
                  }
                  Navigator.of(context).pop();
                }
              },
              itemBuilder: (context) {
                return <PopupMenuItem<int>>[
                  PopupMenuItem(
                    value: 0,
                    child: Text(
                      'Details',
                      style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                    ),
                  ),
                  if (!ls.isBubble)
                    PopupMenuItem(
                      value: 1,
                      child: Text(
                        controller.chat.isArchived! ? 'Unarchive' : 'Archive',
                        style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                      ),
                    ),
                  if (!ls.isBubble)
                    PopupMenuItem(
                      value: 2,
                      child: Text(
                        'Delete',
                        style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                      ),
                    ),
                ];
              },
              icon: Icon(
                Icons.more_vert,
                color: context.theme.colorScheme.onBackground,
              ),
            )
          ]
        ),
        if (ss.settings.showConnectionIndicator.value)
          const ConnectionIndicator(),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kIsDesktop ? 70 : kToolbarHeight);
}

class _ChatIconAndTitle extends CustomStateful<ConversationViewController> {
  const _ChatIconAndTitle({required super.parentController});

  @override
  State<StatefulWidget> createState() => _ChatIconAndTitleState();
}

class _ChatIconAndTitleState extends CustomState<_ChatIconAndTitle, void, ConversationViewController> {
  String title = "Unknown";
  late final StreamSubscription<Query<Chat>> sub;
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
    updateObx(() {
      final titleQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
          .watch();
      sub = titleQuery.listen((Query<Chat> query) {
        final chat = query.findFirst()!;
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
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (samsung)
          Padding(
            padding: const EdgeInsets.only(right: 12.5),
            child: IgnorePointer(
              ignoring: true,
              child: ContactAvatarGroupWidget(
                chat: controller.chat,
                size: !controller.chat.isGroup ? 35 : 40,
              ),
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.theme.textTheme.titleLarge!.apply(color: context.theme.colorScheme.onBackground),
            ),
            if (samsung && (controller.chat.isGroup || (!title.isPhoneNumber && !title.isEmail)))
              Text(
                controller.chat.isGroup
                  ? "${controller.chat.participants.length} recipients"
                  : controller.chat.participants[0].address,
                style: context.theme.textTheme.labelLarge!.apply(color: context.theme.colorScheme.outline),
              ),
          ],
        ),
      ],
    );
  }
}
