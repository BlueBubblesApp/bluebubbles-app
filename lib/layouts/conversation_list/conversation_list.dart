import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/layouts/setup/setup_view.dart';
import 'package:bluebubbles/layouts/titlebar_wrapper.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/sync/incremental_sync_manager.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:bluebubbles/repository/tasks/sync_tasks.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

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
import 'package:bluebubbles/layouts/settings/settings_panel.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/event_dispatcher.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/socket_manager.dart';
import 'package:bluebubbles/main.dart';
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
    TextStyle? style = context.textTheme.headlineLarge!.copyWith(color: context.theme.colorScheme.onBackground, fontWeight: FontWeight.w500);
    if (size != null) style = style.copyWith(fontSize: size);

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
        showSnackbar("Error", "Camera was denied");
        return;
      }
    }

    final XFile? file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file != null) {
      openNewChatCreator(existing: [PlatformFile(
        path: file.path,
        name: file.path.split('/').last,
        size: await file.length(),
        bytes: await file.readAsBytes(),
      )]);
    }
  }

  Widget buildSettingsButton() => !widget.showArchivedChats && !widget.showUnknownSenders
      ? PopupMenuButton(
          color: context.theme.colorScheme.properSurface,
          shape: SettingsManager().settings.skin.value != Skins.Material ? RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(20.0),
            ),
          ) : null,
          onSelected: (dynamic value) {
            if (value == 0) {
              ChatBloc().markAllAsRead();
            } else if (value == 1) {
              CustomNavigator.pushLeft(
                  context,
                  ConversationList(
                    showArchivedChats: true,
                    showUnknownSenders: false,
                  ));
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
                  ));
            } else if (value == 4) {
              showDialog(
                barrierDismissible: false,
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      "Are you sure?",
                      style: context.theme.textTheme.titleLarge,
                    ),
                    backgroundColor: context.theme.colorScheme.properSurface,
                    actions: <Widget>[
                      TextButton(
                        child: Text("No", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text("Yes", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                        onPressed: () async {
                          await DBProvider.deleteDB();
                          await SettingsManager().resetConnection();
                          SettingsManager().settings = Settings();
                          SettingsManager().settings.save();
                          SettingsManager().fcmData = null;
                          FCMData.deleteFcmData();
                          prefs.setString("selected-dark", "OLED Dark");
                          prefs.setString("selected-light", "Bright White");
                          themeBox.putMany(Themes.defaultThemes);
                          loadTheme(context);
                          Get.offAll(() => WillPopScope(
                            onWillPop: () async => false,
                            child: TitleBarWrapper(child: SetupView()),
                          ), duration: Duration.zero, transition: Transition.noTransition);
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
                  'Mark All As Read',
                  style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Text(
                  'Archived',
                  style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                ),
              ),
              if (SettingsManager().settings.filterUnknownSenders.value)
                PopupMenuItem(
                  value: 3,
                  child: Text(
                    'Unknown Senders',
                    style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                  ),
                ),
              PopupMenuItem(
                value: 2,
                child: Text(
                  'Settings',
                  style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                ),
              ),
              if (kIsWeb)
                PopupMenuItem(
                    value: 4,
                    child: Text(
                      'Logout',
                      style: context.textTheme.bodyLarge!.apply(color: context.theme.colorScheme.properOnSurface),
                    ))
            ];
          },
          icon: SettingsManager().settings.skin.value == Skins.Material ? Icon(
                  Icons.more_vert,
                  color: context.theme.colorScheme.onBackground,
                  size: 25,
                ) : null,
          child: SettingsManager().settings.skin.value == Skins.Material
              ? null
              : ThemeSwitcher(
                  iOSSkin: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      color: context.theme.colorScheme.properSurface,
                    ),
                    child: Icon(
                      Icons.more_horiz,
                      color: context.theme.colorScheme.properOnSurface,
                      size: 20,
                    ),
                  ),
                  materialSkin: Container(),
                  samsungSkin: Icon(
                    Icons.more_vert,
                    color: context.theme.colorScheme.onBackground,
                    size: 25,
                  ),
                ),
        )
      : Container();

  Widget buildFloatingActionButton() {
    return Obx(() => Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (SettingsManager().settings.cameraFAB.value && SettingsManager().settings.skin.value == Skins.iOS)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 45,
                  maxHeight: 45,
                ),
                child: FloatingActionButton(
                  child: Icon(
                    SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.camera : Icons.photo_camera,
                    size: 20,
                    color: context.theme.colorScheme.onPrimaryContainer
                  ),
                  onPressed: openCamera,
                  heroTag: null,
                    backgroundColor: context.theme.colorScheme.primaryContainer,
                ),
              ),
            if (SettingsManager().settings.cameraFAB.value && SettingsManager().settings.skin.value == Skins.iOS)
              SizedBox(
                height: 10,
              ),
            InkWell(
              onLongPress: SettingsManager().settings.skin.value == Skins.iOS || !SettingsManager().settings.cameraFAB.value ? null : openCamera,
              child: FloatingActionButton(
                  backgroundColor: context.theme.colorScheme.primary,
                  child: Icon(SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.pencil : Icons.message,
                      color: context.theme.colorScheme.onPrimary, size: 25),
                  onPressed: openNewChatCreator,
              ),
            ),
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
