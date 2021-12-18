import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/themes.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/settings/settings_widgets.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PinnedOrderPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Color headerColor;
    Color tileColor;
    if ((Theme.of(context).colorScheme.secondary.computeLuminance() < Theme.of(context).backgroundColor.computeLuminance() ||
        SettingsManager().settings.skin.value == Skins.Material) && (SettingsManager().settings.skin.value != Skins.Samsung || isEqual(Theme.of(context), whiteLightTheme))) {
      headerColor = context.theme.monetNeutralAccentColor(context);
      tileColor = context.theme.monetBackgroundColor(context);
    } else {
      headerColor = context.theme.monetBackgroundColor(context);
      tileColor = context.theme.monetNeutralAccentColor(context);
    }
    if (SettingsManager().settings.skin.value == Skins.iOS && isEqual(Theme.of(context), oledDarkTheme) && !SettingsManager().settings.isMonetEnabled) {
      tileColor = headerColor;
    }

    return SettingsScaffold(
      title: "Pinned Chat Order",
      initialHeader: null,
      iosSubtitle: null,
      materialSubtitle: null,
      tileColor: tileColor,
      headerColor: headerColor,
      actions: [
        TextButton(
            child: Text("RESET",
                style: Theme.of(context)
                    .textTheme
                    .subtitle1!
                    .apply(color: Theme.of(context).primaryColor)),
            onPressed: () {
              ChatBloc().removePinIndices();
            }),
      ],
      bodySlivers: [
        Obx(() => ChatBloc().loadedChatBatch.value && ChatBloc().chats.bigPinHelper(true).isNotEmpty ? SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(13.0),
              child: Text("Set the order of pinned chats by dragging the chat tile to the desired location."),
            ),
          ),
        ) : SliverToBoxAdapter(child: SizedBox.shrink())),
        Obx(() {
          if (!ChatBloc().loadedChatBatch.value) {
            return SliverToBoxAdapter(
              child: Center(
                child: Container(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Loading chats...",
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                      ),
                      buildProgressIndicator(context, size: 15),
                    ],
                  ),
                ),
              ),
            );
          }
          if (ChatBloc().loadedChatBatch.value && ChatBloc().chats.bigPinHelper(true).isEmpty) {
            return SliverToBoxAdapter(
              child: Center(
                child: Container(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Text(
                    "You have no pinned chats :(",
                    style: Theme.of(context).textTheme.subtitle1,
                  ),
                ),
              ),
            );
          }

          return SliverReorderableList(
            onReorder: ChatBloc().updateChatPinIndex,
            itemBuilder: (context, index) {
              return AbsorbPointer(
                key: Key(ChatBloc().chats.bigPinHelper(true)[index].guid.toString()),
                absorbing: true,
                child: ConversationTile(
                  chat: ChatBloc().chats.bigPinHelper(true)[index],
                  inSelectMode: true,
                  onSelect: (_) {},
                ),
              );
            },
            itemCount: ChatBloc().chats.bigPinHelper(true).length,
          );
        }),
      ]
    );
  }
}