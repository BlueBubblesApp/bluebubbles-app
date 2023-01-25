import 'dart:ui';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/wrappers/fade_on_scroll.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CupertinoHeader extends StatelessWidget {
  const CupertinoHeader({Key? key, required this.controller});

  final ConversationListController controller;

  @override
  Widget build(BuildContext context) {
    final double topMargin = context.orientation == Orientation.landscape && context.isPhone
        ? 20
        : kIsDesktop || kIsWeb
        ? 40
        : kToolbarHeight + 30;

    return SliverToBoxAdapter(
      child: FadeOnScroll(
        scrollController: controller.iosScrollController,
        zeroOpacityOffset: topMargin + 15,
        child: Container(
          margin: EdgeInsets.only(
            top: topMargin,
            left: 20,
            right: 20,
            bottom: 5,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: HeaderText(controller: controller),
              ),
              Obx(() => Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SyncIndicator(size: 16),
                  const SizedBox(width: 10.0),
                  ClipOval(
                    child: Material(
                      color: context.theme.colorScheme.properSurface, // button color
                      child: InkWell(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(
                            CupertinoIcons.search,
                            color: context.theme.colorScheme.properOnSurface,
                            size: 20
                          )
                        ),
                        onTap: () {
                          ns.pushLeft(context, SearchView());
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  if (ss.settings.moveChatCreatorToHeader.value)
                    ClipOval(
                      child: Material(
                        color: context.theme.colorScheme.properSurface, // button color
                        child: InkWell(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              CupertinoIcons.pencil,
                              color: context.theme.colorScheme.properOnSurface,
                              size: 20,
                            ),
                          ),
                          onTap: () => controller.openNewChatCreator(context),
                        ),
                      ),
                    ),
                  if (ss.settings.moveChatCreatorToHeader.value
                      && ss.settings.cameraFAB.value)
                    const SizedBox(width: 10.0),
                  if (ss.settings.moveChatCreatorToHeader.value
                      && ss.settings.cameraFAB.value)
                    ClipOval(
                      child: Material(
                        color: context.theme.colorScheme.properSurface, // button color
                        child: InkWell(
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              CupertinoIcons.camera,
                              color: context.theme.colorScheme.properOnSurface,
                              size: 20
                            ),
                          ),
                          onTap: () => controller.openCamera(context)
                        ),
                      ),
                    ),
                  if (ss.settings.moveChatCreatorToHeader.value)
                    const SizedBox(width: 10.0),
                  const Material(
                    color: Colors.transparent,
                    shape: CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: OverflowMenu(),
                  ),
                ],
              ))
            ],
          ),
        ),
      ),
    );
  }
}

class CupertinoMiniHeader extends StatelessWidget {
  const CupertinoMiniHeader({Key? key, required this.controller});

  final ConversationListController controller;

  @override
  Widget build(BuildContext context) {
    final double topMargin = context.orientation == Orientation.landscape && context.isPhone
        ? 20
        : kIsDesktop || kIsWeb
        ? 40
        : kToolbarHeight + 30;

    return FadeOnScroll(
      scrollController: controller.iosScrollController,
      fullOpacityOffset: topMargin + 15,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
              width: ns.width(context),
              height: (topMargin - 20).clamp(40, double.infinity),
              color: context.theme.colorScheme.properSurface.withOpacity(0.5),
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  controller.showArchivedChats
                      ? "Archive"
                      : controller.showUnknownSenders
                      ? "Unknown Senders"
                      : "Messages",
                  style: context.textTheme.titleMedium!
                      .copyWith(color: context.theme.colorScheme.properOnSurface),
                ),
              )
          ),
        ),
      ),
    );
  }
}