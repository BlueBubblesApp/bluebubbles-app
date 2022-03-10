import 'dart:async';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/message_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/message_helper.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/socket_singletons.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_details/conversation_details.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/conversation_view/new_chat_creator/contact_selector_option.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/layouts/widgets/contact_avatar_group_widget.dart';
import 'package:bluebubbles/layouts/widgets/custom_cupertino_nav_bar.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/chat_controller.dart';
import 'package:bluebubbles/managers/chat_manager.dart';
import 'package:bluebubbles/managers/contact_manager.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/life_cycle_manager.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/new_message_manager.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:slugify/slugify.dart';
import 'package:url_launcher/url_launcher.dart';

mixin ConversationViewMixin<ConversationViewState extends StatefulWidget> on State<ConversationView> {
  /// Commonly shared variables
  Chat? chat;
  Chat? previousChat;
  bool? isCreator;
  MessageBloc? messageBloc;

  /// Regular conversation view variables
  OverlayEntry? entry;
  LayerLink layerLink = LayerLink();
  List<String?> newMessages = [];
  bool processingParticipants = false;

  /// Chat selector variables
  List<Chat> conversations = [];
  List<UniqueContact> contacts = [];
  List<UniqueContact> selected = [];
  List<UniqueContact> prevSelected = [];
  String searchQuery = "";
  bool currentlyProcessingDeleteKey = false;
  ChatController? currentChat;
  bool markingAsRead = false;
  bool markedAsRead = false;
  String previousSearch = '';
  int previousContactCount = 0;
  bool shouldShowAlert = false;

  final RxBool fetchingChatController = false.obs;

  final _contactStreamController = StreamController<List<UniqueContact>>.broadcast();

  Stream<List<UniqueContact>> get contactStream => _contactStreamController.stream;

  TextEditingController chatSelectorController = TextEditingController(text: " ");

  static Rx<MultiTween<String>> gradientTween = Rx<MultiTween<String>>(MultiTween<String>()
    ..add("color1", Tween<double>(begin: 0, end: 0.2))..add("color2", Tween<double>(begin: 0.8, end: 1)));
  Timer? _debounce;

  /// Conversation view methods
  ///
  ///
  /// ===========================================================
  void initConversationViewState() {
    if (isCreator!) return;

    fetchParticipants();

    newMessages = ChatBloc()
        .chats
        .where((element) => element.guid != chat?.guid && (element.hasUnreadMessage ?? false))
        .map((e) => e.guid)
        .toList();

    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!["add-unread-chat", "remove-unread-chat", "refresh-messagebloc"].contains(event["type"])) return;
      if (!event["data"].containsKey("chatGuid")) return;

      // Ignore any events having to do with this chat
      String? chatGuid = event["data"]["chatGuid"];
      if (chat!.guid == chatGuid) return;

      int preLength = newMessages.length;
      if (event["type"] == "add-unread-chat" && !newMessages.contains(chatGuid)) {
        newMessages.add(chatGuid);
      } else if (event["type"] == "remove-unread-chat" && newMessages.contains(chatGuid)) {
        newMessages.remove(chatGuid);
      }

      // Only re-render if the newMessages count changes
      if (preLength != newMessages.length && mounted) setState(() {});
    });

    // Listen for changes in the group
    NewMessageManager().stream.listen((NewMessageEvent event) async {
      // Make sure we have the required data to qualify for this tile
      if (event.chatGuid != widget.chat!.guid) return;
      if (!event.event.containsKey("message")) return;
      if (widget.chat?.guid == null) return;
      // Make sure the message is a group event
      Message message = event.event["message"];
      if (!message.isGroupEvent()) return;

      // If it's a group event, let's fetch the new information and save it
      try {
        await fetchChatSingleton(widget.chat!.guid);
      } catch (ex) {
        Logger.error(ex.toString());
      }

      setNewChatData(forceUpdate: true);
    });
  }

  void setNewChatData({forceUpdate = false}) {
    // Save the current participant list and get the latest
    List<Handle> ogParticipants = widget.chat!.participants;
    widget.chat!.getParticipants();

    // Save the current title and generate the new one
    String? ogTitle = widget.chat!.title;
    widget.chat!.getTitle();

    // If the original data is different, update the state
    if (ogTitle != widget.chat!.title || ogParticipants.length != widget.chat!.participants.length || forceUpdate) {
      if (mounted) setState(() {});
    }
  }

  void didChangeDependenciesConversationView() async {
    if (isCreator!) return;
    if (SchedulerBinding.instance!.schedulerPhase != SchedulerPhase.idle) {
      // wait for the end of that frame.
      await SchedulerBinding.instance!.endOfFrame;
    }
    SocketManager().removeChatNotification(chat!);
  }

  void initChatController(Chat chat) async {
    currentChat = ChatManager().createChatController(chat, active: true, loadAttachments: true);
    currentChat!.init();
    currentChat!.stream.listen((event) {
      if (mounted) setState(() {});
    });
  }

  MessageBloc initMessageBloc() {
    messageBloc = MessageBloc(chat);
    return messageBloc!;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    messageBloc?.dispose();
    _contactStreamController.close();

    ChatManager().setActiveChat(previousChat);
    super.dispose();
  }

  Future<void> fetchParticipants() async {
    if (chat?.guid == null) return;
    if (isCreator!) return;
    // Prevent multiple calls to fetch participants
    if (processingParticipants) return;
    processingParticipants = true;

    // If we don't have participants, get them
    if (chat!.participants.isEmpty) {
      chat!.getParticipants();

      // If we have participants, refresh the state
      if (chat!.participants.isNotEmpty) {
        if (mounted) setState(() {});
        return;
      }

      Logger.info("No participants found for chat, fetching...", tag: "ConversationView");

      try {
        // If we don't have participants, we should fetch them from the server
        Chat? data = await fetchChatSingleton(chat!.guid);
        // If we got data back, fetch the participants and update the state
        if (data != null) {
          chat!.getParticipants();
          if (chat!.participants.isNotEmpty) {
            Logger.info("Got new chat participants. Updating state.", tag: "ConversationView");
            if (mounted) setState(() {});
          } else {
            Logger.info("Participants list is still empty, please contact support!", tag: "ConversationView");
          }
        }
      } catch (ex) {
        Logger.error("There was an error fetching the chat");
        Logger.error(ex.toString());
      }
    }

    processingParticipants = false;
  }

  void openDetails() {
    Navigator.of(context).push(
      ThemeSwitcher.buildPageRoute(
        builder: (context) =>
            TitleBarWrapper(
              hideInSplitView: true,
              child: ConversationDetails(
                chat: chat!,
                messageBloc: messageBloc ?? initMessageBloc(),
              ),
            ),
      ),
    );
  }

  void markChatAsRead() {
    void setProgress(bool val) {
      if (mounted) {
        setState(() {
          markingAsRead = val;

          if (!val) {
            markedAsRead = true;
          }
        });
      }

      // Unset the marked icon
      Future.delayed(Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            markedAsRead = false;
          });
        }
      });
    }

    // Set that we are
    setProgress(true);

    SocketManager().sendMessage("mark-chat-read", {"chatGuid": chat!.guid}, (data) {
      setProgress(false);
    }).catchError((_) {
      setProgress(false);
    });
  }

  Widget buildCupertinoTrailing() {
    Color? fontColor = Theme
        .of(context)
        .textTheme
        .headline1!
        .color;
    bool manualMark =
        SettingsManager().settings.enablePrivateAPI.value && SettingsManager().settings.privateManualMarkAsRead.value;
    bool showManual = !SettingsManager().settings.privateMarkChatAsRead.value && !(widget.chat?.isGroup() ?? false);
    List<Widget> items = [
      if (showManual && manualMark && markingAsRead)
        Padding(
            padding: EdgeInsets.only(right: SettingsManager().settings.colorblindMode.value ? 15.0 : 10.0),
            child: SettingsManager().settings.skin.value == Skins.iOS
                ? Theme(
              data: ThemeData(
                cupertinoOverrideTheme: cupertino.CupertinoThemeData(
                  brightness: ThemeData.estimateBrightnessForColor(Theme
                      .of(context)
                      .backgroundColor),
                ),
              ),
              child: cupertino.CupertinoActivityIndicator(
                radius: 12,
              ),
            )
                : Container(
                height: 24,
                width: 24,
                child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    )))),
      if (showManual && manualMark && !markingAsRead)
        Padding(
          padding: EdgeInsets.only(right: SettingsManager().settings.colorblindMode.value ? 10.0 : 5.0),
          child: GestureDetector(
            child: Icon(
              (markedAsRead)
                  ? cupertino.CupertinoIcons.check_mark_circled
                  : cupertino.CupertinoIcons.check_mark_circled_solid,
              color: (markedAsRead) ? HexColor('32CD32').withAlpha(200) : fontColor,
            ),
            onTap: markChatAsRead,
          ),
        ),
    ];

    if (SettingsManager().settings.showConnectionIndicator.value) {
      items.add(Obx(() => getIndicatorIcon(SocketManager().state.value, size: 12)));
    }

    if (items.length <= 1) {
      items.add(Container(width: 40));
    }

    return Stack(
      alignment: (!SettingsManager().settings.showConnectionIndicator.value || !manualMark)
          ? AlignmentDirectional.center
          : AlignmentDirectional.topEnd,
      children: items,
    );
  }

  Widget buildConversationViewHeader(BuildContext context) {
    Color backgroundColor = Theme
        .of(context)
        .backgroundColor;
    Color? fontColor = Theme
        .of(context)
        .textTheme
        .headline1!
        .color;
    Color? fontColor2 = Theme
        .of(context)
        .textTheme
        .subtitle1!
        .color;
    String? title = chat!.title;

    final hideTitle = SettingsManager().settings.redactedMode.value && SettingsManager().settings.hideContactInfo.value;
    final generateTitle =
        SettingsManager().settings.redactedMode.value && SettingsManager().settings.generateFakeContactNames.value;

    if (generateTitle) {
      title = chat!.fakeNames.length > 1 ? "Group Chat" : chat!.fakeNames[0];
    } else if (hideTitle) {
      fontColor = Colors.transparent;
      fontColor2 = Colors.transparent;
    }

    if (SettingsManager().settings.skin.value == Skins.Material ||
        SettingsManager().settings.skin.value == Skins.Samsung) {
      return AppBar(
        toolbarHeight: kIsDesktop ? 70 : null,
        systemOverlayStyle: ThemeData.estimateBrightnessForColor(Theme
            .of(context)
            .backgroundColor) == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Padding(
          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
          child: GestureDetector(
            onTap: () async {
              if (!chat!.isGroup()) {
                final handle = chat!.handles.first;
                final contact = ContactManager().getContact(handle.address);
                if (contact == null) {
                  await MethodChannelInterface().invokeMethod("open-contact-form",
                      {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
                } else {
                  await MethodChannelInterface().invokeMethod("view-contact-form", {'id': contact.id});
                }
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: Theme
                      .of(context)
                      .textTheme
                      .headline1!
                      .apply(color: fontColor),
                ),
                if (SettingsManager().settings.skin.value == Skins.Samsung &&
                    (chat!.isGroup() || (!title.isPhoneNumber && !title.isEmail)))
                  Text(
                    generateTitle
                        ? ContactManager()
                        .getContact(chat!.handles.first.address)
                        ?.fakeAddress ?? ""
                        : chat!.isGroup()
                        ? "${chat!.participants.length} recipients"
                        : chat!.participants[0].address,
                    style: Theme
                        .of(context)
                        .textTheme
                        .subtitle1!
                        .apply(color: fontColor2),
                  ),
              ],
            ),
          ),
        ),
        bottom: PreferredSize(
          child: Container(
            color: Theme
                .of(context)
                .dividerColor,
            height: 0.5,
          ),
          preferredSize: Size.fromHeight(0.5),
        ),
        leading: Padding(
          padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
          // child: buildBackButton(context, callback: () {
          //   if (LifeCycleManager().isBubble) {
          //     SystemNavigator.pop();
          //     return false;
          //   }
          //   EventDispatcher().emit("update-highlight", null);
          //   return true;
          // }),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: backgroundColor,
        actionsIconTheme: IconThemeData(color: Theme
            .of(context)
            .primaryColor),
        iconTheme: IconThemeData(color: Theme
            .of(context)
            .primaryColor),
        actions: [
          Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Obx(() {
              if (SettingsManager().settings.showConnectionIndicator.value) {
                return Obx(() => getIndicatorIcon(SocketManager().state.value, size: 12));
              } else {
                return SizedBox.shrink();
              }
            }),
          ),
          Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Obx(() {
              if (SettingsManager().settings.privateManualMarkAsRead.value && markingAsRead) {
                return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Theme
                                  .of(context)
                                  .primaryColor)),
                        )));
              } else {
                return SizedBox.shrink();
              }
            }),
          ),
          Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Obx(() {
              if (SettingsManager().settings.enablePrivateAPI.value &&
                  SettingsManager().settings.privateManualMarkAsRead.value &&
                  !markingAsRead) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    child: Icon(
                      (markedAsRead)
                          ? SettingsManager().settings.skin.value == Skins.iOS
                          ? cupertino.CupertinoIcons.check_mark_circled_solid
                          : Icons.check_circle
                          : SettingsManager().settings.skin.value == Skins.iOS
                          ? cupertino.CupertinoIcons.check_mark_circled
                          : Icons.check_circle_outline,
                      color: (markedAsRead) ? HexColor('32CD32').withAlpha(200) : fontColor,
                    ),
                    onTap: markChatAsRead,
                  ),
                );
              } else {
                return SizedBox.shrink();
              }
            }),
          ),
          if ((!chat!.isGroup() &&
              (chat!.participants[0].address.isPhoneNumber || chat!.participants[0].address.isEmail)) &&
              !kIsDesktop &&
              !kIsWeb)
            Padding(
              padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: GestureDetector(
                  child: Icon(
                    chat!.participants[0].address.isPhoneNumber ? Icons.call : Icons.email,
                    color: fontColor,
                  ),
                  onTap: () {
                    if (chat!.participants[0].address.isPhoneNumber) {
                      launch("tel://${chat!.participants[0].address}");
                    } else {
                      launch('mailto:${chat!.participants[0].address}');
                    }
                  },
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: kIsDesktop ? 20 : 0),
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                child: Icon(
                  SettingsManager().settings.skin.value == Skins.iOS
                      ? cupertino.CupertinoIcons.ellipsis
                      : Icons.more_vert,
                  color: fontColor,
                ),
                onTap: openDetails,
              ),
            ),
          ),
        ],
      );
    }

    TextStyle? titleStyle = Theme
        .of(context)
        .textTheme
        .bodyText1;
    if (!generateTitle && hideTitle) titleStyle = titleStyle!.copyWith(color: Colors.transparent);

    // NOTE: THIS IS ZACH TRYING TO FIX THE NAV BAR (REPLACE IT)
    // IT KINDA WORKED BUT ULTIMATELY FAILED

    // return PreferredSize(
    //     preferredSize: Size(CustomNavigator.width(context), 80),
    //     child: ClipRect(
    //         child: BackdropFilter(
    //             filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
    //             child: Container(
    //                 decoration: BoxDecoration(
    //                   backgroundBlendMode: BlendMode.color,
    //                   border: Border(
    //                     bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.2),
    //                   ),
    //                   color: Theme.of(context).colorScheme.secondary.withAlpha(125),
    //                 ),
    //                 child: Row(
    //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //                     crossAxisAlignment: CrossAxisAlignment.center,
    //                     children: [
    //                       GestureDetector(
    //                         onTap: () {
    //                           Navigator.of(context).pop();
    //                         },
    //                         child: Row(
    //                           mainAxisSize: MainAxisSize.min,
    //                           mainAxisAlignment: MainAxisAlignment.start,
    //                           crossAxisAlignment: Cupertino.CrossAxisAlignment.center,
    //                           children: [
    //                             buildBackButton(context),
    //                             if (newMessages.length > 0)
    //                               Container(
    //                                 width: 25.0,
    //                                 height: 20.0,
    //                                 decoration: BoxDecoration(
    //                                     color: Theme.of(context).primaryColor,
    //                                     shape: BoxShape.rectangle,
    //                                     borderRadius: BorderRadius.circular(10)),
    //                                 child: Center(
    //                                     child: Text(newMessages.length.toString(),
    //                                         textAlign: TextAlign.center,
    //                                         style: TextStyle(color: Colors.white, fontSize: 12.0))),
    //                               ),
    //                           ],
    //                         ),
    //                       ),
    //                       GestureDetector(
    //                         onTap: openDetails,
    //                         child: Column(
    //                           crossAxisAlignment: CrossAxisAlignment.center,
    //                           mainAxisAlignment: Cupertino.MainAxisAlignment.center,
    //                           children: [
    //                             RowSuper(
    //                               children: avatars,
    //                               innerDistance: distance,
    //                               alignment: Alignment.center,
    //                             ),
    //                             Container(height: 5.0),
    //                             RichText(
    //                               maxLines: 1,
    //                               overflow: Cupertino.TextOverflow.ellipsis,
    //                               textAlign: TextAlign.center,
    //                               text: TextSpan(
    //                                 style: Theme.of(context).textTheme.headline2,
    //                                 children: [
    //                                   TextSpan(
    //                                     text: title,
    //                                     style: titleStyle,
    //                                   ),
    //                                   TextSpan(
    //                                     text: " >",
    //                                     style: Theme.of(context).textTheme.subtitle1,
    //                                   ),
    //                                 ],
    //                               ),
    //                             ),
    //                           ],
    //                         ),
    //                       ),
    //                       this.buildCupertinoTrailing()
    //                     ])))));

    final children = [
      if (kIsDesktop) SizedBox(height: 8.0, width: 5.0),
      ContactAvatarGroupWidget(
        chat: chat!,
        size: chat!.participants.length == 1 ? 40 : 45,
        onTap: openDetails,
      ),
      if (!kIsDesktop) SizedBox(height: 5.0, width: 5.0),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: CustomNavigator.width(context) / 2 - 55,
          ),
          child: RichText(
            maxLines: 1,
            overflow: cupertino.TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme
                  .of(context)
                  .textTheme
                  .headline2,
              children: [
                ...MessageHelper.buildEmojiText(
                  title ?? "",
                  titleStyle!,
                ),
              ],
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            style: Theme
                .of(context)
                .textTheme
                .headline2,
            children: [
              TextSpan(
                text: " >",
                style: Theme
                    .of(context)
                    .textTheme
                    .subtitle1,
              ),
            ],
          ),
        ),
      ]),
    ];

    return PreferredSize(
      preferredSize: Size.fromHeight(context.orientation == Orientation.landscape && context.isPhone ? 55 : 75),
      child: CupertinoNavigationBar(
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .secondary
              .withAlpha(125),
          border: Border(
            bottom: BorderSide(color: Theme
                .of(context)
                .dividerColor, width: 1.5),
          ),
          leading: GestureDetector(
              onTap: () {
                if (LifeCycleManager().isBubble) {
                  ChatManager().setActiveChat(null);
                  SystemNavigator.pop();
                  return;
                }
                EventDispatcher().emit("update-highlight", null);
                Navigator.of(context).pop();
              },
              behavior: HitTestBehavior.translucent,
              child: Obx(
                    () =>
                    Container(
                      width: 40 + (ChatBloc().unreads.value > 0 ? 25 : 0),
                      child: Row(
                        mainAxisSize: cupertino.MainAxisSize.min,
                        mainAxisAlignment: cupertino.MainAxisAlignment.start,
                        children: [
                          buildBackButton(context, callback: () {
                            EventDispatcher().emit("update-highlight", null);
                            return true;
                          }),
                          if (ChatBloc().unreads.value > 0)
                            Container(
                              width: 25.0,
                              height: 20.0,
                              decoration: BoxDecoration(
                                  color: Theme
                                      .of(context)
                                      .primaryColor,
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Center(
                                  child: Text(ChatBloc().unreads.value.toString(),
                                      textAlign: TextAlign.center, style: TextStyle(
                                          color: Colors.white, fontSize: 12.0))),
                            ),
                        ],
                      ),
                    ),
              )),
          middle: cupertino.Padding(
            padding: EdgeInsets.only(right: newMessages.isNotEmpty ? 10 : 0),
            child: GestureDetector(
              onTap: openDetails,
              child: Builder(builder: (context) {
                if (context.orientation == Orientation.landscape && context.isPhone) {
                  return Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: children);
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: children,
                );
              }),
            ),
          ),
          trailing: Obx(
                  () =>
                  Container(width: 40 + (ChatBloc().unreads.value > 0 ? 25 : 0), child: buildCupertinoTrailing())
          )
      )
      ,
    );
  }

  /// Chat selector methods
  ///
  ///
  /// ===========================================================
  void initChatSelector() {
    if (!isCreator!) return;

    loadEntries();

    // Add listener to filter the contacts on text change
    chatSelectorController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (chatSelectorController.text.isEmpty) {
          if (selected.isNotEmpty && !currentlyProcessingDeleteKey) {
            currentlyProcessingDeleteKey = true;
            selected.removeLast();
            resetCursor();
            fetchChatController();
            setState(() {});
            // Prevent deletes from occuring multiple times
            Future.delayed(Duration(milliseconds: 100), () {
              currentlyProcessingDeleteKey = false;
            });
          } else {
            resetCursor();
          }
        } else if (chatSelectorController.text[0] != " ") {
          chatSelectorController.text =
              " " + chatSelectorController.text.substring(0, chatSelectorController.text.length - 1);
          chatSelectorController.selection = TextSelection.fromPosition(
            TextPosition(offset: chatSelectorController.text.length),
          );
          setState(() {});
        }
        searchQuery = chatSelectorController.text.substring(1);
        filterContacts();
      });
    });
  }

  void resetCursor() {
    if (!isCreator!) return;
    chatSelectorController.text = " ";
    chatSelectorController.selection = TextSelection.fromPosition(
      TextPosition(offset: 1),
    );
  }

  Future<void> fetchChatController() async {
    if (!isCreator!) return;
    if (selected.length == 1 && selected.first.isChat) {
      chat = selected.first.chat;
    }

    void clearCurrent() {
      chat = null;
      messageBloc = null;
      if (mounted) setState(() {});
    }

    // If we don't have anything selected, reset the chat and message bloc
    if (selected.isEmpty) {
      return clearCurrent();
    }

    // Check and see if there are any matching chats to the select participants
    List<Chat?> matchingChats = [];

    // If it's just one recipient, try manual lookup
    if (selected.length == 1) {
      try {
        Chat? existingChat;
        if (kIsWeb) {
          existingChat = await Chat.findOneWeb(chatIdentifier: slugify(selected[0].address!, delimiter: ''));
        } else {
          existingChat = Chat.findOne(chatIdentifier: slugify(selected[0].address!, delimiter: ''));
        }
        if (existingChat != null) {
          matchingChats.add(existingChat);
        }
      } catch (_) {}
    }

    if (matchingChats.isEmpty) {
      for (var i in ChatBloc().chats) {
        // If the lengths don't match continue
        if (i.participants.length != selected.length) continue;

        // Iterate over each selected contact
        int matches = 0;
        for (UniqueContact contact in selected) {
          bool match = false;
          bool isEmailAddr = contact.address!.isEmail;
          String lastDigits = contact.address!.substring(contact.address!.length - 4, contact.address!.length);

          for (var participant in i.participants) {
            // If one is an email and the other isn't, skip
            if (isEmailAddr && !participant.address.isEmail) continue;

            // If the last 4 digits don't match, skip
            if (!participant.address.endsWith(lastDigits)) continue;

            // Get a list of comparable options
            List<String?> opts = await getCompareOpts(participant);
            match = sameAddress(opts, contact.address);
            if (match) break;
          }

          if (match) matches += 1;
        }

        if (matches == selected.length) matchingChats.add(i);
      }
    }

    // If there are no matching chats, clear the chat and message bloc
    if (matchingChats.isEmpty) {
      return clearCurrent();
    }

    // Sort the chats and take the first one
    matchingChats.sort((a, b) => a!.participants.length.compareTo(b!.participants.length));
    chat = matchingChats.first;

    // Re-initialize the current chat and message bloc for the found chats
    if (chat != null) {
      currentChat = ChatManager().createChatController(chat!, active: true, loadAttachments: true);
      messageBloc = initMessageBloc();
    }
    if (mounted) setState(() {});
  }

  Future<void> loadEntries() async {
    if (!isCreator!) return;

    // If we don't have chats, fetch them
    if (ChatBloc().chats.isEmpty) {
      await ChatBloc().refreshChats();
    }

    void setChats(List<Chat> newChats) {
      conversations = newChats;
      for (int i = 0; i < conversations.length; i++) {
        if (isNullOrEmpty(conversations[i].participants)!) {
          conversations[i].getParticipants();
        }
      }

      filterContacts();
    }

    ever(ChatBloc().chats, (List<Chat> chats) async {
      if (chats.isEmpty) return;

      // Make sure the contact count changed, otherwise, don't set the chats
      if (chats.length == previousContactCount) return;
      previousContactCount = chats.length;

      // Update and filter the chats
      setChats(chats);
    });

    // When the chat request is finished, set the chats
    if (ChatBloc().chatRequest != null) {
      await ChatBloc().chatRequest!.future;
      setChats(ChatBloc().chats);
    }
  }

  void setContacts(List<UniqueContact> contacts, {bool addToStream = true, refreshState = false}) {
    this.contacts = contacts;
    if (addToStream && !_contactStreamController.isClosed) {
      _contactStreamController.sink.add(contacts);
    }

    if (refreshState && mounted) {
      setState(() {});
    }
  }

  void filterContacts() {
    if (!isCreator!) return;
    if (selected.length == 1 && selected.first.isChat) {
      setContacts([], addToStream: false);
    }

    String slugText(String text) {
      return slugify(text, delimiter: '').toString().replaceAll('-', '');
    }

    // slugify the search query for matching
    String tempSearchQuery = slugText(searchQuery);

    List<UniqueContact> _contacts = [];
    List<String> cache = [];
    void addContactEntries(Contact contact, {conditionally = false}) {
      for (String phone in contact.phones) {
        String cleansed = slugText(phone);
        if (conditionally && !cleansed.contains(tempSearchQuery)) continue;

        if (!cache.contains(cleansed)) {
          cache.add(cleansed);
          _contacts.add(
            UniqueContact(
              address: phone,
              displayName: contact.displayName,
            ),
          );
        }
      }

      for (String email in contact.emails) {
        String emailVal = slugText.call(email);
        if (conditionally && !emailVal.contains(tempSearchQuery)) continue;

        if (!cache.contains(emailVal)) {
          cache.add(emailVal);
          _contacts.add(
            UniqueContact(
              address: email,
              displayName: contact.displayName,
            ),
          );
        }
      }
    }

    if (widget.type != ChatSelectorTypes.ONLY_EXISTING) {
      for (Contact contact in ContactManager().contacts) {
        String name = slugText(contact.displayName);
        if (name.contains(tempSearchQuery)) {
          addContactEntries(contact);
        } else {
          addContactEntries(contact, conditionally: true);
        }
      }
    }

    List<UniqueContact> _conversations = [];
    if (selected.isEmpty && widget.type != ChatSelectorTypes.ONLY_CONTACTS) {
      for (Chat chat in conversations) {
        if (chat.title == null && chat.displayName == null) continue;
        String title = slugText(chat.title ?? chat.displayName!);
        if (title.contains(tempSearchQuery)) {
          if (!cache.contains(chat.guid)) {
            cache.add(chat.guid);
            _conversations.add(
              UniqueContact(
                chat: chat,
                displayName: chat.title,
              ),
            );
          }
        }
      }
    }

    _conversations.addAll(_contacts);
    if (searchQuery.isNotEmpty) {
      _conversations.sort((a, b) {
        if (a.isChat && a.chat!.participants.length == 1) return -1;
        if (b.isChat && b.chat!.participants.length == 1) return 1;
        if (a.isChat && !b.isChat) return 1;
        if (b.isChat && !a.isChat) return -1;
        if (!b.isChat && !a.isChat) return 0;
        return a.chat!.participants.length.compareTo(b.chat!.participants.length);
      });
    }

    bool shouldRefreshState = searchQuery != previousSearch || contacts.isEmpty || conversations.isEmpty;
    setContacts(_conversations, refreshState: shouldRefreshState);
    previousSearch = searchQuery;
  }

  Future<Chat?> createChat() async {
    if (chat != null) return chat;
    Completer<Chat?> completer = Completer();
    if (searchQuery.isNotEmpty) {
      selected.add(UniqueContact(address: searchQuery, displayName: searchQuery));
    }

    List<String> participants = selected.map((e) => cleansePhoneNumber(e.address!)).toList();
    Map<String, dynamic> params = {};
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Theme
                .of(context)
                .colorScheme
                .secondary,
            title: Text(
              "Creating a new chat...",
              style: Theme
                  .of(context)
                  .textTheme
                  .bodyText1,
            ),
            content:
            Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Container(
                // height: 70,
                // color: Colors.black,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme
                      .of(context)
                      .primaryColor),
                ),
              ),
            ]),
          );
        });

    params["participants"] = participants;
    Logger.info("Starting chat with participants: ${participants.join(", ")}");

    Future<void> returnChat(Chat newChat) async {
      newChat.save();
      await ChatBloc().updateChatPosition(newChat);
      completer.complete(newChat);
      Navigator.of(context).pop();
    }

    // If there is only 1 participant, try to find the chat
    Chat? existingChat;
    if (participants.length == 1) {
      if (kIsWeb) {
        existingChat = await Chat.findOneWeb(chatIdentifier: slugify(participants[0], delimiter: ''));
      } else {
        existingChat = Chat.findOne(chatIdentifier: slugify(participants[0], delimiter: ''));
      }
    }

    if (SettingsManager().settings.enablePrivateAPI.value &&
        (await SettingsManager().getMacOSVersion() ?? 0) > 10 &&
        existingChat == null) {
      api.createChat(participants, null).then((response) async {
        if (response.statusCode != 200) {
          Navigator.of(context).pop();
          showDialog(
              barrierDismissible: false,
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(
                    "Could not create",
                  ),
                  content: Text(
                    "Reason: (${response.data["error"]["type"]}) -> ${response.data["error"]["message"]}",
                  ),
                  actions: [
                    TextButton(
                      child: Text(
                        "Ok",
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    )
                  ],
                );
              });
          completer.complete(null);
          return;
        }

        // If everything went well, let's add the chat to the bloc
        Chat newChat = Chat.fromMap(response.data["data"]);
        await returnChat(newChat);
      });
    } else if (existingChat == null) {
      SocketManager().sendMessage(
        "start-chat",
        params,
            (data) async {
          if (data['status'] != 200) {
            Navigator.of(context).pop();
            showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      "Could not create",
                    ),
                    content: Text(
                      "Reason: (${data["error"]["type"]}) -> ${data["error"]["message"]}",
                    ),
                    actions: [
                      TextButton(
                        child: Text(
                          "Ok",
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      )
                    ],
                  );
                });
            completer.complete(null);
            return;
          }

          // If everything went well, let's add the chat to the bloc
          Chat newChat = Chat.fromMap(data["data"]);
          await returnChat(newChat);
        },
      );
    }

    if (existingChat != null) {
      await returnChat(existingChat);
    }

    return completer.future;
  }

  void onSelected(UniqueContact item) async {
    fetchingChatController.value = true;
    if (item.isChat) {
      if (widget.type == ChatSelectorTypes.ONLY_EXISTING) {
        selected.add(item);
        chat = item.chat;
        setContacts([], addToStream: false, refreshState: true);
      } else {
        for (Handle e in item.chat?.participants ?? []) {
          UniqueContact contact = UniqueContact(
              address: e.address,
              displayName:
              ContactManager()
                  .getContact(e.address)
                  ?.displayName ?? await formatPhoneNumber(e));
          selected.add(contact);
        }

        await fetchChatController();
      }

      resetCursor();
      if (mounted) setState(() {});
      fetchingChatController.value = false;
      return;
    }
    // Add the selected item
    selected.add(item);
    fetchChatController();

    // Reset the controller text
    resetCursor();
    if (mounted) setState(() {});
    fetchingChatController.value = false;
  }

  Widget buildChatSelectorBody() =>
      ClipRRect(
        borderRadius: SettingsManager().settings.skin.value == Skins.Samsung
            ? BorderRadius.circular(25)
            : BorderRadius.circular(0),
        child: StreamBuilder(
            initialData: contacts,
            stream: contactStream,
            builder: (BuildContext context, AsyncSnapshot<List<UniqueContact>> snapshot) {
              List<UniqueContact>? data = snapshot.hasData ? snapshot.data : [];
              return ListView.builder(
                physics: ThemeSwitcher.getScrollPhysics(),
                itemBuilder: (BuildContext context, int index) =>
                    ContactSelectorOption(
                      key: Key("selector-${data![index].displayName}"),
                      item: data[index],
                      onSelected: onSelected,
                      index: index,
                      shouldShowChatType: data.firstWhereOrNull((e) => !(e.chat?.isIMessage ?? true)) != null,
                    ),
                itemCount: data?.length ?? 0,
              );
            }),
      );

  Widget buildChatSelectorHeader() =>
      AppBar(
        toolbarHeight: kIsDesktop ? 30 : 0,
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .secondary,
        leading: null,
        automaticallyImplyLeading: false,
        bottom: cupertino.CupertinoNavigationBar(
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .secondary
              .withOpacity(0.5),
          middle: Container(
            child: Text(
              widget.customHeading ?? "New Message",
              style: Theme
                  .of(context)
                  .textTheme
                  .headline2,
            ),
          ),
          // leading: buildBackButton(context, iconSize: 20),
          trailing: shouldShowAlert
              ? IconButton(
            icon: Icon(
              SettingsManager().settings.skin.value == Skins.iOS
                  ? cupertino.CupertinoIcons.exclamationmark_circle
                  : Icons.error_outline,
              size: 20,
              color: Theme
                  .of(context)
                  .primaryColor,
            ),
            padding: EdgeInsets.zero,
            iconSize: 20,
            constraints: BoxConstraints(maxWidth: 20, maxHeight: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                      backgroundColor: Theme
                          .of(context)
                          .colorScheme
                          .secondary,
                      title: Text("Group Chat Creation",
                          style: TextStyle(color: Theme
                              .of(context)
                              .textTheme
                              .bodyText1!
                              .color)),
                      content: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support for creating group chats currently does not work on MacOS 11 (Big Sur) and up due to limitations imposed by Apple. We hope to soon implement this feature with the Private API.',
                            style: context.theme.textTheme.subtitle1,
                          ),
                        ],
                      ),
                      actions: <Widget>[
                        TextButton(
                            child: Text("OK",
                                style: Theme
                                    .of(context)
                                    .textTheme
                                    .subtitle1!
                                    .apply(color: Theme
                                    .of(context)
                                    .primaryColor)),
                            onPressed: () {
                              Navigator.of(context).pop();
                            }),
                      ]);
                },
              );
            },
          )
              : null,
        ),
      );
}

class UniqueContact {
  final String? displayName;
  final String? label;
  final String? address;
  final Chat? chat;

  bool get isChat => chat != null;

  UniqueContact({this.displayName, this.label, this.address, this.chat});
}
