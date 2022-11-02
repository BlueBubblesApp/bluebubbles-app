import 'dart:math';

import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/ui/ui_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/media_gallery_card.dart';
import 'package:bluebubbles/app/layouts/conversation_details/contact_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/new_chat_creator/contact_selector_option.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/layouts/settings/pages/theming/avatar/avatar_crop.dart';
import 'package:bluebubbles/app/widgets/avatars/contact_avatar_group_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:slugify/slugify.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;

  ConversationDetails({Key? key, required this.chat}) : super(key: key);

  @override
  State<ConversationDetails> createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends OptimizedState<ConversationDetails> with WidgetsBindingObserver, ThemeHelpers {
  static const maxPageSize = 5;
  late final TextEditingController controller = TextEditingController(text: chat.isGroup ? chat.displayName : chat.getTitle());

  List<Attachment> attachmentsForChat = <Attachment>[];
  bool showMoreParticipants = false;

  Chat get chat => widget.chat;
  bool get shouldShowMore => chat.participants.length > maxPageSize;
  List<Handle> get clippedParticipants => showMoreParticipants || chat.participants.length < maxPageSize
      ? chat.participants
      : chat.participants.sublist(0, maxPageSize);

  @override
  void initState() {
    super.initState();
    updateObx(() {
      fetchAttachments();
    });
  }

  void fetchAttachments() {
    if (kIsWeb) return;
    chat.getAttachmentsAsync().then((value) {
      final attachments = value.sublist(0, min(25, value.length));
      for (Attachment a in attachments) {
        a.message.target?.handle = chat.participants.firstWhereOrNull((e) => e.id == a.message.target?.handleId);
      }
      setState(() {
        attachmentsForChat = value.sublist(0, min(25, value.length));
      });
    });
  }

  void showChangeName(String method) {
    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: context.theme.colorScheme.properSurface,
            actions: [
              TextButton(
                child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () async {
                  if (method == "private-api") {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: context.theme.colorScheme.properSurface,
                            title: Text(
                              controller.text.isEmpty ? "Removing name..." : "Changing name to ${controller.text}...",
                              style: context.theme.textTheme.titleLarge,
                            ),
                            content: Container(
                              height: 70,
                              child: Center(
                                child: CircularProgressIndicator(
                                  backgroundColor: context.theme.colorScheme.properSurface,
                                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                ),
                              ),
                            ),
                          );
                        });
                    final response = await http.updateChat(chat.guid, controller.text);
                    if (response.statusCode == 200) {
                      Get.back();
                      Get.back();
                      showSnackbar("Notice", "Updated name successfully!");
                    } else {
                      Get.back();
                      showSnackbar("Error", "Failed to update name!");
                    }
                  } else {
                    Get.back();
                    widget.chat.changeName(controller.text);
                  }
                },
              ),
              TextButton(
                child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                onPressed: () => Get.back(),
              )
            ],
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: "Chat Name",
                border: OutlineInputBorder(),
              ),
            ),
            title: Text("Change Name", style: context.theme.textTheme.titleLarge),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final bool redactedMode = ss.settings.redactedMode.value;
    final bool hideInfo = redactedMode && ss.settings.hideContactInfo.value;
    final bool generateName = redactedMode && ss.settings.generateFakeContactNames.value;
    if (generateName) controller.text = "Group Chat";
    final Rx<Color> _backgroundColor = (ss.settings.windowEffect.value == WindowEffect.disabled
            ? context.theme.colorScheme.background
            : Colors.transparent)
        .obs;

    if (kIsDesktop) {
      ss.settings.windowEffect.listen((WindowEffect effect) {
        if (mounted) {
          _backgroundColor.value =
              effect != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background;
        }
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Theme(
        data: context.theme.copyWith(
          // in case some components still use legacy theming
          primaryColor: context.theme.colorScheme.bubble(context, chat.isIMessage),
          colorScheme: context.theme.colorScheme.copyWith(
            primary: context.theme.colorScheme.bubble(context, chat.isIMessage),
            onPrimary: context.theme.colorScheme.onBubble(context, chat.isIMessage),
            surface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
            onSurface: ss.settings.monetTheming.value == Monet.full
                ? null
                : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
          ),
        ),
        child: Obx(() => SettingsScaffold(
          headerColor: _backgroundColor.value,
          title: "Details",
          tileColor: tileColor,
          initialHeader: null,
          iosSubtitle: iosSubtitle,
          materialSubtitle: materialSubtitle,
          bodySlivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 10),
                Center(
                  child: ContactAvatarGroupWidget(
                    chat: chat,
                    size: 100,
                    onTap: chat.isGroup ? () {} : null,
                  ),
                ),
                if (!hideInfo)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Center(
                      child: Text(
                        controller.text,
                        style: context.theme.textTheme.headlineMedium!
                            .copyWith(fontWeight: FontWeight.bold, color: context.theme.colorScheme.onBackground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (chat.isGroup)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          child: Text(
                            "${(chat.displayName?.isNotEmpty ?? false) ? "Change" : "Add"} Name",
                            style: context.theme.textTheme.bodyMedium!.apply(color: context.theme.primaryColor),
                            textScaleFactor: 1.15,
                          ),
                          onPressed: () {
                            if (!ss.settings.enablePrivateAPI.value || !chat.isIMessage) {
                              showChangeName("local");
                            } else {
                              showChangeName("private-api");
                            }
                          },
                          onLongPress: () {
                            showChangeName("local");
                          },
                        ),
                        Container(
                          child: IconButton(
                            icon: Icon(
                              ss.settings.skin.value == Skins.iOS
                                  ? CupertinoIcons.info
                                  : Icons.info_outline,
                              size: 15,
                              color: context.theme.colorScheme.primary,
                            ),
                            padding: EdgeInsets.zero,
                            iconSize: 15,
                            constraints: const BoxConstraints(maxWidth: 20, maxHeight: 20),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: context.theme.colorScheme.properSurface,
                                    title: Text("Group Naming Info", style: context.theme.textTheme.titleLarge),
                                    content: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!ss.settings.enablePrivateAPI.value || !chat.isIMessage)
                                          Text(
                                            "${!chat.isIMessage ? "This chat is SMS" : "You have Private API disabled"}, so changing the name here will only change it locally for you. You will not see these changes on other devices, and the other members of this chat will not see these changes.",
                                            style: context.theme.textTheme.bodyLarge
                                          ),
                                        if (ss.settings.enablePrivateAPI.value && chat.isIMessage)
                                          Text(
                                            "You have Private API enabled, so changing the name here will change the name for everyone in this chat. If you only want to change it locally, you can tap and hold the \"Change Name\" button.",
                                            style: context.theme.textTheme.bodyLarge
                                          ),
                                      ],
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text("Close", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        }
                                      ),
                                    ]
                                  );
                                },
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                if (!chat.isGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0, right: 10, top: 20),
                    child: Row(
                      mainAxisAlignment: kIsWeb || kIsDesktop ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                      children: [
                        if (!kIsWeb && !kIsDesktop)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                final contact = chat.participants.first.contact;
                                onPressContact(contact, chat.participants.first);
                              },
                              onLongPress: () {
                                final contact = chat.participants.first.contact;
                                onPressContact(contact, chat.participants.first, isLongPressed: true);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: context.theme.colorScheme.properSurface,
                                ),
                                height: 60,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                        ss.settings.skin.value == Skins.iOS
                                            ? CupertinoIcons.phone
                                            : Icons.call,
                                        color: context.theme.colorScheme.primary,
                                        size: 20),
                                    const SizedBox(height: 7.5),
                                    Text("Call", style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.primary)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (!kIsWeb && !kIsDesktop)
                          const SizedBox(width: 5),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              final contact = chat.participants.first.contact;
                              onPressContact(contact, chat.participants.first, isEmail: true);
                            },
                            onLongPress: () {
                              final contact = chat.participants.first.contact;
                              onPressContact(contact, chat.participants.first, isEmail: true, isLongPressed: true);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: context.theme.colorScheme.properSurface,
                              ),
                              height: 60,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      ss.settings.skin.value == Skins.iOS ? CupertinoIcons.mail : Icons.email,
                                      color: context.theme.colorScheme.primary,
                                      size: 20),
                                  const SizedBox(height: 7.5),
                                  Text("Mail", style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.primary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!kIsWeb && !kIsDesktop)
                          const SizedBox(width: 5),
                        if (!kIsWeb && !kIsDesktop)
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final contact = chat.participants.first.contact;
                                final handle = chat.participants.first;
                                if (contact == null) {
                                  await mcs.invokeMethod("open-contact-form",
                                      {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
                                } else {
                                  await mcs.invokeMethod("view-contact-form", {'id': contact.id});
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  color: context.theme.colorScheme.properSurface,
                                ),
                                height: 60,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      ss.settings.skin.value == Skins.iOS ? CupertinoIcons.info : Icons.info,
                                      color: context.theme.colorScheme.primary,
                                      size: 20
                                    ),
                                    const SizedBox(height: 7.5),
                                    Text("Info", style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.primary)),
                                  ],
                                ),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                if (chat.isGroup)
                  Padding(
                    padding: const EdgeInsets.only(left: 15.0, bottom: 5.0),
                    child: Text(
                      "${chat.participants.length} MEMBERS",
                      style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)
                    ),
                  ),
              ]),
            ),
            if (chat.isGroup)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= clippedParticipants.length && shouldShowMore) {
                    return ListTile(
                      onTap: () {
                        setState(() {
                          showMoreParticipants = !showMoreParticipants;
                        });
                      },
                      title: Text(
                        showMoreParticipants ? "Show less" : "Show more",
                        style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
                      ),
                      leading: Container(
                        width: 40 * ss.settings.avatarScale.value,
                        height: 40 * ss.settings.avatarScale.value,
                        decoration: BoxDecoration(
                          color: context.theme.colorScheme.properSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.more_horiz,
                          color: context.theme.colorScheme.primary,
                          size: 20
                        ),
                      ),
                    );
                  }

                  if (index >= chat.participants.length) return const SizedBox.shrink();

                  return ContactTile(
                    key: Key(chat.participants[index].address),
                    handle: chat.participants[index],
                    chat: chat,
                    updateChat: (Chat newChat) {
                      //todo chat = newChat;
                      setState(() {});
                    },
                    canBeRemoved: chat.participants.length > 1
                        && ss.settings.enablePrivateAPI.value
                        && chat.isIMessage,
                  );
                }, childCount: clippedParticipants.length + 1),
              ),
            if (ss.settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup)
              SliverToBoxAdapter(
                child: ListTile(
                  title: Text("Add Member", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                  leading: Container(
                    width: 40 * ss.settings.avatarScale.value,
                    height: 40 * ss.settings.avatarScale.value,
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.properSurface, // border color
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        Icons.add,
                        color: context.theme.colorScheme.primary,
                        size: 20),
                  ),
                  onTap: () {
                    final TextEditingController participantController = TextEditingController();
                    showDialog(
                        context: context,
                        builder: (_) {
                          return AlertDialog(
                            actions: [
                              TextButton(
                                child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                onPressed: () => Get.back(),
                              ),
                              TextButton(
                                child: Text("Pick Contact", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                onPressed: () async {
                                  /*final contacts = [];
                                  final cache = [];
                                  String slugText(String text) {
                                    return slugify(text, delimiter: '').toString().replaceAll('-', '');
                                  }

                                  for (Contact contact in cs.contacts) {
                                    for (String phone in contact.phones) {
                                      String cleansed = slugText(phone);

                                      if (!cache.contains(cleansed)) {
                                        cache.add(cleansed);
                                        contacts.add(
                                          UniqueContact(
                                            address: phone,
                                            displayName: contact.displayName,
                                          ),
                                        );
                                      }
                                    }

                                    for (String email in contact.emails) {
                                      String emailVal = slugText.call(email);

                                      if (!cache.contains(emailVal)) {
                                        cache.add(emailVal);
                                        contacts.add(
                                          UniqueContact(
                                            address: email,
                                            displayName: contact.displayName,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                  UniqueContact? selected;
                                  await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text("Pick Contact", style: context.theme.textTheme.titleLarge),
                                        backgroundColor: context.theme.colorScheme.properSurface,
                                        content: SingleChildScrollView(
                                          child: Container(
                                            width: double.maxFinite,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Text("Select the contact you would like to add"),
                                                ),
                                                ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight: context.mediaQuery.size.height * 0.4,
                                                  ),
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount: contacts.length,
                                                    itemBuilder: (context, index) {
                                                      return ContactSelectorOption(
                                                        key: Key("selector-${contacts[index].displayName}"),
                                                        item: contacts[index],
                                                        onSelected: (contact) {
                                                          Get.back();
                                                          selected = contact;
                                                        },
                                                        index: index,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                  );
                                  if (selected?.address != null) {
                                    if (!selected!.address!.isEmail) {
                                      participantController.text = selected!.address!.numericOnly();
                                    } else {
                                      participantController.text = selected!.address!;
                                    }
                                  }*/
                                },
                              ),
                              TextButton(
                                child: Text("OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                onPressed: () async {
                                  if (participantController.text.isEmpty ||
                                      (!participantController.text.isEmail &&
                                          !participantController.text.isPhoneNumber)) {
                                    showSnackbar("Error", "Enter a valid address!");
                                    return;
                                  }
                                  showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          backgroundColor: context.theme.colorScheme.properSurface,
                                          title: Text(
                                            "Adding ${participantController.text}...",
                                            style: context.theme.textTheme.titleLarge,
                                          ),
                                          content: Container(
                                            height: 70,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                backgroundColor: context.theme.colorScheme.properSurface,
                                                valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                  final response =
                                  await http.chatParticipant("add", chat.guid, participantController.text);
                                  if (response.statusCode == 200) {
                                    Get.back();
                                    Get.back();
                                    showSnackbar(
                                        "Notice", "Added ${participantController.text} successfully!");
                                  } else {
                                    Get.back();
                                    showSnackbar("Error", "Failed to add ${participantController.text}!");
                                  }
                                },
                              ),
                            ],
                            content: TextField(
                              controller: participantController,
                              decoration: InputDecoration(
                                labelText: "Phone Number / Email",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            title: Text("Add Participant", style: context.theme.textTheme.titleLarge),
                            backgroundColor: context.theme.colorScheme.properSurface,
                          );
                        });
                  },
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 10),
            ),
            SliverToBoxAdapter(
              child: SettingsSection(
                backgroundColor: tileColor,
                children: [
                  if (!kIsWeb)
                    SettingsTile(
                      title: "Change Chat Avatar",
                      trailing: Padding(
                        padding: const EdgeInsets.only(right: 15.0),
                        child: Icon(
                          ss.settings.skin.value == Skins.iOS ? CupertinoIcons.person : Icons.person_outlined,
                        ),
                      ),
                      onTap: () {
                        if (chat.customAvatarPath != null) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  title: Text("Custom Avatar",
                                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color)),
                                  content: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          "You have already set a custom avatar for this chat. What would you like to do?",
                                          style: Theme.of(context).textTheme.bodyMedium),
                                    ],
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                        child: Text("Cancel",
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge!
                                                .apply(color: Theme.of(context).primaryColor)),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        }),
                                    TextButton(
                                        child: Text("Reset",
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge!
                                                .apply(color: Theme.of(context).primaryColor)),
                                        onPressed: () {
                                          File file = File(chat.customAvatarPath!);
                                          file.delete();
                                          chat.customAvatarPath = null;
                                          chat.save(updateCustomAvatarPath: true);
                                          Get.back();
                                        }),
                                    TextButton(
                                        child: Text("Set New",
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelLarge!
                                                .apply(color: Theme.of(context).primaryColor)),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          Get.to(() => AvatarCrop(chat: chat));
                                        }),
                                  ]);
                            },
                          );
                        } else {
                          Get.to(() => AvatarCrop(chat: chat));
                        }
                      },
                    ),
                  SettingsTile(
                    title: "Fetch 100 More Messages",
                    subtitle: "Fetches 100 messages after the last message stored locally",
                    isThreeLine: true,
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: Icon(
                        ss.settings.skin.value == Skins.iOS
                            ? CupertinoIcons.cloud_download
                            : Icons.file_download,
                      ),
                    ),
                    onTap: () async {
                      await showDialog(
                        context: context,
                        builder: (context) => SyncDialog(
                            chat: chat, withOffset: true, initialMessage: "Fetching messages...", limit: 100),
                      );

                      fetchAttachments();
                    },
                  ),
                  SettingsTile(
                    title: "Sync Last 25 Messages",
                    subtitle: "Syncs the 25 most recent messages from the server",
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: Icon(
                        ss.settings.skin.value == Skins.iOS
                            ? CupertinoIcons.arrow_counterclockwise
                            : Icons.replay,
                      ),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) =>
                            SyncDialog(chat: chat, initialMessage: "Syncing messages...", limit: 25),
                      );
                    },
                  ),
                  if (!kIsWeb &&
                      !widget.chat.isGroup &&
                      ss.settings.enablePrivateAPI.value &&
                      ss.settings.privateMarkChatAsRead.value)
                    SettingsSwitch(
                      title: "Send Read Receipts",
                      initialVal: widget.chat.autoSendReadReceipts!,
                      onChanged: (value) {
                        widget.chat.toggleAutoRead(!widget.chat.autoSendReadReceipts!);
                        eventDispatcher.emit("refresh", null);
                        if (mounted) setState(() {});
                      },
                      backgroundColor: tileColor,
                    ),
                  if (!kIsWeb &&
                      !widget.chat.isGroup &&
                      ss.settings.enablePrivateAPI.value &&
                      ss.settings.privateSendTypingIndicators.value)
                    SettingsSwitch(
                      title: "Send Typing Indicators",
                      initialVal: widget.chat.autoSendTypingIndicators!,
                      onChanged: (value) {
                        widget.chat.toggleAutoType(!widget.chat.autoSendTypingIndicators!);
                        eventDispatcher.emit("refresh", null);
                        if (mounted) setState(() {});
                      },
                      backgroundColor: tileColor,
                    ),
                  if (!kIsWeb)
                    SettingsSwitch(
                      title: "Pin Conversation",
                      initialVal: widget.chat.isPinned!,
                      onChanged: (value) {
                        widget.chat.togglePin(!widget.chat.isPinned!);
                        eventDispatcher.emit("refresh", null);
                        if (mounted) setState(() {});
                      },
                      backgroundColor: tileColor,
                    ),
                  if (!kIsWeb)
                    SettingsSwitch(
                      title: "Mute Conversation",
                      initialVal: widget.chat.muteType == "mute",
                      onChanged: (value) {
                        widget.chat.toggleMute(value);
                        eventDispatcher.emit("refresh", null);
                        if (mounted) setState(() {});
                      },
                      backgroundColor: tileColor,
                    ),
                  if (!kIsWeb)
                    SettingsSwitch(
                      title: "Archive Conversation",
                      initialVal: widget.chat.isArchived!,
                      onChanged: (value) {
                        widget.chat.toggleArchived(value);
                      },
                      backgroundColor: tileColor,
                    ),
                  if (!kIsWeb)
                    SettingsTile(
                      title: "Clear Transcript",
                      subtitle: "Delete all messages for this chat on this device",
                      trailing: Padding(
                        padding: const EdgeInsets.only(right: 15.0),
                        child: Icon(
                          ss.settings.skin.value == Skins.iOS
                              ? CupertinoIcons.trash
                              : Icons.delete_outlined,
                        ),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                                backgroundColor: context.theme.colorScheme.properSurface,
                                title: Text("Are You Sure?",
                                    style: context.theme.textTheme.titleLarge),
                                content: Text(
                                  'Clearing the transcript will permanently delete all messages in this chat. It will also prevent any previous messages from being loaded by the app, until you perform a full reset.',
                                  style: context.theme.textTheme.bodyLarge,
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                                    onPressed: () async {
                                      Navigator.of(context).pop();
                                      widget.chat.clearTranscript();
                                      eventDispatcher.emit("refresh-messagebloc", {"chatGuid": widget.chat.guid});
                                    },
                                  ),
                                ]);
                          },
                        );
                      },
                    ),
                  if (!kIsWeb)
                    SettingsTile(
                      title: "Download Chat Transcript",
                      subtitle: kIsDesktop ? "Left click for a plaintext transcript\nRight click for a PDF transcript" : "Tap for a plaintext transcript\nTap and hold for a PDF transcript",
                      isThreeLine: true,
                      trailing: Padding(
                        padding: const EdgeInsets.only(right: 15.0),
                        child: Icon(
                          ss.settings.skin.value == Skins.iOS ? CupertinoIcons.doc_text : Icons.note_outlined,
                        ),
                      ),
                      onTap: () async {
                        final tuple = await showTimeframePicker();
                        int days = tuple.item1;
                        int hours = tuple.item2;
                        if (hours == 0 && days == 0) return;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("Generating PDF...", style: context.theme.textTheme.titleLarge),
                            content: Column(mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SizedBox(
                                    height: 15.0,
                                  ),
                                  buildProgressIndicator(context),
                                ]),
                            backgroundColor: context.theme.colorScheme.properSurface,
                          ),
                          barrierDismissible: false,
                        );
                        final messages = (await Chat.getMessagesAsync(chat, limit: 0, includeDeleted: true))
                            .reversed
                            .where((e) => DateTime.now().isWithin(e.dateCreated!,
                            hours: hours != 0 ? hours : null, days: days != 0 ? days : null));
                        if (messages.isEmpty) {
                          Get.back();
                          showSnackbar("Error", "No messages found!");
                          return;
                        }
                        final List<String> lines = [];
                        for (Message m in messages) {
                          if (m.hasAttachments) {
                            m.fetchAttachments();
                          }
                          final readStr = m.dateRead != null ? "Read: ${buildFullDate(m.dateRead!)}, " : "";
                          final deliveredStr =
                          m.dateDelivered != null ? "Delivered: ${buildFullDate(m.dateDelivered!)}, " : "";
                          final sentStr = "Sent: ${buildFullDate(m.dateCreated!)}";
                          final text = MessageHelper.getNotificationText(m, withSender: true);
                          final line = "($readStr$deliveredStr$sentStr) $text";
                          lines.add(line);
                        }
                        final now = DateTime.now().toLocal();
                        String filePath = "/storage/emulated/0/Download/";
                        if (kIsDesktop) {
                          filePath = (await getDownloadsDirectory())!.path;
                        }
                        filePath = p.join(filePath,
                            "${(chat.title ?? "Unknown Chat").replaceAll(RegExp(r'[<>:"/\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt");
                        File file = File(filePath);
                        await file.create(recursive: true);
                        await file.writeAsString(lines.join('\n'));
                        Get.back();
                        showSnackbar("Success", "Saved transcript to the downloads folder");
                      },
                      onLongPress: () async {
                        final tuple = await showTimeframePicker();
                        int days = tuple.item1;
                        int hours = tuple.item2;
                        if (hours == 0 && days == 0) return;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("Generating PDF...", style: context.theme.textTheme.titleLarge),
                            content: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  SizedBox(
                                    height: 15.0,
                                  ),
                                  buildProgressIndicator(context),
                                ]),
                            backgroundColor: context.theme.colorScheme.properSurface,
                          ),
                          barrierDismissible: false,
                        );
                        final messages = (await Chat.getMessagesAsync(chat, limit: 0, includeDeleted: true))
                            .reversed
                            .where((e) => DateTime.now().isWithin(e.dateCreated!,
                            hours: hours != 0 ? hours : null, days: days != 0 ? days : null));
                        if (messages.isEmpty) {
                          Get.back();
                          showSnackbar("Error", "No messages found!");
                          return;
                        }
                        final doc = pw.Document();
                        final List<String> timestamps = [];
                        final List<dynamic> content = [];
                        final List<Size?> dimensions = [];
                        for (Message m in messages) {
                          if (m.hasAttachments) {
                            m.fetchAttachments();
                          }
                          final readStr = m.dateRead != null ? "Read: ${buildFullDate(m.dateRead!)}, " : "";
                          final deliveredStr =
                          m.dateDelivered != null ? "Delivered: ${buildFullDate(m.dateDelivered!)}, " : "";
                          final sentStr = "Sent: ${buildFullDate(m.dateCreated!)}";
                          if (m.hasAttachments) {
                            final attachments = m.attachments.where((e) =>
                            e?.guid != null && ["image/png", "image/jpg", "image/jpeg"].contains(e!.mimeType));
                            final files = attachments
                                .map((e) => as.getContent(e!, autoDownload: false))
                                .whereType<PlatformFile>();
                            if (files.isNotEmpty) {
                              for (PlatformFile f in files) {
                                final a = attachments.firstWhere((e) => e!.transferName == f.name);
                                timestamps.add(readStr + deliveredStr + sentStr);
                                content.add(pw.MemoryImage(await File(f.path!).readAsBytes()));
                                final aspectRatio = (a!.width ?? 150.0) / (a.height ?? 150.0);
                                dimensions.add(Size(400, aspectRatio * 400));
                              }
                            }
                            timestamps.add(readStr + deliveredStr + sentStr);
                            content.add(MessageHelper.getNotificationText(m, withSender: true));
                            dimensions.add(null);
                          } else {
                            timestamps.add(readStr + deliveredStr + sentStr);
                            content.add(MessageHelper.getNotificationText(m, withSender: true));
                            dimensions.add(null);
                          }
                        }
                        final font = await PdfGoogleFonts.openSansRegular();
                        doc.addPage(pw.MultiPage(
                            maxPages: 1000,
                            header: (pw.Context context) => pw.Padding(
                                padding: pw.EdgeInsets.only(bottom: 10),
                                child: pw.Text(chat.title ?? "Unknown Chat",
                                    textScaleFactor: 2,
                                    style: pw.Theme.of(context)
                                        .defaultTextStyle
                                        .copyWith(fontWeight: pw.FontWeight.bold, font: font))),
                            build: (pw.Context context) => [
                              pw.Partitions(children: [
                                pw.Partition(
                                    child: pw.Table(
                                        children: List.generate(
                                            timestamps.length,
                                                (index) => pw.TableRow(children: [
                                              pw.Padding(
                                                padding: pw.EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                                                child: pw.Text(timestamps[index],
                                                    style: pw.Theme.of(context)
                                                        .defaultTextStyle
                                                        .copyWith(font: font)),
                                              ),
                                              pw.Container(
                                                  child: pw.Padding(
                                                      padding: pw.EdgeInsets.symmetric(
                                                          horizontal: 3, vertical: 10),
                                                      child: content[index] is pw.MemoryImage
                                                          ? pw.Image(content[index],
                                                          width: dimensions[index]!.width,
                                                          height: dimensions[index]!.height)
                                                          : pw.Text(content[index].toString(),
                                                          style: pw.TextStyle(font: font))))
                                            ])))),
                              ]),
                            ]));
                        final now = DateTime.now().toLocal();
                        String filePath = "/storage/emulated/0/Download/";
                        if (kIsDesktop) {
                          filePath = (await getDownloadsDirectory())!.path;
                        }
                        filePath = p.join(filePath,
                            "${(chat.title ?? "Unknown Chat").replaceAll(RegExp(r'[<>:"/\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.pdf");
                        File file = File(filePath);
                        await file.create(recursive: true);
                        await file.writeAsBytes(await doc.save());
                        Get.back();
                        showSnackbar("Success", "Saved transcript to the downloads folder");
                      },
                    ),
                ],
              ),
            ),
            if (!kIsWeb)
              SliverPadding(
                padding: EdgeInsets.only(top: 20, bottom: 10, left: 15),
                sliver: SliverToBoxAdapter(
                  child: Text("MEDIA", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
                ),
              ),
            if (!kIsWeb)
              SliverPadding(
                padding: const EdgeInsets.all(10),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: max(2, ns.width(context) ~/ 200),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, int index) {
                      return MediaGalleryCard(
                        attachment: attachmentsForChat[index],
                      );
                    },
                    childCount: attachmentsForChat.length,
                  ),
                ),
              ),
            const SliverPadding(
              padding: EdgeInsets.only(top: 50),
            ),
          ],
        ))
      ),
    );
  }

  Future<Tuple2<int, int>> showTimeframePicker() async {
    int hours = 0;
    int days = 0;
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "Select timeframe",
              style: context.theme.textTheme.titleLarge,
            ),
            backgroundColor: context.theme.colorScheme.properSurface,
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                  padding: EdgeInsets.all(15),
                  child: Text("Note: Longer timeframes may take a while to generate the file", style: context.theme.textTheme.bodyLarge,)),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    child: Text("Cancel", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text("1 Hour", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      hours = 1;
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text("1 Day", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      days = 1;
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text("1 Week", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      days = 7;
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text("1 Month", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      days = 30;
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text("1 Year", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                    onPressed: () {
                      days = 365;
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              )
            ]),
          );
        },
    );
    return Tuple2(days, hours);
  }

  void onPressContact(Contact? contact, Handle handle, {bool isEmail = false, bool isLongPressed = false}) async {
    void performAction(String address) async {
      if (isEmail) {
        launchUrl(Uri(scheme: "mailto", path: address));
      } else if (await Permission.phone.request().isGranted) {
        launchUrl(Uri(scheme: "tel", path: address));
      }
    }

    if (contact == null) {
      performAction(handle.address);
    } else {
      List<String> items = isEmail ? getUniqueEmails(contact.emails) : getUniqueNumbers(contact.phones);
      if (items.length == 1) {
        performAction(items.first);
      } else if (!isEmail && handle.defaultPhone != null && !isLongPressed) {
        performAction(handle.defaultPhone!);
      } else if (isEmail && handle.defaultEmail != null && !isLongPressed) {
        performAction(handle.defaultEmail!);
      } else {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: context.theme.colorScheme.properSurface,
              title:
              Text("Select Address", style: context.theme.textTheme.titleLarge),
              content: ObxValue<Rx<bool>>(
                      (data) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < items.length; i++)
                        TextButton(
                          child: Text(items[i],
                              style: context.theme.textTheme.bodyLarge,
                              textAlign: TextAlign.start),
                          onPressed: () {
                            if (data.value) {
                              if (isEmail) {
                                handle.defaultEmail = items[i];
                                handle.updateDefaultEmail(items[i]);
                              } else {
                                handle.defaultPhone = items[i];
                                handle.updateDefaultPhone(items[i]);
                              }
                            }
                            performAction(items[i]);
                            Navigator.of(context).pop();
                          },
                        ),
                      Row(
                        children: <Widget>[
                          SizedBox(
                            height: 48.0,
                            width: 24.0,
                            child: Checkbox(
                              value: data.value,
                              activeColor: context.theme.colorScheme.primary,
                              onChanged: (bool? value) {
                                data.value = value!;
                              },
                            ),
                          ),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  primary: Colors.transparent, padding: EdgeInsets.only(left: 5), elevation: 0.0),
                              onPressed: () {
                                data = data.toggle();
                              },
                              child: Text(
                                "Remember my selection", style: context.theme.textTheme.bodyMedium
                              )),
                        ],
                      ),
                      Text(
                        "Long press the ${isEmail ? "email" : "call"} button to reset your default selection",
                        style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                      )
                    ],
                  ),
                  false.obs),
            );
          },
        );
      }
    }
  }
}

class SyncDialog extends StatefulWidget {
  SyncDialog({Key? key, required this.chat, this.initialMessage, this.withOffset = false, this.limit = 100})
      : super(key: key);
  final Chat chat;
  final String? initialMessage;
  final bool withOffset;
  final int limit;

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  String? errorCode;
  bool finished = false;
  String? message;
  double? progress;

  @override
  void initState() {
    super.initState();
    message = widget.initialMessage;
    syncMessages();
  }

  void syncMessages() async {
    int offset = 0;
    if (widget.withOffset) {
      offset = Message.countForChat(widget.chat) ?? 0;
    }

    cm.getMessages(widget.chat.guid, offset: offset, limit: widget.limit).then((dynamic messages) {
      if (mounted) {
        setState(() {
          message = "Adding ${messages.length} messages...";
        });
      }

      MessageHelper.bulkAddMessages(widget.chat, messages, onProgress: (int progress, int length) {
        if (progress == 0 || length == 0) {
          this.progress = null;
        } else {
          this.progress = progress / length;
        }

        if (mounted) setState(() {});
      }).then((List<Message> __) {
        onFinish(true);
      });
    }).catchError((_) {
      onFinish(false);
    });
  }

  void onFinish([bool success = true]) {
    if (!mounted) return;
    if (success) Navigator.of(context).pop();
    if (!success) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(errorCode != null ? "Error!" : message!, style: context.theme.textTheme.titleLarge),
      content: errorCode != null
          ? Text(errorCode!, style: context.theme.textTheme.bodyLarge)
          : Container(
              height: 5,
              child: Center(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: context.theme.colorScheme.outline,
                  valueColor: AlwaysStoppedAnimation<Color>(context.theme.colorScheme.primary),
                ),
              ),
            ),
      backgroundColor: context.theme.colorScheme.properSurface,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "OK", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary),
          ),
        )
      ],
    );
  }
}
