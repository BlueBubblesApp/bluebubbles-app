import 'package:universal_io/io.dart';
import 'dart:ui';

import 'package:bluebubbles/blocs/chat_bloc.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/layouts/conversation_list/conversation_tile.dart';
import 'package:bluebubbles/layouts/widgets/avatar_crop.dart';
import 'package:get/get.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomAvatarPanelBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CustomAvatarPanelController>(() => CustomAvatarPanelController());
  }
}

class CustomAvatarPanelController extends GetxController {
  late Settings _settingsCopy;

  @override
  void onInit() {
    super.onInit();
    _settingsCopy = SettingsManager().settings;
  }

  @override
  void dispose() {
    SettingsManager().saveSettings(_settingsCopy);
    super.dispose();
  }
}

class CustomAvatarPanel extends GetView<CustomAvatarPanelController> {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).backgroundColor, // navigation bar color
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
                brightness: ThemeData.estimateBrightnessForColor(Theme.of(context).backgroundColor),
                toolbarHeight: 100.0,
                elevation: 0,
                leading: buildBackButton(context),
                backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
                title: Text(
                  "Custom Avatars",
                  style: Theme.of(context).textTheme.headline1,
                ),
              ),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            ),
          ),
        ),
        body: CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(
            parent: CustomBouncingScrollPhysics(),
          ),
          slivers: <Widget>[
            Obx(() {
              if (!ChatBloc().loadedChats.value) {
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
              if (ChatBloc().loadedChats.value && ChatBloc().chats.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.only(top: 50.0),
                      child: Text(
                        "You have no chats :(",
                        style: Theme.of(context).textTheme.subtitle1,
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    return ConversationTile(
                      key: Key(
                          ChatBloc().chats[index].guid.toString()),
                      chat: ChatBloc().chats[index],
                      inSelectMode: true,
                      onSelect: (_) {
                        if (ChatBloc().chats[index].customAvatarPath.value != null) {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                  backgroundColor: Theme.of(context).accentColor,
                                  title: new Text("Custom Avatar",
                                      style:
                                      TextStyle(color: Theme.of(context).textTheme.bodyText1!.color)),
                                  content: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          "You have already set a custom avatar for this chat. What would you like to do?",
                                          style: Theme.of(context).textTheme.bodyText1),
                                    ],
                                  ),
                                  actions: <Widget>[
                                    TextButton(
                                        child: Text("Cancel",
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle1!
                                                .apply(color: Theme.of(context).primaryColor)),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        }),
                                    TextButton(
                                        child: Text("Reset",
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle1!
                                                .apply(color: Theme.of(context).primaryColor)),
                                        onPressed: () {
                                          File file = new File(ChatBloc().chats[index].customAvatarPath.value!);
                                          file.delete();
                                          ChatBloc().chats[index].customAvatarPath.value = null;
                                          ChatBloc().chats[index].save();
                                          Navigator.of(context).pop();
                                        }),
                                    TextButton(
                                        child: Text("Set New",
                                            style: Theme.of(context)
                                                .textTheme
                                                .subtitle1!
                                                .apply(color: Theme.of(context).primaryColor)),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          CustomNavigator.pushSettings(
                                            context,
                                            AvatarCrop(),
                                          );
                                        }),
                                  ]);
                            },
                          );
                        } else {
                          CustomNavigator.pushSettings(
                            context,
                            AvatarCrop(),
                          );
                        }
                      },
                    );
                  },
                  childCount: ChatBloc().chats.length,
                ),
              );
            }),
            SliverList(
              delegate: SliverChildListDelegate(
                <Widget>[],
              ),
            )
          ],
        ),
      ),
    );
  }
}
