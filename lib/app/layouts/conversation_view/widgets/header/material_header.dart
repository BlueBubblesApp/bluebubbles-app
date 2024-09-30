import 'package:bluebubbles/app/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
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
    final Rx<Color> _backgroundColor = context.theme.colorScheme.background.withOpacity((kIsDesktop && ss.settings.windowEffect.value != WindowEffect.disabled) ? 0.4 : 1).obs;
    Chat chat = controller.chat;
    return Stack(
          children: [Obx(() => AppBar(
      backgroundColor: _backgroundColor.value,
      systemOverlayStyle: context.theme.colorScheme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      automaticallyImplyLeading: false,
      toolbarHeight: (kIsDesktop ? 25 : 0) + kToolbarHeight,
      leadingWidth: 30,
      leading: Padding(
        padding: EdgeInsets.only(left: 5.0, top: kIsDesktop ? 20 : 0),
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
          onTap: chat.isGroup ? () {
            Navigator.of(context).push(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => ConversationDetails(
                  chatGuid: chat.guid,
                ),
              ),
            );
          } : () async {
            final handle = chat.participants.first;
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
        if (Platform.isAndroid && !chat.isGroup && chat.participants.first.address.isPhoneNumber)
          IconButton(
            icon: Icon(Icons.call_outlined, color: context.theme.colorScheme.onBackground),
            onPressed: () {
              launchUrl(Uri(scheme: "tel", path: chat.participants.first.address));
            },
          ),
        if (Platform.isAndroid && !chat.isGroup && chat.participants.first.address.isEmail)
          IconButton(
            icon: Icon(Icons.mail_outlined, color: context.theme.colorScheme.onBackground),
            onPressed: () {
              launchUrl(Uri(scheme: "mailto", path: chat.participants.first.address));
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
                      chatGuid: chat.guid,
                    ),
                  ),
                );
              } else if (value == 1) {
                chat.toggleIsArchived(null);
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
                            GlobalChatService.removeChat(chat.guid, softDelete: true);
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
                    child: Obx(() => Text(
                      chat.observables.isArchived.value ? 'Unarchive' : 'Archive',
                      style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                    )),
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
    )),
      Positioned(
        child: Obx(() {
          final sendProgress = controller.chat.observables.sendProgress.value;
          return TweenAnimationBuilder<double>(
            duration: sendProgress == 0 ? Duration.zero : sendProgress == 1 ? const Duration(milliseconds: 250) : const Duration(seconds: 10),
            curve: sendProgress == 1 ? Curves.easeInOut : Curves.easeOutExpo,
            tween: Tween<double>(
                begin: 0,
                end: sendProgress,
            ),
            builder: (context, value, _) =>
                AnimatedOpacity(
                  opacity: value == 1 ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.transparent,
                    minHeight: 3,
                  ),
                )
          );
        }),
        bottom: 0,
        left: 0,
        right: 0,
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
    tag = controller.chatGuid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    final hideInfo = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
    final chat = controller.chat;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 12.5),
          child: IgnorePointer(
            ignoring: true,
            child: ContactAvatarGroupWidget(
              chatGuid: chat.guid,
              size: !chat.isGroup ? 35 : 40,
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            String title = chat.observables.title.value ?? "";
            if (controller.inSelectMode.value) {
              title = "${controller.selected.length} selected";
            } else if (hideInfo) {
              title = chat.participants.length > 1 ? "Group Chat" : chat.participants[0].fakeName;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.theme.textTheme.titleLarge!.apply(color: context.theme.colorScheme.onBackground, fontSizeFactor: 0.85),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                ),
                if (samsung && (chat.isGroup || (!title.isPhoneNumber && !title.isEmail)) && !hideInfo)
                  Text(
                    chat.isGroup
                      ? "${chat.participants.length} recipients"
                      : chat.participants[0].address,
                    style: context.theme.textTheme.labelLarge!.apply(color: context.theme.colorScheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}
