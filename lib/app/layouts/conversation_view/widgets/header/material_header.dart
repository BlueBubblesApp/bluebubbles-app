import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart' hide BackButton;
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialHeader extends StatelessWidget implements PreferredSizeWidget {
  const MaterialHeader({super.key, required this.controller});

  final ConversationViewController controller;

  @override
  Widget build(BuildContext context) {
    final Rx<Color> _backgroundColor = context.theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: (kIsDesktop && SettingsSvc.settings.windowEffect.value != WindowEffect.disabled) ? 0.4 : 1)
        .obs;
    final Color _foregroundColor = context.theme.colorScheme.onSurfaceVariant;

    return Stack(children: [
      Obx(() => AppBar(
            backgroundColor: _backgroundColor.value,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            systemOverlayStyle: context.systemUiOverlayStyle(
              statusBarColor: _backgroundColor.value,
              backgroundBrightness: ThemeData.estimateBrightnessForColor(_backgroundColor.value),
            ),
            automaticallyImplyLeading: false,
            toolbarHeight: (kIsDesktop ? 25 : 0) + kToolbarHeight,
            leadingWidth: 30,
            leading: Padding(
              padding: EdgeInsets.only(left: 5.0, top: kIsDesktop ? 20 : 0),
              child: BackButton(
                color: _foregroundColor,
                onPressed: () {
                  if (controller.inSelectMode.value) {
                    controller.inSelectMode.value = false;
                    controller.selected.clear();
                    return true;
                  }
                  if (LifecycleSvc.isBubble) {
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
                onTap: controller.chat.isGroup
                    ? () {
                        Navigator.of(context).push(
                          ThemeSwitcher.buildPageRoute(
                            builder: (context) => ConversationDetails(
                              chat: controller.chat,
                            ),
                          ),
                        );
                      }
                    : () async {
                        final handle = controller.chat.handles.first;
                        final contact = handle.contactsV2.firstOrNull;
                        if (contact == null || !contact.isNative) {
                          await MethodChannelSvc.actions.openContactForm(
                            address: handle.address,
                            isEmail: handle.address.isEmail,
                          );
                        } else {
                          try {
                            await MethodChannelSvc.actions.viewContactForm(nativeContactId: contact.nativeContactId);
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
              if (Platform.isAndroid && !controller.chat.isGroup && controller.chat.handles.first.address.isPhoneNumber)
                IconButton(
                  icon: Icon(Icons.call_outlined, color: _foregroundColor),
                  onPressed: () {
                    launchUrl(Uri(scheme: "tel", path: controller.chat.handles.first.address));
                  },
                ),
              if (Platform.isAndroid && !controller.chat.isGroup && controller.chat.handles.first.address.isEmail)
                IconButton(
                  icon: Icon(Icons.mail_outlined, color: _foregroundColor),
                  onPressed: () {
                    launchUrl(Uri(scheme: "mailto", path: controller.chat.handles.first.address));
                  },
                ),
              Padding(
                padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
                child: PopupMenuButton<int>(
                  color: context.theme.colorScheme.surfaceContainerHighest,
                  shape: SettingsSvc.settings.skin.value != Skins.Material
                      ? const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(20.0),
                          ),
                        )
                      : null,
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
                      ChatsSvc.setChatArchived(controller.chat, !controller.chat.isArchived!);
                      if (Get.isSnackbarOpen) {
                        Get.closeAllSnackbars();
                      }
                      Navigator.of(context).pop();
                    } else if (value == 2) {
                      showBBDialog(
                        barrierDismissible: false,
                        context: context,
                        title: "Are you sure?",
                        body: "This chat will be deleted from this device only",
                        actions: <BBDialogAction>[
                          BBDialogAction(
                            text: "No",
                            onPressed: () {
                              if (Get.isSnackbarOpen) {
                                Get.closeAllSnackbars();
                              }
                              Navigator.of(context, rootNavigator: true).pop();
                            },
                          ),
                          BBDialogAction(
                            text: "Yes",
                            isDestructive: true,
                            onPressed: () async {
                              ChatsSvc.removeChat(controller.chat);
                              ChatsSvc.softDeleteChat(controller.chat);
                              if (Get.isSnackbarOpen) {
                                Get.closeAllSnackbars();
                              }
                              Navigator.of(context, rootNavigator: true).pop();
                            },
                          ),
                        ],
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
                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      if (!LifecycleSvc.isBubble)
                        PopupMenuItem(
                          value: 1,
                          child: Text(
                            controller.chat.isArchived! ? 'Unarchive' : 'Archive',
                            style:
                                context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      if (!LifecycleSvc.isBubble)
                        PopupMenuItem(
                          value: 2,
                          child: Text(
                            'Delete',
                            style:
                                context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      PopupMenuItem(
                        value: 3,
                        child: Text(
                          'Bookmarks',
                          style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ];
                  },
                  icon: Icon(
                    Icons.more_vert,
                    color: _foregroundColor,
                  ),
                ),
              )
            ],
          )),
      const Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: HeaderProgressIndicator(),
      ),
    ]);
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
    final chatState = ChatStateScope.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12.5),
          child: IgnorePointer(
            ignoring: true,
            child: ContactAvatarGroupWidget(
              size: !controller.chat.isGroup ? 35 : 40,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                // Get title from ChatState - it handles all title logic including redacted mode
                final _title = controller.inSelectMode.value
                    ? "${controller.selected.length} selected"
                    : chatState.title.value ?? controller.chat.getTitle();
                return Text(
                  _title,
                  style: context.theme.textTheme.titleLarge!
                      .apply(color: context.theme.colorScheme.onSurfaceVariant, fontSizeFactor: 0.85),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                );
              }),
              if (samsung &&
                  (controller.chat.isGroup ||
                      (!controller.chat.getTitle().isPhoneNumber && !controller.chat.getTitle().isEmail)))
                Text(
                  controller.chat.isGroup
                      ? "${controller.chat.handles.length} recipients"
                      : controller.chat.handles[0].address,
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
