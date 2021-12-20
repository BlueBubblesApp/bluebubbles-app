import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class PinnedOrderPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: SettingsManager().settings.immersiveMode.value ? Colors.transparent : Theme.of(context).backgroundColor, // navigation bar color
        systemNavigationBarIconBrightness:
        Theme.of(context).backgroundColor.computeLuminance() > 0.5 ? Brightness.dark : Brightness.light,
        statusBarColor: Colors.transparent, // status bar color
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: PreferredSize(
          preferredSize: Size(CustomNavigator.width(context), 80),
          child: ClipRRect(
            child: BackdropFilter(
              child: AppBar(
                systemOverlayStyle: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor) == Brightness.dark
                    ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: Theme.of(context).backgroundColor.withOpacity(0.5),
                title: Text(
                  "Pinned Chat Order",
                  style: Theme.of(context).textTheme.headline1,
                ),
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
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: context.height - 80,
          ),
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(
              parent: CustomBouncingScrollPhysics(),
            ),
            child: Column(
              children: <Widget>[
                Obx(() {
                  if (!ChatBloc().loadedChatBatch.value) {
                    return Center(
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
                    );
                  }
                  if (ChatBloc().hasChats.value && ChatBloc().chats.bigPinHelper(true).isEmpty) {
                    return Center(
                      child: Container(
                        padding: EdgeInsets.only(top: 50.0),
                        child: Text(
                          "You have no pinned chats :(",
                          style: Theme.of(context).textTheme.subtitle1,
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
                      child: Text("Set the order of pinned chats by dragging the chat tile to the desired location."),
                    ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}