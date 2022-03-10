import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_details/attachment_details_card.dart';
import 'package:bluebubbles/layouts/conversation_details/contact_tile.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view_mixin.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/contact_selector_option.dart';
import 'package:bluebubbles/layouts/widgets/avatar_crop.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:slugify/slugify.dart';
import 'package:universal_io/io.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;
  final MessageBloc messageBloc;

  ConversationDetails({Key? key, required this.chat, required this.messageBloc}) : super(key: key);

  @override
  _ConversationDetailsState createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends State<ConversationDetails> with WidgetsBindingObserver {
  late TextEditingController controller;
  bool readOnly = true;
  late Chat chat;
  List<Attachment> attachmentsForChat = <Attachment>[];
  bool isClearing = false;
  bool isCleared = false;
  int maxPageSize = 5;
  bool showMore = false;
  bool showNameField = false;

  bool get shouldShowMore {
    return chat.participants.length > maxPageSize;
  }

  List<Handle> get participants {
    // If we are showing all, return everything
    if (showMore) return chat.participants;

    // If we aren't showing all, show the max we can show
    return chat.participants.length > maxPageSize ? chat.participants.sublist(0, maxPageSize) : chat.participants;
  }

  @override
  void initState() {
    super.initState();
    chat = widget.chat;
    readOnly = !(chat.participants.length > 1);
    controller = TextEditingController(text: chat.displayName);
    showNameField = chat.displayName?.isNotEmpty ?? false;

    ever(ChatBloc().chats, (List<Chat> chats) async {
      Chat? _chat = chats.firstWhereOrNull((e) => e.guid == widget.chat.guid);
      if (_chat == null) return;
      _chat.getParticipants();
      chat = _chat;
      readOnly = !(chat.participants.length > 1);
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance!.addObserver(this);

    WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
      if (ModalRoute.of(context)?.animation != null) {
        if (ModalRoute.of(context)?.animation?.status != AnimationStatus.completed) {
          late final AnimationStatusListener listener;
          listener = (AnimationStatus status) {
            if (status == AnimationStatus.completed) {
              fetchAttachments();
              ModalRoute.of(context)?.animation?.removeStatusListener(listener);
            }
          };
          ModalRoute.of(context)?.animation?.addStatusListener(listener);
        } else {
          fetchAttachments();
        }
      } else {
        fetchAttachments();
      }
    });
  }

  void fetchAttachments() {
    if (kIsWeb) {
      if (attachmentsForChat.length > 25) attachmentsForChat = attachmentsForChat.sublist(0, 25);
      if (mounted) setState(() {});
      return;
    }
    chat.getAttachmentsAsync().then((value) {
      attachmentsForChat = value;
      if (attachmentsForChat.length > 25) attachmentsForChat = attachmentsForChat.sublist(0, 25);
      if (mounted) setState(() {});
    });
  }

  void showChangeName(String method) {
    showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            actions: [
              TextButton(
                child: Text("OK"),
                onPressed: () async {
                  if (method == "private-api") {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            title: Text(
                              controller.text.isEmpty ? "Removing name..." : "Changing name to ${controller.text}...",
                              style: Theme.of(context).textTheme.bodyText1,
                            ),
                            content:
                            Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                              Container(
                                // height: 70,
                                // color: Colors.black,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                ),
                              ),
                            ]),
                          );
                        });
                    final response = await api.updateChat(chat.guid, controller.text);
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
                    widget.chat.getTitle();
                    ChatBloc().updateChat(chat);
                  }
                },
              ),
              TextButton(
                child: Text("Cancel"),
                onPressed: () => Get.back(),
              )
            ],
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: "Chat Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            title: Text("Change Name"),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool redactedMode = SettingsManager().settings.redactedMode.value;
    final bool hideInfo = redactedMode && SettingsManager().settings.hideContactInfo.value;
    final bool generateName = redactedMode && SettingsManager().settings.generateFakeContactNames.value;
    if (generateName) controller.text = "Group Chat";

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
            Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Theme(
        data: Theme.of(context).copyWith(primaryColor: chat.isTextForwarding ? Colors.green : Theme.of(context).primaryColor),
        child: Builder(
          builder: (context) {
            return Scaffold(
              backgroundColor: Theme.of(context).backgroundColor,
              appBar: AppBar(
                leading: SettingsManager().settings.skin.value == Skins.iOS ? buildBackButton(context, padding: EdgeInsets.only(left: kIsDesktop ? 5 : 0, top: kIsDesktop ? 15 : 0)) : null,
                      iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
                      title: Padding(padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0), child: Text(
                        "Details",
                        style: Theme.of(context).textTheme.headline1,
                      ),),
                      backgroundColor: Theme.of(context).backgroundColor,
                      bottom: PreferredSize(
                        child: Container(
                          color: Theme.of(context).dividerColor,
                          height: 0.5,
                        ),
                        preferredSize: Size.fromHeight(0.5),
                      ),
                    ),
              extendBodyBehindAppBar: SettingsManager().settings.skin.value == Skins.iOS ? true : false,
              body: CustomScrollView(
                physics: ThemeSwitcher.getScrollPhysics(),
                slivers: <Widget>[
                  if (SettingsManager().settings.skin.value == Skins.iOS)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 100,
                      ),
                    ),
                  if (chat.isGroup())
                    SliverToBoxAdapter(
                      child: Center(
                        child: ContactAvatarGroupWidget(
                          chat: chat,
                          size: 100,
                          onTap: () {},
                        ),
                      ),
                    ),
                  if (chat.isGroup() && (chat.displayName?.isNotEmpty ?? false) && !hideInfo)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Center(
                          child: Text(
                            controller.text,
                            style: Theme.of(context).textTheme.bodyText1!.copyWith(fontWeight: FontWeight.bold),
                            textScaleFactor: 1.75,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        ),
                      ),
                    ),
                  if (chat.isGroup())
                    SliverToBoxAdapter(
                      child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                child: Text("${(chat.displayName?.isNotEmpty ?? false) ? "Change" : "Add"} Name",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyText1!
                                        .apply(color: Theme.of(context).primaryColor), textScaleFactor: 1.15,),
                                  onPressed: () {
                                    if (!SettingsManager().settings.enablePrivateAPI.value || !chat.isIMessage) {
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
                                    SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.info : Icons.info_outline,
                                    size: 15,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  padding: EdgeInsets.zero,
                                  iconSize: 15,
                                  constraints: BoxConstraints(maxWidth: 20, maxHeight: 20),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                            backgroundColor: Theme.of(context).colorScheme.secondary,
                                            title: Text("Group Naming",
                                                style:
                                                TextStyle(color: Theme.of(context).textTheme.bodyText1!.color)),
                                            content: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (!SettingsManager().settings.enablePrivateAPI.value || !chat.isIMessage)
                                                  Text(
                                                      "${!chat.isIMessage ? "This chat is SMS" : "You have Private API disabled"}, so changing the name here will only change it locally for you. You will not see these changes on other devices, and the other members of this chat will not see these changes.",
                                                      style: Theme.of(context).textTheme.bodyText1),
                                                if (SettingsManager().settings.enablePrivateAPI.value && chat.isIMessage)
                                                  Text(
                                                      "You have Private API enabled, so changing the name here will change the name for everyone in this chat. If you only want to change it locally, you can tap and hold the \"Change Name\" button.",
                                                      style: Theme.of(context).textTheme.bodyText1),
                                              ],
                                            ),
                                            actions: <Widget>[
                                              TextButton(
                                                  child: Text("OK",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .subtitle1!
                                                          .apply(color: Theme.of(context).primaryColor)),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  }),
                                            ]);
                                      },
                                    );
                                  },
                                ),
                              )
                            ],
                          ),
                      ),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= participants.length && shouldShowMore) {
                        return ListTile(
                          onTap: () {
                            if (!mounted) return;
                            setState(() {
                              showMore = !showMore;
                            });
                          },
                          leading: Text(
                            showMore ? "Show less" : "Show more",
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          trailing: Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: Icon(
                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.ellipsis : Icons.more_horiz,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        );
                      }

                      if (index >= chat.participants.length) return Container();

                      return ContactTile(
                        key: Key(chat.participants[index].address),
                        handle: chat.participants[index],
                        chat: chat,
                        updateChat: (Chat newChat) {
                          chat = newChat;
                          if (mounted) setState(() {});
                        },
                        canBeRemoved: chat.participants.length > 1 && SettingsManager().settings.enablePrivateAPI.value && chat.isIMessage,
                      );
                    }, childCount: participants.length + 1),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  if (SettingsManager().settings.enablePrivateAPI.value && chat.isIMessage && chat.isGroup())
                    SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              primary: Theme.of(context).colorScheme.secondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () async {
                              final TextEditingController participantController = TextEditingController();
                              showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    actions: [
                                      TextButton(
                                        child: Text("Cancel"),
                                        onPressed: () => Get.back(),
                                      ),
                                      TextButton(
                                        child: Text("Pick Contact"),
                                        onPressed: () async {
                                          final contacts = [];
                                          final cache = [];
                                          String slugText(String text) {
                                            return slugify(text, delimiter: '').toString().replaceAll('-', '');
                                          }

                                          for (Contact contact in ContactManager().contacts) {
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
                                          await Get.defaultDialog(
                                            title: "Pick Contact",
                                            titleStyle: Theme.of(context).textTheme.headline1,
                                            backgroundColor: Theme.of(context).backgroundColor,
                                            buttonColor: Theme.of(context).primaryColor,
                                            content: Container(
                                              constraints: BoxConstraints(
                                                maxHeight: Get.height - 300,
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 300,
                                                  height: Get.height - 300,
                                                  constraints: BoxConstraints(
                                                    maxHeight: Get.height - 300,
                                                  ),
                                                  child: StatefulBuilder(
                                                      builder: (context, setState) {
                                                        return SingleChildScrollView(
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Padding(
                                                                padding: const EdgeInsets.all(8.0),
                                                                child: Text("Select the contact you would like to add"),
                                                              ),
                                                              ListView.builder(
                                                                shrinkWrap: true,
                                                                itemCount: contacts.length,
                                                                physics: NeverScrollableScrollPhysics(),
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
                                                            ],
                                                          ),
                                                        );
                                                      }
                                                  ),
                                                ),
                                              ),
                                            ),
                                            confirm: Container(height: 0, width: 0),
                                            cancel: Container(height: 0, width: 0),
                                          );
                                          if (selected?.address != null) {
                                            if (!selected!.address!.isEmail) {
                                              participantController.text = selected!.address!.numericOnly();
                                            } else {
                                              participantController.text = selected!.address!;
                                            }
                                          }
                                        },
                                      ),
                                      TextButton(
                                        child: Text("OK"),
                                        onPressed: () async {
                                          if (participantController.text.isEmpty || (!participantController.text.isEmail && !participantController.text.isPhoneNumber)) {
                                            showSnackbar("Error", "Enter a valid address!");
                                            return;
                                          }
                                          showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return AlertDialog(
                                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                                  title: Text(
                                                    "Adding ${participantController.text}...",
                                                    style: Theme.of(context).textTheme.bodyText1,
                                                  ),
                                                  content:
                                                  Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                                                    Container(
                                                      // height: 70,
                                                      // color: Colors.black,
                                                      child: CircularProgressIndicator(
                                                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                                      ),
                                                    ),
                                                  ]),
                                                );
                                              });
                                          final response = await api.chatParticipant("add", chat.guid, participantController.text);
                                          if (response.statusCode == 200) {
                                            Get.back();
                                            Get.back();
                                            showSnackbar("Notice", "Added ${participantController.text} successfully!");
                                          } else {
                                            Get.back();
                                            showSnackbar("Error", "Failed to add ${participantController.text}!");
                                          }
                                        },
                                      ),
                                    ],
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: participantController,
                                          decoration: InputDecoration(
                                            labelText: "Phone Number / Email",
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    title: Text("Add Participant"),
                                  );
                                }
                              );
                            },
                            child: Text(
                              "ADD PARTICIPANT",
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyText1!.color,
                                fontSize: 13,
                              ),
                            ),
                          )),
                    ),
                  if (SettingsManager().settings.enablePrivateAPI.value && chat.isIMessage)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  if (!kIsWeb)
                    SliverToBoxAdapter(
                      child: InkWell(
                        onTap: () async {
                          if (chat.customAvatarPath != null) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                    backgroundColor: Theme.of(context).colorScheme.secondary,
                                    title: Text("Custom Avatar",
                                        style: TextStyle(color: Theme.of(context).textTheme.bodyText1!.color)),
                                    content: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("You have already set a custom avatar for this chat. What would you like to do?",
                                            style: Theme.of(context).textTheme.bodyText1),
                                      ],
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                          child: Text("Cancel",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle1!
                                                  .apply(color: Theme.of(context).primaryColor)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          }),
                                      TextButton(
                                          child: Text("Reset",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle1!
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
                                                  .subtitle1!
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
                        child: ListTile(
                          leading: Text(
                            "Change chat avatar",
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          trailing: Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: Icon(
                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.person : Icons.person,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: InkWell(
                      onTap: () async {
                        await showDialog(
                          context: context,
                          builder: (context) =>
                              SyncDialog(chat: chat, withOffset: true, initialMessage: "Fetching messages...", limit: 100),
                        );

                        fetchAttachments();
                      },
                      child: ListTile(
                        leading: Text(
                          "Fetch more messages",
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        trailing: Padding(
                          padding: EdgeInsets.only(right: 15),
                          child: Icon(
                            SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: InkWell(
                      onTap: () async {
                        showDialog(
                          context: context,
                          builder: (context) => SyncDialog(chat: chat, initialMessage: "Syncing messages...", limit: 25),
                        );
                      },
                      child: ListTile(
                        leading: Text(
                          "Sync last 25 messages",
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        trailing: Padding(
                          padding: EdgeInsets.only(right: 15),
                          child: Icon(
                            SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.arrow_counterclockwise : Icons.replay,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!kIsWeb && !widget.chat.isGroup() && SettingsManager().settings.enablePrivateAPI.value && SettingsManager().settings.privateMarkChatAsRead.value)
                    SliverToBoxAdapter(
                        child: ListTile(
                            leading: Text("Send Read Receipts",
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                )),
                            trailing: Switch(
                                value: widget.chat.autoSendReadReceipts!,
                                activeColor: Theme.of(context).primaryColor,
                                activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                                inactiveTrackColor: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                                inactiveThumbColor: Theme.of(context).colorScheme.secondary,
                                onChanged: (value) {
                                  widget.chat.toggleAutoRead(!widget.chat.autoSendReadReceipts!);
                                  EventDispatcher().emit("refresh", null);
                                  if (mounted) setState(() {});
                                }))),
                  if (!kIsWeb && !widget.chat.isGroup() && SettingsManager().settings.enablePrivateAPI.value && SettingsManager().settings.privateSendTypingIndicators.value)
                    SliverToBoxAdapter(
                        child: ListTile(
                            leading: Text("Send Typing Indicators",
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                )),
                            trailing: Switch(
                                value: widget.chat.autoSendTypingIndicators!,
                                activeColor: Theme.of(context).primaryColor,
                                activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                                inactiveTrackColor: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                                inactiveThumbColor: Theme.of(context).colorScheme.secondary,
                                onChanged: (value) {
                                  widget.chat.toggleAutoType(!widget.chat.autoSendTypingIndicators!);
                                  EventDispatcher().emit("refresh", null);
                                  if (mounted) setState(() {});
                                }))),
                  if (!kIsWeb)
                    SliverToBoxAdapter(
                        child: ListTile(
                            leading: Text("Pin Conversation",
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                )),
                            trailing: Switch(
                                value: widget.chat.isPinned!,
                                activeColor: Theme.of(context).primaryColor,
                                activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                                inactiveTrackColor: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                                inactiveThumbColor: Theme.of(context).colorScheme.secondary,
                                onChanged: (value) {
                                  widget.chat.togglePin(!widget.chat.isPinned!);
                                  EventDispatcher().emit("refresh", null);
                                  if (mounted) setState(() {});
                              }))),
                  if (!kIsWeb)
                    SliverToBoxAdapter(
                        child: ListTile(
                            leading: Text("Mute Conversation",
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                )),
                            trailing: Switch(
                                value: widget.chat.muteType == "mute",
                                activeColor: Theme.of(context).primaryColor,
                                activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                                inactiveTrackColor: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                                inactiveThumbColor: Theme.of(context).colorScheme.secondary,
                                onChanged: (value) {
                                  widget.chat.toggleMute(value);
                                  EventDispatcher().emit("refresh", null);

                                  if (mounted) setState(() {});
                                }))),
                  if (!kIsWeb)
                    SliverToBoxAdapter(
                        child: ListTile(
                            leading: Text("Archive Conversation",
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                )),
                            trailing: Switch(
                                value: widget.chat.isArchived!,
                                activeColor: Theme.of(context).primaryColor,
                                activeTrackColor: Theme.of(context).primaryColor.withAlpha(200),
                                inactiveTrackColor: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                                inactiveThumbColor: Theme.of(context).colorScheme.secondary,
                                onChanged: (value) {
                                  if (value) {
                                    ChatBloc().archiveChat(widget.chat);
                                  } else {
                                    ChatBloc().unArchiveChat(widget.chat);
                                  }

                                  EventDispatcher().emit("refresh", null);
                                  if (mounted) setState(() {});
                                }))),
                  if (!kIsWeb)
                    SliverToBoxAdapter(
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  title: Text("Are You Sure?",
                                      style:
                                      TextStyle(color: Theme.of(context).textTheme.bodyText1!.color)),
                                  content: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Clearing the transcript will permanently prevent all stored messages from being loaded by the client app, until you perform a full reset.',
                                        style: context.theme.textTheme.subtitle1,
                                      ),
                                    ],
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                      child: Text("Yes"),
                                      onPressed: () async {
                                        if (mounted) {
                                          setState(() {
                                            isClearing = true;
                                          });
                                        }

                                        try {
                                          widget.chat.clearTranscript();
                                          EventDispatcher().emit("refresh-messagebloc", {"chatGuid": widget.chat.guid});
                                          if (mounted) {
                                            setState(() {
                                              isClearing = false;
                                              isCleared = true;
                                            });
                                          }
                                        } catch (ex) {
                                          if (mounted) {
                                            setState(() {
                                              isClearing = false;
                                              isCleared = false;
                                            });
                                          }
                                        }
                                      },
                                    ),
                                    TextButton(
                                      child: Text("Cancel"),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ]
                              );
                            },
                          );
                        },
                        child: ListTile(
                          leading: Text(
                            "Clear Transcript (Local Only)",
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          trailing: Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: (isClearing)
                                ? CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                                  )
                                : (isCleared)
                                    ? Icon(
                                        SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.checkmark : Icons.done,
                                        color: Theme.of(context).primaryColor,
                                      )
                                    : Icon(
                                        SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.trash : Icons.delete_forever,
                                        color: Theme.of(context).primaryColor,
                                      ),
                          ),
                        ),
                      ),
                    ),
                  if (!kIsWeb)
                    SliverToBoxAdapter(
                      child: InkWell(
                        onTap: () async {
                          int hours = 0;
                          int days = 0;
                          await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  "Select timeframe",
                                  style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                                ),
                                content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                          padding: EdgeInsets.all(15),
                                          child: Text("Note: Longer timeframes may take a while to generate the txt file")
                                      ),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        children: [
                                          TextButton(
                                            child: Text("Cancel"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: Text("1 Hour"),
                                            onPressed: () {
                                              hours = 1;
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: Text("1 Day"),
                                            onPressed: () {
                                              days = 1;
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: Text("1 Week"),
                                            onPressed: () {
                                              days = 7;
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: Text("1 Month"),
                                            onPressed: () {
                                              days = 30;
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: Text("1 Year"),
                                            onPressed: () {
                                              days = 365;
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      )
                                    ]
                                ),
                                backgroundColor: Theme.of(context).backgroundColor,
                              );
                            },
                          );
                          if (hours == 0 && days == 0) return;
                          Get.defaultDialog(
                            title: "Generating transcript...",
                            titleStyle: Theme.of(context).textTheme.headline1,
                            confirm: Container(height: 0, width: 0),
                            cancel: Container(height: 0, width: 0),
                            content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  SizedBox(
                                    height: 15.0,
                                  ),
                                  buildProgressIndicator(context),
                                ]
                            ),
                            barrierDismissible: false,
                            backgroundColor: Theme.of(context).backgroundColor,
                          );
                          final messages = (await Chat.getMessagesAsync(chat, limit: 0, includeDeleted: true))
                              .reversed
                              .where((e) => DateTime.now().isWithin(e.dateCreated!, hours: hours != 0 ? hours : null, days: days != 0 ? days : null));
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
                            final deliveredStr = m.dateDelivered != null ? "Delivered: ${buildFullDate(m.dateDelivered!)}, " : "";
                            final sentStr = "Sent: ${buildFullDate(m.dateCreated!)}";
                            final text = MessageHelper.getNotificationText(m, withSender: true);
                            final line = "(" + readStr + deliveredStr + sentStr + ") " + text;
                            lines.add(line);
                          }
                          final now = DateTime.now().toLocal();
                          String filePath = "/storage/emulated/0/Download/";
                          if (kIsDesktop) {
                            filePath = (await getDownloadsDirectory())!.path;
                          }
                          filePath = p.join(filePath, "${(chat.title ?? "Unknown Chat").replaceAll(RegExp(r'[<>:"/\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.txt");
                          File file = File(filePath);
                          await file.create(recursive: true);
                          await file.writeAsString(lines.join('\n'));
                          Get.back();
                          showSnackbar("Success", "Saved transcript to the downloads folder");
                        },
                        child: ListTile(
                          leading: Text(
                            "Download Chat Transcript (Plaintext)",
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          trailing: Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: Icon(
                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.doc_text : Icons.note,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!kIsWeb)
                    SliverToBoxAdapter(
                      child: InkWell(
                        onTap: () async {
                          int hours = 0;
                          int days = 0;
                          await showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text(
                                  "Select timeframe",
                                  style: Theme.of(context).textTheme.bodyText1!.apply(fontSizeFactor: 1.5),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                        padding: EdgeInsets.all(15),
                                        child: Text("Note: Longer timeframes may take a while to generate the PDF")
                                    ),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      children: [
                                        TextButton(
                                          child: Text("Cancel"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text("1 Hour"),
                                          onPressed: () {
                                            hours = 1;
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text("1 Day"),
                                          onPressed: () {
                                            days = 1;
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text("1 Week"),
                                          onPressed: () {
                                            days = 7;
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text("1 Month"),
                                          onPressed: () {
                                            days = 30;
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: Text("1 Year"),
                                          onPressed: () {
                                            days = 365;
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    )
                                  ]
                                ),
                                backgroundColor: Theme.of(context).backgroundColor,
                              );
                            },
                          );
                          if (hours == 0 && days == 0) return;
                          Get.defaultDialog(
                            title: "Generating PDF...",
                            titleStyle: Theme.of(context).textTheme.headline1,
                            confirm: Container(height: 0, width: 0),
                            cancel: Container(height: 0, width: 0),
                            content: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  SizedBox(
                                    height: 15.0,
                                  ),
                                  buildProgressIndicator(context),
                                ]
                            ),
                            barrierDismissible: false,
                            backgroundColor: Theme.of(context).backgroundColor,
                          );
                          final messages = (await Chat.getMessagesAsync(chat, limit: 0, includeDeleted: true))
                              .reversed
                              .where((e) => DateTime.now().isWithin(e.dateCreated!, hours: hours != 0 ? hours : null, days: days != 0 ? days : null));
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
                            final deliveredStr = m.dateDelivered != null ? "Delivered: ${buildFullDate(m.dateDelivered!)}, " : "";
                            final sentStr = "Sent: ${buildFullDate(m.dateCreated!)}";
                            if (m.hasAttachments) {
                              final attachments = m.attachments.where((e) => e?.guid != null && ["image/png", "image/jpg", "image/jpeg"].contains(e!.mimeType));
                              final files = attachments.map((e) => AttachmentHelper.getContent(e!, autoDownload: false)).whereType<PlatformFile>();
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
                                      .copyWith(fontWeight: pw.FontWeight.bold, font: font))
                            ),
                            build: (pw.Context context) => [
                              pw.Partitions(
                                  children: [
                                    pw.Partition(
                                      child: pw.Table(
                                        children: List.generate(timestamps.length, (index) => pw.TableRow(
                                          children: [
                                            pw.Padding(
                                              padding: pw.EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                                              child: pw.Text(timestamps[index],
                                                  style: pw.Theme.of(context)
                                                      .defaultTextStyle
                                                      .copyWith(font: font)),
                                            ),
                                            pw.Container(
                                              child: pw.Padding(
                                                  padding: pw.EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                                                  child: content[index] is pw.MemoryImage
                                                      ? pw.Image(content[index], width: dimensions[index]!.width, height: dimensions[index]!.height)
                                                      : pw.Text(content[index].toString(),
                                                      style: pw.TextStyle(font: font))
                                              )
                                            )
                                          ]
                                        ))
                                      )
                                    ),
                                  ]
                              ),
                            ]
                          ));
                          final now = DateTime.now().toLocal();
                          String filePath = "/storage/emulated/0/Download/";
                          if (kIsDesktop) {
                            filePath = (await getDownloadsDirectory())!.path;
                          }
                          filePath = p.join(filePath,"${(chat.title ?? "Unknown Chat").replaceAll(RegExp(r'[<>:"/\|?*]'), "")}-transcript-${now.year}${now.month}${now.day}_${now.hour}${now.minute}${now.second}.pdf");
                          File file = File(filePath);
                          await file.create(recursive: true);
                          await file.writeAsBytes(await doc.save());
                          Get.back();
                          showSnackbar("Success", "Saved transcript to the downloads folder");
                        },
                        child: ListTile(
                          leading: Text(
                            "Download Chat Transcript (PDF)",
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          trailing: Padding(
                            padding: EdgeInsets.only(right: 15),
                            child: Icon(
                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.doc_on_doc : Icons.picture_as_pdf,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, int index) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).backgroundColor, width: 3),
                          ),
                          child: AttachmentDetailsCard(
                            attachment: attachmentsForChat[index],
                          ),
                        );
                      },
                      childCount: attachmentsForChat.length,
                    ),
                  ),
                  SliverToBoxAdapter(child: Container(height: 50))
                ],
              ),
            );
          }
        ),
      ),
    );
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
  _SyncDialogState createState() => _SyncDialogState();
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

    SocketManager().fetchMessages(widget.chat, offset: offset, limit: widget.limit)!.then((dynamic messages) {
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
      title: Text(errorCode != null ? "Error!" : message!),
      content: errorCode != null
          ? Text(errorCode!)
          : Container(
              height: 5,
              child: Center(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "Ok",
            style: Theme.of(context).textTheme.bodyText1!.apply(
                  color: Theme.of(context).primaryColor,
                ),
          ),
        )
      ],
    );
  }
}
