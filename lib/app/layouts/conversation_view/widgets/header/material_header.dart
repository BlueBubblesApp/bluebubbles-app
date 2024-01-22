import 'dart:async';

import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialHeader extends StatelessWidget implements PreferredSizeWidget {
  const MaterialHeader({Key? key, required this.controller});

  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    final Rx<Color> _backgroundColor = context.theme.colorScheme.background.withOpacity((kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled) ? 0.4 : ss.settings.skin.value == Skins.Samsung ? 1 : 0.95).obs;

    return Obx(() => AppBar(
      backgroundColor: _backgroundColor.value,
      systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: false,
      toolbarHeight: (kIsDesktop ? 25 : 0) + kToolbarHeight,
      leadingWidth: 40,
      leading: Padding(
        padding: EdgeInsets.only(left: 10.0, top: kIsDesktop ? 20 : 0),
        child: BackButton(
          color: context.theme.colorScheme.onBackground,
          onPressed: () {
            if (controller.inSelectMode.value) {
              controller.inSelectMode.value = false;
              controller.selected.clear();
              return true;
            }
            if (ls.isBubble) {
              SystemNavigator.pop();
              return true;
            }
            controller.close();
            return false;
          },
        ),
      ),
      title: Padding(
        padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: controller.chat.isGroup ? () {
            Navigator.of(context).push(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => ConversationDetails(
                  chat: controller.chat,
                ),
              ),
            );
          } : () async {
            final handle = controller.chat.participants.first;
            final contact = handle.contact;
            if (contact == null) {
              await mcs.invokeMethod("open-contact-form", {'address': handle.address, 'address_type': handle.address.isEmail ? 'email' : 'phone'});
            } else {
              try {
                await mcs.invokeMethod("view-contact-form", {'id': contact.id});
              } catch (_) {
                showSnackbar("Error", "Failed to find contact on device!");
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: _ChatIconAndTitle(parentController: controller),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
          child: ManualMark(controller: controller),
        ),
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
        Padding(
          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
          child: PopupMenuButton<int>(
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
                if (Get.isSnackbarOpen) {
                  Get.closeAllSnackbars();
                }
                Navigator.of(context).pop();
              } else if (value == 2) {
                showDialog(
                  barrierDismissible: false,
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        "Are you sure?",
                        style: context.theme.textTheme.titleLarge,
                      ),
                      content: Text(
                        "This chat will be deleted from this device only",
                        style: context.theme.textTheme.bodyLarge
                      ),
                      backgroundColor: context.theme.colorScheme.properSurface,
                      actions: <Widget>[
                        TextButton(
                          child: Text("No", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                          onPressed: () {
                            if (Get.isSnackbarOpen) {
                              Get.closeAllSnackbars();
                            }
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                          onPressed: () async {
                            chats.removeChat(controller.chat);
                            Chat.softDelete(controller.chat);
                            if (Get.isSnackbarOpen) {
                              Get.closeAllSnackbars();
                            }
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              } else if (value == 3) {
                showBookmarksThread(controller, context);
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
                PopupMenuItem(
                  value: 3,
                  child: Text(
                    'Bookmarks',
                    style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                  ),
                ),
              ];
            },
            icon: Icon(
              Icons.more_vert,
              color: context.theme.colorScheme.onBackground,
            ),
          ),
        )
      ],
    ));
  }

  @override
  Size get preferredSize => Size.fromHeight(kIsDesktop ? 90 : kToolbarHeight);
}

class _ChatIconAndTitle extends CustomStateful<ConversationViewController> {
  const _ChatIconAndTitle({required super.parentController});

  @override
  State<StatefulWidget> createState() => _ChatIconAndTitleState();
}

class _ChatIconAndTitleState extends CustomState<_ChatIconAndTitle, void, ConversationViewController> {
  String title = "Unknown";
  late final StreamSubscription sub;
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
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                String _title = title;
                if (controller.inSelectMode.value) {
                  _title = "${controller.selected.length} selected";
                } else if (hideInfo) {
                  _title = controller.chat.participants.length > 1 ? "Group Chat" : controller.chat.participants[0].fakeName;
                }
                return Text(
                  _title,
                  style: context.theme.textTheme.titleLarge!.apply(color: context.theme.colorScheme.onBackground),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                );
              }),
              if (samsung && (controller.chat.isGroup || (!title.isPhoneNumber && !title.isEmail)) && !hideInfo)
                Text(
                  controller.chat.isGroup
                    ? "${controller.chat.participants.length} recipients"
                    : controller.chat.participants[0].address,
                  style: context.theme.textTheme.labelLarge!.apply(color: context.theme.colorScheme.outline),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
