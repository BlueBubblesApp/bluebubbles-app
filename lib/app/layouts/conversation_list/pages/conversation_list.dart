import 'dart:async';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/footer/samsung_footer.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/samsung_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/initial_widget_right.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/material_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/samsung_conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/tablet_mode_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' hide context;
import 'package:permission_handler/permission_handler.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/cupertino_conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/material_conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/samsung_conversation_list.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class ConversationListController extends StatefulController {
  final bool showArchivedChats;
  final bool showUnknownSenders;
  final ScrollController iosScrollController = ScrollController();
  final ScrollController materialScrollController = ScrollController();
  final ScrollController samsungScrollController = ScrollController();
  final List<String> selectedChats = [];
  bool showMaterialFABText = true;
  double materialScrollStartPosition = 0;

  ConversationListController({required this.showArchivedChats, required this.showUnknownSenders});

  void updateSelectedChats() {
    if (ss.settings.skin.value == Skins.Material) {
      updateWidgets<MaterialHeader>(null);
      updateMaterialFAB();
    } else if (ss.settings.skin.value == Skins.Samsung) {
      updateWidgets<SamsungFooter>(null);
      updateWidgets<ExpandedHeaderText>(null);
    }
  }

  void clearSelectedChats() {
    for (String c in List<String>.from(selectedChats)) {
      selectedChats.removeWhere((element) => element == c);
      Get.find<ConversationTileController>(tag: c).updateWidgets<MaterialConversationTile>(null);
      Get.find<ConversationTileController>(tag: c).updateWidgets<SamsungConversationTile>(null);
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

    final file = await ImagePicker().pickImage(source: ImageSource.camera);
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
    ns.pushAndRemoveUntil(
      context,
      ChatCreator(initialAttachments: existing ?? []),
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
  @override
  void initState() {
    super.initState();
    tag = controller.showArchivedChats
        ? "Archived"
        : controller.showUnknownSenders
            ? "Unknown"
            : "Messages";

    if (!ss.settings.reachedConversationList.value) {
      Timer.periodic(const Duration(seconds: 1), (Timer t) {
        bool notInSettings = ns.isTabletMode(context)
            ? !Get.keys.containsKey(3) || Get.keys[3]?.currentContext == null
            : Get.rawRoute?.settings.name == "/";
        // This only runs once
        if (notInSettings) {
          ss.settings.reachedConversationList.value = true;
          ss.saveSettings();
          ss.getServerDetails(refresh: true);
          t.cancel();
        }
      });
    }

    // Extra safety check to make sure Android doesn't open the last chat when opening the app
    if (kIsDesktop || kIsWeb) {
      String? lastOpenedChat = ss.prefs.getString('lastOpenedChat');
      if (lastOpenedChat != null &&
          showAltLayoutContextless &&
          GlobalChatService.activeGuid.value != ss.prefs.getString('lastOpenedChat') &&
          !ls.isBubble) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (kIsWeb) {
            await GlobalChatService.chatsLoadedFuture.future;
          }

          GlobalChatService.openChat(lastOpenedChat);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ThemeSwitcher(
      iOSSkin: CupertinoConversationList(parentController: controller),
      materialSkin: MaterialConversationList(parentController: controller),
      samsungSkin: SamsungConversationList(parentController: controller),
    );

    if (controller.showArchivedChats || controller.showUnknownSenders) return child;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: brightness.opposite,
      ),
      child: TabletModeWrapper(
        initialRatio: 0.4,
        minWidthLeft: kIsDesktop || kIsWeb ? 150 : null,
        minRatio: kIsDesktop || kIsWeb ? 0.1 : 0.33,
        maxRatio: 0.5,
        allowResize: true,
        left: !showAltLayout
            ? child
            : LayoutBuilder(builder: (context, constraints) {
                ns.maxWidthLeft = constraints.maxWidth;
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
                          if (GlobalChatService.hasActiveChat) {
                            cvc(GlobalChatService.activeGuid.value!).close();
                          }
                          eventDispatcher.emit('update-highlight', null);
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
            ns.maxWidthRight = constraints.maxWidth;
            return PopScope(
              canPop: false,
              onPopInvoked: (_) async {
                Get.back(id: 2);
              },
              child: Navigator(
                key: Get.nestedKey(2),
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
