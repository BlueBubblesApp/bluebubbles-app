import 'package:bluebubbles/layouts/setup/setup_view.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

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
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (kIsDesktop && !widget.showUnknownSenders) {
      ChatBloc().refreshChats();
    }

    SystemChannels.textInput.invokeMethod('TextInput.hide').catchError((e) {
      Logger.error("Error caught while hiding keyboard: ${e.toString()}");
    });

    // Listen for any incoming events
    EventDispatcher().stream.listen((Map<String, dynamic> event) {
      if (!event.containsKey("type")) return;

      if (event["type"] == 'refresh' && mounted) {
        setState(() {});
      }

      if (event["type"] == 'theme-update' && mounted) {
        setState(() {});
      }
    });
  }

  Widget getHeaderTextWidget({double? size}) {
    TextStyle? style = context.textTheme.headline1;
    if (size != null) style = style!.copyWith(fontSize: size);

    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: Text(
          widget.showArchivedChats
              ? "Archive"
              : widget.showUnknownSenders
                  ? "Unknown Senders"
                  : "Messages",
          style: style),
    );
  }

  Widget getSyncIndicatorWidget() {
    return Obx(() {
      if (!SettingsManager().settings.showSyncIndicator.value) return SizedBox.shrink();
      if (!SetupBloc().isIncrementalSyncing.value) return Container();
      return buildProgressIndicator(context, size: 12);
    });
  }

  void openNewChatCreator({List<PlatformFile>? existing}) async {
    EventDispatcher().emit("update-highlight", null);
    CustomNavigator.pushAndRemoveUntil(
      context,
      ConversationView(
        isCreator: true,
        existingAttachments: existing ?? [],
      ),
      (route) => route.isFirst,
    );
  }

  void openCamera() async {
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
    File file = File("$appDocPath/attachments/" + randomString(16) + ext);
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
  }

  Widget buildSettingsButton() => !widget.showArchivedChats && !widget.showUnknownSenders
      ? PopupMenuButton(
          color: context.theme.colorScheme.secondary,
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
                          Get.offAll(() => WillPopScope(
                              onWillPop: () async => false,
                              child: TitleBarWrapper(child: SetupView()),
                            ),
                            duration: Duration.zero,
                            transition: Transition.noTransition
                          );
                          SettingsManager().settings = Settings();
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
          icon: SettingsManager().settings.skin.value == Skins.Material ? Icon(
            Icons.more_vert,
            color: context.textTheme.bodyText1!.color,
            size: 25,
          ) : null,
          child: SettingsManager().settings.skin.value == Skins.Material ? null : ThemeSwitcher(
            iOSSkin: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                color: context.theme.colorScheme.secondary,
              ),
              child: Icon(
                Icons.more_horiz,
                color: context.theme.primaryColor,
                size: 15,
              ),
            ),
            materialSkin: Container(),
            samsungSkin: Icon(
              Icons.more_vert,
              color: context.textTheme.bodyText1!.color,
              size: 25,
            ),
          ),
        )
      : Container();

  Widget buildFloatingActionButton() {
    return Obx(() => Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (SettingsManager().settings.cameraFAB.value && SettingsManager().settings.skin.value != Skins.Material)
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
              onPressed: openCamera,
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
    ));
  }

  Widget getConnectionIndicatorWidget() {
    if (!SettingsManager().settings.showConnectionIndicator.value) return Container();

    return Obx(() => Padding(
          padding: EdgeInsets.only(right: SettingsManager().settings.skin.value != Skins.Material ? 10 : 0.0),
      child: getIndicatorIcon(SocketManager().state.value, size: 12),
    ));
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
