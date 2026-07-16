import 'dart:async';

import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/layouts/chat_creator/new_chat_creator.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/conversation_list_fab.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/footer/samsung_footer.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/material_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/samsung_header.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/initial_widget_right.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/material_conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/samsung_conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
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
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

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

    final XFile? file = await ImagePicker().pickImage(source: ImageSource.camera);
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

class _ConversationListState extends CustomState<ConversationList, void, ConversationListController>
    with WidgetsBindingObserver {
  Timer? _initTimer;

  @override
  void initState() {
    super.initState();
    tag = controller.showArchivedChats
        ? "Archived"
        : controller.showUnknownSenders
            ? "Unknown"
            : "Messages";

    if (!kIsWeb && !controller.showArchivedChats && !controller.showUnknownSenders) {
      WidgetsBinding.instance.addObserver(this);
      ChatsSvc.loadedAllChats.future.then((_) => _precacheAvatars());
    }

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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-warm the avatar image cache after a resume — the OS may have cleared
    // Flutter's ImageCache (memory trim) while the app was backgrounded.
    if (state == AppLifecycleState.resumed) _precacheAvatars();
  }

  /// Decodes the avatars for the top chats into Flutter's ImageCache so tiles
  /// render them synchronously instead of falling back to initials while the
  /// file decodes. The ResizeImage params must exactly match what
  /// ContactAvatarWidget passes to Image.file, or the warmed entries are never hit.
  void _precacheAvatars() {
    if (!mounted) return;
    const decodeSize = ContactAvatarWidget.avatarDecodeSize;
    for (final chat in ChatsSvc.allChats.take(30)) {
      final state = ChatsSvc.getChatState(chat.guid);
      if (state == null) continue;
      final customPath = state.customAvatarPath.value;
      if (customPath != null) {
        // Group custom avatars render unresized (CircleAvatar + FileImage).
        unawaited(precacheImage(FileImage(File(customPath)), context));
        continue;
      }
      for (final hs in state.participants) {
        final path = hs.avatarPath.value;
        if (path == null) continue;
        unawaited(precacheImage(
          ResizeImage(FileImage(File(path)), width: decodeSize, height: decodeSize),
          context,
        ));
      }
    }
  }

  @override
  void dispose() {
    _initTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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

    return BBScaffold(
      safeAreaLeft: false,
      safeAreaRight: false,
      body: TabletModeWrapper(
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
                  onPopInvokedWithResult: <T>(bool _, T? __) async {
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
              onPopInvokedWithResult: <T>(bool _, T? __) async {
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
