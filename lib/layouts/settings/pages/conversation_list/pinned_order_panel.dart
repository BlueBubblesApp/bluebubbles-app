import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class PinnedOrderPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Rx<Color> _backgroundColor = (settings.settings.windowEffect.value == WindowEffect.disabled ? context.theme.colorScheme.background : Colors.transparent).obs;

    if (kIsDesktop) {
      settings.settings.windowEffect.listen((WindowEffect effect) =>
      _backgroundColor.value = effect != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: settings.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Obx(() => Scaffold(
        backgroundColor: _backgroundColor.value,
        appBar: PreferredSize(
          preferredSize: Size(navigatorService.width(context), 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                systemOverlayStyle: ThemeData.estimateBrightnessForColor(context.theme.colorScheme.background) == Brightness.dark
                    ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                toolbarHeight: kIsDesktop ? 80 : 50,
                elevation: 0,
                scrolledUnderElevation: 3,
                surfaceTintColor: context.theme.colorScheme.primary,
                leading: buildBackButton(context),
                backgroundColor: context.theme.colorScheme.background,
                centerTitle: settings.settings.skin.value == Skins.iOS,
                title: Text(
                  "Pinned Chat Order",
                  style: context.theme.textTheme.titleLarge,
                ),
                actions: [
                  TextButton(
                      child: Text("Reset", style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                      onPressed: () {
                        ChatBloc().removePinIndices();
                      }),
                ],
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: SingleChildScrollView(
          physics: ThemeSwitcher.getScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Obx(() {
                if (!ChatBloc().loadedChatBatch.value) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Loading chats...",
                              style: context.theme.textTheme.labelLarge,
                            ),
                          ),
                          buildProgressIndicator(context, size: 15),
                        ],
                      ),
                    ),
                  );
                }
                if (ChatBloc().hasChats.value && ChatBloc().chats.bigPinHelper(true).isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: Text(
                        "You have no pinned chats :(",
                        style: context.theme.textTheme.labelLarge,
                      ),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  onReorder: ChatBloc().updateChatPinIndex,
                  header: Padding(
                    padding: const EdgeInsets.all(13.0),
                    child: Text("Set the order of pinned chats by dragging the chat tile to the desired location.", style: context.theme.textTheme.bodyLarge),
                  ),
                  itemBuilder: (context, index) {
                    return AbsorbPointer(
                      key: Key(ChatBloc().chats.bigPinHelper(true)[index].guid.toString()),
                      absorbing: true,
                      child: ConversationTile(
                        chat: ChatBloc().chats.bigPinHelper(true)[index],
                        controller: Get.put(
                          ConversationListController(showUnknownSenders: true, showArchivedChats: true),
                          tag: "pinned-order-panel"
                        ),
                        inSelectMode: true,
                        onSelect: (_) {},
                      ),
                    );
                  },
                  itemCount: ChatBloc().chats.bigPinHelper(true).length,
                );
              }),
            ],
          ),
        ),
      )),
    );
  }
}