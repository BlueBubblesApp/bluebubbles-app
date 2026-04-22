import 'dart:async';

import 'package:bluebubbles/app/layouts/camera/camera_screen.dart';
import 'package:bluebubbles/app/layouts/chat_creator/new_chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/footer/samsung_footer.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/samsung_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/initial_widget_right.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/material_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/samsung_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/app/wrappers/bb_annotated_region.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/tablet_mode_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' hide context;
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/cupertino_conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/material_conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/samsung_conversation_list.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ConversationListController extends StatefulController {
  final bool showArchivedChats;
  final bool showUnknownSenders;
  final ScrollController iosScrollController = ScrollController();
  final ScrollController materialScrollController = ScrollController();
  final ScrollController samsungScrollController = ScrollController();
  final List<Chat> selectedChats = [];
  bool showMaterialFABText = true;
  double materialScrollStartPosition = 0;

  ConversationListController({required this.showArchivedChats, required this.showUnknownSenders});

  void updateSelectedChats() {
    if (SettingsSvc.settings.skin.value == Skins.Material) {
      updateWidgets<MaterialHeader>(null);
      updateMaterialFAB();
    } else if (SettingsSvc.settings.skin.value == Skins.Samsung) {
      updateWidgets<SamsungFooter>(null);
      updateWidgets<ExpandedHeaderText>(null);
    }
  }

  void clearSelectedChats() {
    final copy = List.from(selectedChats);
    for (Chat c in copy) {
      selectedChats.removeWhere((element) => element.guid == c.guid);
      Get.find<ConversationTileController>(tag: c.guid).updateWidgets<MaterialConversationTile>(null);
      Get.find<ConversationTileController>(tag: c.guid).updateWidgets<SamsungConversationTile>(null);
    }
    updateSelectedChats();
  }

  void updateMaterialFAB() {
    updateWidgets<ConversationListFAB>(null);
  }

  void openCamera(BuildContext context) async {
    bool camera = await Permission.camera.isGranted;
    if (!camera) {
      bool granted = (await Permission.camera.request()) == PermissionStatus.granted;
      if (!granted) {
        showSnackbar("Error", "Camera was denied");
        return;
      }
    }

    final XFile? file;
    if (Platform.isAndroid && !kIsWeb) {
      file = await Navigator.of(context).push<XFile?>(
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    } else {
      file = await ImagePicker().pickImage(source: ImageSource.camera);
    }
    if (file == null) return;

    openNewChatCreator(context, existing: [
      PlatformFile(
        name: basename(file.path),
        path: file.path,
        bytes: await file.readAsBytes(),
        size: await file.length(),
      )
    ]);
  }

  void openNewChatCreator(BuildContext context, {List<PlatformFile>? existing}) async {
    NavigationSvc.pushAndRemoveUntil(
      context,
      NewChatCreator(initialAttachments: existing ?? []),
      (route) => route.isFirst,
    );
  }
}

class ConversationList extends CustomStateful<ConversationListController> {
  ConversationList({super.key, required bool showArchivedChats, required bool showUnknownSenders})
      : super(
            parentController: Get.put(
                ConversationListController(
                  showArchivedChats: showArchivedChats,
                  showUnknownSenders: showUnknownSenders,
                ),
                tag: showArchivedChats
                    ? "Archived"
                    : showUnknownSenders
                        ? "Unknown"
                        : "Messages"));

  @override
  State<StatefulWidget> createState() => _ConversationListState();
}

class _ConversationListState extends CustomState<ConversationList, void, ConversationListController> {
  Timer? _initTimer;

  @override
  void initState() {
    super.initState();
    tag = controller.showArchivedChats
        ? "Archived"
        : controller.showUnknownSenders
            ? "Unknown"
            : "Messages";

    if (!SettingsSvc.settings.reachedConversationList.value) {
      _initTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (!mounted) {
          t.cancel();
          return;
        }

        bool notInSettings = NavigationSvc.isTabletMode(context)
            ? !Get.keys.containsKey(3) || Get.keys[3]?.currentContext == null
            : Get.rawRoute?.settings.name == "/";
        // This only runs once
        if (notInSettings) {
          SettingsSvc.settings.reachedConversationList.value = true;
          SettingsSvc.settings.saveOneAsync('reachedConversationList');
          t.cancel();
        }
      });
    }

    // Extra safety check to make sure Android doesn't open the last chat when opening the app
    if (kIsDesktop || kIsWeb) {
      if (PrefsSvc.i.getString('lastOpenedChat') != null &&
          showAltLayoutContextless &&
          ChatsSvc.activeChat?.chat.guid != PrefsSvc.i.getString('lastOpenedChat') &&
          !LifecycleSvc.isBubble) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (kIsWeb) {
            await ChatsSvc.loadedAllChats.future;
          }
          NavigationSvc.pushAndRemoveUntil(
            context,
            ConversationView(
                chat: kIsWeb
                    ? (await Chat.findOneWeb(guid: PrefsSvc.i.getString('lastOpenedChat')))!
                    : Chat.findOne(guid: PrefsSvc.i.getString('lastOpenedChat'))!),
            (route) => route.isFirst,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = ThemeSwitcher(
      iOSSkin: CupertinoConversationList(parentController: controller),
      materialSkin: MaterialConversationList(parentController: controller),
      samsungSkin: SamsungConversationList(parentController: controller),
    );

    if (controller.showArchivedChats || controller.showUnknownSenders) return child;

    return BBAnnotatedRegion(
      systemNavigationBarIconBrightness: brightness,
      statusBarIconBrightness: brightness.opposite,
      child: TabletModeWrapper(
        initialRatio: 0.4,
        minWidthLeft: kIsDesktop || kIsWeb ? 150 : null,
        minRatio: kIsDesktop || kIsWeb ? 0.1 : 0.33,
        maxRatio: 0.5,
        allowResize: true,
        left: !showAltLayout
            ? child
            : LayoutBuilder(builder: (context, constraints) {
                NavigationSvc.maxWidthLeft = constraints.maxWidth;
                return PopScope(
                  canPop: false,
                  onPopInvoked: (_) async {
                    Get.until((route) {
                      bool id2result = false;
                      // check if we should pop the left side first
                      Get.until((route) {
                        if (route.settings.name != "initial") {
                          Get.back(id: 2);
                          id2result = true;
                        }
                        if (!(Get.global(2).currentState?.canPop() ?? true)) {
                          if (ChatsSvc.activeChat != null) {
                            cvc(ChatsSvc.activeChat!.chat).close();
                          }
                          EventDispatcherSvc.emit('update-highlight', null);
                        }
                        return true;
                      }, id: 2);
                      if (!id2result) {
                        if (route.settings.name == "initial") {
                          SystemNavigator.pop();
                        } else {
                          Get.back(id: 1);
                        }
                      }
                      return true;
                    }, id: 1);
                  },
                  child: Navigator(
                    key: Get.nestedKey(1),
                    requestFocus: false,
                    onPopPage: (route, _) {
                      return false;
                    },
                    pages: [
                      CupertinoPage(
                        name: "initial",
                        child: child,
                      )
                    ],
                  ),
                );
              }),
        right: LayoutBuilder(
          builder: (context, constraints) {
            NavigationSvc.maxWidthRight = constraints.maxWidth;
            return PopScope(
              canPop: false,
              onPopInvoked: (_) async {
                Get.back(id: 2);
              },
              child: Navigator(
                key: Get.nestedKey(2),
                // Prevent the Navigator from auto-claiming focus when a new route is
                // pushed — ConversationTextFieldState.initState() explicitly requests
                // focus on the text field via addPostFrameCallback (#2754).
                requestFocus: false,
                onPopPage: (route, _) {
                  return false;
                },
                pages: [
                  const CupertinoPage(
                    name: "initial",
                    child: InitialWidgetRight(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
