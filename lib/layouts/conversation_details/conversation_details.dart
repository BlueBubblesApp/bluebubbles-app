import 'dart:ui';

import 'package:get/get.dart';
import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/layouts/conversation_details/attachment_details_card.dart';
import 'package:bluebubbles/layouts/conversation_details/contact_tile.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/chat.dart';
import 'package:bluebubbles/repository/models/handle.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ConversationDetails extends StatefulWidget {
  final Chat chat;
  final MessageBloc messageBloc;

  ConversationDetails({Key key, this.chat, this.messageBloc}) : super(key: key);

  @override
  _ConversationDetailsState createState() => _ConversationDetailsState();
}

class _ConversationDetailsState extends State<ConversationDetails> {
  TextEditingController controller;
  bool readOnly = true;
  Chat chat;
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
    controller = new TextEditingController(text: chat.displayName);
    showNameField = chat.displayName.isNotEmpty;

    fetchAttachments();
    ChatBloc().chatStream.listen((event) async {
      Chat _chat = await Chat.findOne({"guid": widget.chat.guid});
      if (_chat == null) return;
      await _chat.getParticipants();
      chat = _chat;
      if (this.mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();

    await chat.getParticipants();
    readOnly = !(chat.participants.length > 1);

    debugPrint("updated readonly $readOnly");
    if (this.mounted) setState(() {});
  }

  void fetchAttachments() {
    Chat.getAttachments(chat).then((value) {
      attachmentsForChat = value;
      if (this.mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool redactedMode = SettingsManager()?.settings?.redactedMode ?? false;
    final bool hideInfo = redactedMode && (SettingsManager()?.settings?.hideContactInfo ?? false);
    final bool generateName = redactedMode && (SettingsManager()?.settings?.generateFakeContactNames ?? false);
    if (generateName) controller.text = "Group Chat";

    final bool showGroupNameInfo = (showNameField && !hideInfo) || generateName;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Get.theme.backgroundColor,
      ),
      child: Scaffold(
        backgroundColor: Get.theme.backgroundColor,
        appBar: SettingsManager().settings.skin == Skins.IOS
            ? CupertinoNavigationBar(
                backgroundColor: Get.theme.accentColor.withAlpha(125),
                middle: Text(
                  "Details",
                  style: Get.theme.textTheme.headline1,
                ),
              )
            : AppBar(
                iconTheme: IconThemeData(color: Get.theme.primaryColor),
                title: Text(
                  "Details",
                  style: Get.theme.textTheme.headline1,
                ),
                backgroundColor: Get.theme.backgroundColor,
                bottom: PreferredSize(
                  child: Container(
                    color: Get.theme.dividerColor,
                    height: 0.5,
                  ),
                  preferredSize: Size.fromHeight(0.5),
                ),
              ),
        extendBodyBehindAppBar: SettingsManager().settings.skin == Skins.IOS ? true : false,
        body: CustomScrollView(
          physics: ThemeSwitcher.getScrollPhysics(),
          slivers: <Widget>[
            if (SettingsManager().settings.skin == Skins.IOS)
              SliverToBoxAdapter(
                child: Container(
                  height: 100,
                ),
              ),
            SliverToBoxAdapter(
              child: readOnly
                  ? Container()
                  : showGroupNameInfo
                      ? Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16.0, right: 8.0, bottom: 8.0),
                                child: TextField(
                                  cursorColor: Get.theme.primaryColor,
                                  readOnly: !chat.isGroup() || redactedMode,
                                  onSubmitted: (String newName) async {
                                    await widget.chat.changeName(newName);
                                    await widget.chat.getTitle();
                                    setState(() {
                                      showNameField = newName.isNotEmpty;
                                    });
                                    ChatBloc().updateChat(chat);
                                  },
                                  controller: controller,
                                  style: Get.theme.textTheme.bodyText1,
                                  autofocus: false,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                      labelText: chat.displayName.isEmpty ? "SET NAME" : "NAME",
                                      labelStyle: TextStyle(color: Get.theme.primaryColor),
                                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey))),
                                ),
                              ),
                            ),
                            if (showGroupNameInfo && chat.displayName.isNotEmpty)
                              Container(
                                  padding: EdgeInsets.only(right: 10),
                                  child: GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                                backgroundColor: Get.theme.accentColor,
                                                title: new Text("Group Naming",
                                                    style: TextStyle(color: Get.theme.textTheme.bodyText1.color)),
                                                content: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        "Changing the group name will only change it locally for you. It will not change the group name on any of your other devices, or for other members of the chat.",
                                                        style: Get.theme.textTheme.bodyText1),
                                                  ],
                                                ),
                                                actions: <Widget>[
                                                  FlatButton(
                                                      child: Text("OK",
                                                          style: Get.theme.textTheme.subtitle1
                                                              .apply(color: Get.theme.primaryColor)),
                                                      onPressed: () {
                                                        Navigator.of(context).pop();
                                                      }),
                                                ]);
                                          },
                                        );
                                      },
                                      child: Icon(
                                        Icons.info_outline,
                                        color: Get.theme.primaryColor,
                                      ))),
                            if (chat.displayName.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0, right: 16.0, bottom: 8.0),
                                child: RaisedButton(
                                  highlightColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  onPressed: () async {
                                    setState(() {
                                      showNameField = false;
                                    });
                                  },
                                  color: Get.theme.accentColor,
                                  child: Text(
                                    "CANCEL",
                                    style: TextStyle(
                                      color: Get.theme.textTheme.bodyText1.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : !hideInfo
                          ? Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                              child: RaisedButton(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                onPressed: () async {
                                  setState(() {
                                    showNameField = true;
                                  });
                                },
                                color: Get.theme.accentColor,
                                child: Text(
                                  "ADD NAME",
                                  style: TextStyle(
                                    color: Get.theme.textTheme.bodyText1.color,
                                    fontSize: 13,
                                  ),
                                ),
                              ))
                          : Container(),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= participants.length && shouldShowMore) {
                  return ListTile(
                    onTap: () {
                      if (!this.mounted) return;
                      setState(() {
                        showMore = !showMore;
                      });
                    },
                    leading: Text(
                      showMore ? "Show less" : "Show more",
                      style: TextStyle(
                        color: Get.theme.primaryColor,
                      ),
                    ),
                    trailing: Padding(
                      padding: EdgeInsets.only(right: 15),
                      child: Icon(
                        Icons.more_horiz,
                        color: Get.theme.primaryColor,
                      ),
                    ),
                  );
                }

                if (index >= chat.participants.length) return Container();

                return ContactTile(
                  key: Key(chat.participants[index].id.toString()),
                  handle: chat.participants[index],
                  chat: chat,
                  updateChat: (Chat newChat) {
                    chat = newChat;
                    if (this.mounted) setState(() {});
                  },
                  canBeRemoved: chat.participants.length > 1,
                );
              }, childCount: participants.length + 1),
            ),
            // SliverToBoxAdapter(
            //   child: chat.participants.length > 1
            //       ? InkWell(
            //           onTap: () async {
            //             Chat result = await Navigator.of(context).push(
            //               CupertinoPageRoute(
            //                 builder: (context) => ConversationView(
            //                   isCreator: true,
            //                   type: ChatSelectorTypes.ONLY_CONTACTS,
            //                   onSelect: (List<UniqueContact> items) {
            //                     Navigator.of(context).pop();
            //                     if (items.length == 0) return;

            //                     for (UniqueContact contact in items) {
            //                       if (contact.isChat) return;
            //                     }
            //                     showDialog(
            //                       context: context,
            //                       barrierDismissible: false,
            //                       builder: (context) => AddingParticipantPopup(
            //                         contacts: items,
            //                         chat: chat,
            //                       ),
            //                     );
            //                   },
            //                 ),
            //               ),
            //             );
            //             if (result != null && this.mounted) {
            //               chat = result;
            //               setState(() {});
            //             }
            //           },
            //           child: ListTile(
            //             title: Text(
            //               "Add Contact",
            //               style: TextStyle(
            //                 color: Get.theme.primaryColor,
            //               ),
            //             ),
            //             leading: Icon(
            //               Icons.add,
            //               color: Get.theme.primaryColor,
            //             ),
            //           ),
            //         )
            //       : Container(),
            // ),
            SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 20),
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
                      color: Get.theme.primaryColor,
                    ),
                  ),
                  trailing: Padding(
                    padding: EdgeInsets.only(right: 15),
                    child: Icon(
                      Icons.file_download,
                      color: Get.theme.primaryColor,
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
                      color: Get.theme.primaryColor,
                    ),
                  ),
                  trailing: Padding(
                    padding: EdgeInsets.only(right: 15),
                    child: Icon(
                      Icons.replay,
                      color: Get.theme.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
                child: ListTile(
                    leading: Text("Pin Conversation",
                        style: TextStyle(
                          color: Get.theme.primaryColor,
                        )),
                    trailing: Switch(
                        value: widget.chat.isPinned,
                        activeColor: Get.theme.primaryColor,
                        activeTrackColor: Get.theme.primaryColor.withAlpha(200),
                        inactiveTrackColor: Get.theme.accentColor.withOpacity(0.6),
                        inactiveThumbColor: Get.theme.accentColor,
                        onChanged: (value) async {
                          if (value) {
                            await widget.chat.pin();
                          } else {
                            await widget.chat.unpin();
                          }

                          EventDispatcher().emit("refresh", null);

                          if (this.mounted) setState(() {});
                        }))),
            SliverToBoxAdapter(
                child: ListTile(
                    leading: Text("Mute Conversation",
                        style: TextStyle(
                          color: Get.theme.primaryColor,
                        )),
                    trailing: Switch(
                        value: widget.chat.isMuted,
                        activeColor: Get.theme.primaryColor,
                        activeTrackColor: Get.theme.primaryColor.withAlpha(200),
                        inactiveTrackColor: Get.theme.accentColor.withOpacity(0.6),
                        inactiveThumbColor: Get.theme.accentColor,
                        onChanged: (value) async {
                          widget.chat.isMuted = value;
                          await widget.chat.save(updateLocalVals: true);
                          EventDispatcher().emit("refresh", null);

                          if (this.mounted) setState(() {});
                        }))),
            SliverToBoxAdapter(
                child: ListTile(
                    leading: Text("Archive Conversation",
                        style: TextStyle(
                          color: Get.theme.primaryColor,
                        )),
                    trailing: Switch(
                        value: widget.chat.isArchived,
                        activeColor: Get.theme.primaryColor,
                        activeTrackColor: Get.theme.primaryColor.withAlpha(200),
                        inactiveTrackColor: Get.theme.accentColor.withOpacity(0.6),
                        inactiveThumbColor: Get.theme.accentColor,
                        onChanged: (value) {
                          if (value) {
                            ChatBloc().archiveChat(widget.chat);
                          } else {
                            ChatBloc().unArchiveChat(widget.chat);
                          }

                          EventDispatcher().emit("refresh", null);
                          if (this.mounted) setState(() {});
                        }))),
            SliverToBoxAdapter(
              child: InkWell(
                onTap: () async {
                  if (this.mounted)
                    setState(() {
                      isClearing = true;
                    });

                  try {
                    await widget.chat.clearTranscript();
                    EventDispatcher().emit("refresh-messagebloc", {"chatGuid": widget.chat.guid});
                    if (this.mounted)
                      setState(() {
                        isClearing = false;
                        isCleared = true;
                      });
                  } catch (ex) {
                    if (this.mounted)
                      setState(() {
                        isClearing = false;
                        isCleared = false;
                      });
                  }
                },
                child: ListTile(
                  leading: Text(
                    "Clear Transcript (Local Only)",
                    style: TextStyle(
                      color: Get.theme.primaryColor,
                    ),
                  ),
                  trailing: Padding(
                    padding: EdgeInsets.only(right: 15),
                    child: (isClearing)
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Get.theme.primaryColor),
                          )
                        : (isCleared)
                            ? Icon(
                                Icons.done,
                                color: Get.theme.primaryColor,
                              )
                            : Icon(
                                Icons.delete_forever,
                                color: Get.theme.primaryColor,
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
                      border: Border.all(color: Get.theme.backgroundColor, width: 3),
                    ),
                    child: AttachmentDetailsCard(
                      attachment: attachmentsForChat[index],
                      allAttachments: attachmentsForChat.reversed.toList(),
                    ),
                  );
                },
                childCount: attachmentsForChat.length,
              ),
            ),
            SliverToBoxAdapter(child: Container(height: 50))
          ],
        ),
      ),
    );
  }
}

class SyncDialog extends StatefulWidget {
  SyncDialog({Key key, this.chat, this.initialMessage, this.withOffset = false, this.limit = 100}) : super(key: key);
  final Chat chat;
  final String initialMessage;
  final bool withOffset;
  final int limit;

  @override
  _SyncDialogState createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  String errorCode;
  bool finished = false;
  String message;
  double progress;

  @override
  void initState() {
    super.initState();
    message = widget.initialMessage;
    syncMessages();
  }

  void syncMessages() async {
    int offset = 0;
    if (widget.withOffset) {
      offset = await Message.countForChat(widget.chat);
    }

    SocketManager().fetchMessages(widget.chat, offset: offset, limit: widget.limit).then((List<dynamic> messages) {
      if (this.mounted) {
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

        if (this.mounted) setState(() {});
      }).then((List<Message> __) {
        onFinish(true);
      });
    }).catchError((_) => onFinish(false));
  }

  void onFinish([bool success = true]) {
    if (!this.mounted) return;
    if (success) Navigator.of(context).pop();
    if (!success) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(errorCode != null ? "Error!" : message),
      content: errorCode != null
          ? Text(errorCode)
          : Container(
              height: 5,
              child: Center(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(Get.theme.primaryColor),
                ),
              ),
            ),
      actions: [
        FlatButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(
            "Ok",
            style: Get.theme.textTheme.bodyText1.apply(
              color: Get.theme.primaryColor,
            ),
          ),
        )
      ],
    );
  }
}
