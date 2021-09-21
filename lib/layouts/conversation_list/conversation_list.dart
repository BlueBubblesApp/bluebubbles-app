import 'dart:async';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/fcm_data.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/blocs/setup_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/logger.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/cupertino_conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/material_conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/samsung_conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ConversationList extends StatefulWidget {
  ConversationList({Key? key, required this.showArchivedChats, required this.showUnknownSenders}) : super(key: key);

  final bool showArchivedChats;
  final bool showUnknownSenders;

  @override
  ConversationListState createState() => ConversationListState();
}

class ConversationListState extends State<ConversationList> {
  Color? currentHeaderColor;
  bool hasPinnedChats = false;

  // ignore: close_sinks
  StreamController<Color?> headerColorStream = StreamController<Color?>.broadcast();

  late ScrollController scrollController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (this.mounted) {
      theme = Colors.transparent;
    }

    SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((e) {
      Logger.error("Error caught while hiding keyboard: ${e.toString()}");
    });
  }

  @override
  void dispose() {
    super.dispose();

    // Remove the scroll listener from the state
    scrollController.removeListener(scrollListener);
  }

  @override
  void initState() {
    super.initState();
    if (!widget.showUnknownSenders) {
      ChatBloc().refreshChats();
    }
    scrollController = ScrollController()..addListener(scrollListener);

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh' && this.mounted) {
        setState(() {});
      }
    });
  }

  Color? get theme => currentHeaderColor;

  set theme(Color? color) {
    if (currentHeaderColor == color) return;
    currentHeaderColor = color;
    if (!headerColorStream.isClosed) headerColorStream.sink.add(currentHeaderColor);
  }

  void scrollListener() {
    !_isAppBarExpanded ? theme = Colors.transparent : theme = context.theme.accentColor.withOpacity(0.5);
  }

  bool get _isAppBarExpanded {
    return scrollController.hasClients && scrollController.offset > (125 - kToolbarHeight);
  }

  List<Widget> getHeaderTextWidgets({double? size, int selected = 0}) {
    TextStyle? style = context.textTheme.headline1;
    if (size != null) style = style!.copyWith(fontSize: size);

    return [Text(widget.showArchivedChats ? "Archive" : widget.showUnknownSenders ? "Unknown Senders" : selected > 0 ? "$selected selected" : "Messages", style: style), Container(width: 10)];
  }

  Widget getSyncIndicatorWidget() {
    return Obx(() {
      if (!SettingsManager().settings.showSyncIndicator.value) return SizedBox.shrink();
      if (!SetupBloc().isSyncing.value) return Container();
      return buildProgressIndicator(context, size: 10);
    });
  }

  void openNewChatCreator({List<PlatformFile>? existing}) async {
    bool shouldShowSnackbar = (await SettingsManager().getMacOSVersion())! >= 11;
    CustomNavigator.pushAndRemoveUntil(
      context,
      ConversationView(
        isCreator: true,
        showSnackbar: shouldShowSnackbar,
        existingAttachments: existing ?? [],
      ),
      (route) => route.isFirst,
    );
  }

  void sortChats() {
    ChatBloc().chats.sort((a, b) {
      if (a.pinIndex.value != null && b.pinIndex.value != null) return a.pinIndex.value!.compareTo(b.pinIndex.value!);
      if (b.pinIndex.value != null) return 1;
      if (a.pinIndex.value != null) return -1;
      if (!a.isPinned! && b.isPinned!) return 1;
      if (a.isPinned! && !b.isPinned!) return -1;
      if (a.latestMessageDate == null && b.latestMessageDate == null) return 0;
      if (a.latestMessageDate == null) return 1;
      if (b.latestMessageDate == null) return -1;
      return -a.latestMessageDate!.compareTo(b.latestMessageDate!);
    });
  }

  Widget buildSettingsButton() => !widget.showArchivedChats && !widget.showUnknownSenders
      ? PopupMenuButton(
          color: context.theme.accentColor,
          onSelected: (dynamic value) {
            if (value == 0) {
              ChatBloc().markAllAsRead();
            } else if (value == 1) {
              CustomNavigator.pushLeft(
                context,
                ConversationList(
                  showArchivedChats: true,
                  showUnknownSenders: false,
                )
              );
            } else if (value == 2) {
              Navigator.of(context).push(
                ThemeSwitcher.buildPageRoute(
                  builder: (BuildContext context) {
                    return SettingsPanel();
                  },
                ),
              );
            } else if (value == 3) {
              CustomNavigator.pushLeft(
                context,
                ConversationList(
                  showArchivedChats: false,
                  showUnknownSenders: true,
                )
              );
            } else if (value == 4) {
              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      "Are you sure?",
                      style: Theme.of(context).textTheme.bodyText1,
                    ),
                    backgroundColor: Theme.of(context).backgroundColor,
                    actions: <Widget>[
                      TextButton(
                        child: Text("Yes"),
                        onPressed: () async {
                          await DBProvider.deleteDB();
                          await SettingsManager().resetConnection();
                          SettingsManager().settings.finishedSetup.value = false;
                          SocketManager().finishedSetup.sink.add(false);
                          Navigator.of(context).popUntil((route) => route.isFirst);
                          SettingsManager().settings = new Settings();
                          SettingsManager().settings.save();
                          SettingsManager().fcmData = null;
                          FCMData.deleteFcmData();
                        },
                      ),
                      TextButton(
                        child: Text("Cancel"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  );
                },
              );
            }
          },
          itemBuilder: (context) {
            return <PopupMenuItem>[
              PopupMenuItem(
                value: 0,
                child: Text(
                  'Mark all as read',
                  style: context.textTheme.bodyText1,
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Text(
                  'Archived',
                  style: context.textTheme.bodyText1,
                ),
              ),
              if (SettingsManager().settings.filterUnknownSenders.value)
                PopupMenuItem(
                  value: 3,
                  child: Text(
                    'Unknown Senders',
                    style: context.textTheme.bodyText1,
                  ),
                ),
              PopupMenuItem(
                value: 2,
                child: Text(
                  'Settings',
                  style: context.textTheme.bodyText1,
                ),
              ),
              if (kIsWeb)
                PopupMenuItem(
                  value: 4,
                  child: Text(
                    'Logout',
                    style: context.textTheme.bodyText1,
                  )
                )
            ];
          },
          child: ThemeSwitcher(
            iOSSkin: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: context.theme.accentColor,
              ),
              child: Icon(
                Icons.more_horiz,
                color: context.theme.primaryColor,
                size: 15,
              ),
            ),
            materialSkin: Icon(
              Icons.more_vert,
              color: context.textTheme.bodyText1!.color,
              size: 25,
            ),
            samsungSkin: Icon(
              Icons.more_vert,
              color: context.textTheme.bodyText1!.color,
              size: 25,
            ),
          ),
        )
      : Container();

  Column buildFloatingActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (SettingsManager().settings.cameraFAB.value)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 45,
              maxHeight: 45,
            ),
            child: FloatingActionButton(
              child: Icon(
                  SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.camera : Icons.photo_camera,
                size: 20,
              ),
              onPressed: () async {
                bool camera = await Permission.camera.isGranted;
                if (!camera) {
                  bool granted = (await Permission.camera.request()) == PermissionStatus.granted;
                  if (!granted) {
                    showSnackbar(
                        "Error",
                        "Camera was denied"
                    );
                    return;
                  }
                }

                String appDocPath = SettingsManager().appDocDir.path;
                String ext = ".png";
                File file = new File("$appDocPath/attachments/" + randomString(16) + ext);
                await file.create(recursive: true);

                // Take the picture after opening the camera
                await MethodChannelInterface().invokeMethod("open-camera", {"path": file.path, "type": "camera"});

                // If we don't get data back, return outta here
                if (!file.existsSync()) return;
                if (file.statSync().size == 0) {
                  file.deleteSync();
                  return;
                }

                openNewChatCreator(existing: [PlatformFile(
                  name: file.path.split("/").last,
                  path: file.path,
                  bytes: file.readAsBytesSync(),
                  size: file.lengthSync(),
                )]);
              },
              heroTag: null,
            ),
          ),
        if (SettingsManager().settings.cameraFAB.value)
          SizedBox(
            height: 10,
          ),
        FloatingActionButton(
            backgroundColor: context.theme.primaryColor,
            child: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.pencil : Icons.message, color: Colors.white, size: 25),
            onPressed: openNewChatCreator),
      ],
    );
  }

  List<Widget> getConnectionIndicatorWidgets() {
    if (!SettingsManager().settings.showConnectionIndicator.value) return [];

    return [Obx(() => getIndicatorIcon(SocketManager().state.value, size: 12)), Container(width: 10.0)];
  }

  @override
  Widget build(BuildContext context) {
    return ThemeSwitcher(
      iOSSkin: CupertinoConversationList(parent: this),
      materialSkin: MaterialConversationList(parent: this),
      samsungSkin: SamsungConversationList(parent: this),
    );
  }
}
