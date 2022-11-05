import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/footer/samsung_footer.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/samsung_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/initial_widget_right.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/material_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/samsung_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_view/conversation_view.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/tablet_mode_wrapper.dart';
import 'package:bluebubbles/services/ui/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/cupertino_conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/material_conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/samsung_conversation_list.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
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
  final List<Chat> selectedChats = [];
  bool showMaterialFABText = true;
  double materialScrollStartPosition = 0;

  ConversationListController({required this.showArchivedChats, required this.showUnknownSenders});

  void updateSelectedChats() {
    if (ss.settings.skin.value == Skins.Material) {
      updateWidgetFunctions[MaterialHeader]?.call(null);
      updateMaterialFAB();
    } else if (ss.settings.skin.value == Skins.Samsung) {
      updateWidgetFunctions[SamsungFooter]?.call(null);
      updateWidgetFunctions[ExpandedHeaderText]?.call(null);
    }
  }

  void clearSelectedChats() {
    final copy = List.from(selectedChats);
    for (Chat c in copy) {
      selectedChats.removeWhere((element) => element.guid == c.guid);
      Get.find<ConversationTileController>(tag: c.guid).updateWidgetFunctions[MaterialConversationTile]?.call(null);
      Get.find<ConversationTileController>(tag: c.guid).updateWidgetFunctions[SamsungConversationTile]?.call(null);
    }
    updateSelectedChats();
  }

  void updateMaterialFAB() {
    updateWidgetFunctions[ConversationListFAB]?.call(null);
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

    File file = File("${fs.appDocDir.path}/attachments/${randomString(16)}.png");
    await file.create(recursive: true);
    await mcs.invokeMethod("open-camera", {"path": file.path, "type": "camera"});

    if (!(await file.exists())) return;
    if ((await file.length()) == 0) {
      await file.delete();
      return;
    }

    openNewChatCreator(context, existing: [
      PlatformFile(
        name: file.path.split("/").last,
        path: file.path,
        bytes: await file.readAsBytes(),
        size: await file.length(),
      )
    ]);
  }

  void openNewChatCreator(BuildContext context, {List<PlatformFile>? existing}) async {
    eventDispatcher.emit("update-highlight", null);
    /*ns.pushAndRemoveUntil(
      context,
      ConversationView(
        isCreator: true,
        existingAttachments: existing ?? [],
      ),
      (route) => route.isFirst,
    )*/;
  }
}

class ConversationList extends CustomStateful<ConversationListController> {
  ConversationList({
    Key? key,
    required bool showArchivedChats,
    required bool showUnknownSenders
  }) : super(key: key, parentController: Get.put(ConversationListController(
    showArchivedChats: showArchivedChats,
    showUnknownSenders: showUnknownSenders,
  ), tag: showArchivedChats ? "Archived" : showUnknownSenders ? "Unknown" : "Messages"));

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

    if (ss.prefs.getString('lastOpenedChat') != null &&
        showAltLayoutContextless &&
        cm.activeChat?.chat.guid != ss.prefs.getString('lastOpenedChat') &&
        !ls.isBubble) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        ns.pushAndRemoveUntil(
          context,
          ConversationView(
            chat: kIsWeb
                ? (await Chat.findOneWeb(guid: ss.prefs.getString('lastOpenedChat')))!
                : Chat.findOne(guid: ss.prefs.getString('lastOpenedChat'))!),
          (route) => route.isFirst,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ThemeSwitcher(
      iOSSkin: CupertinoConversationList(parentController: controller),
      materialSkin: MaterialConversationList(parentController: controller),
      samsungSkin: SamsungConversationList(parentController: controller),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value
            ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: brightness.opposite,
      ),
      child: TabletModeWrapper(
        initialRatio: 0.4,
        minRatio: kIsDesktop || kIsWeb ? 0.2 : 0.33,
        maxRatio: 0.5,
        allowResize: true,
        left: !showAltLayout ? child : LayoutBuilder(
          builder: (context, constraints) {
            ns.maxWidthLeft = constraints.maxWidth;
            return WillPopScope(
              onWillPop: () async {
                Get.until((route) {
                  bool id2result = false;
                  // check if we should pop the left side first
                  Get.until((route) {
                    if (route.settings.name != "initial") {
                      Get.back(id: 2);
                      id2result = true;
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
                return false;
              },
              child: Navigator(
                key: Get.nestedKey(1),
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
          }
        ),
        right: LayoutBuilder(
          builder: (context, constraints) {
            ns.maxWidthRight = constraints.maxWidth;
            return WillPopScope(
              onWillPop: () async {
                Get.back(id: 2);
                return false;
              },
              child: Navigator(
                key: Get.nestedKey(2),
                onPopPage: (route, _) {
                  return false;
                },
                pages: [
                  CupertinoPage(
                    name: "initial",
                    child: const InitialWidgetRight(),
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
