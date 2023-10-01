import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

class ConversationListFAB extends CustomStateful<ConversationListController> {
  const ConversationListFAB({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _ConversationListFABState();
}

class _ConversationListFABState extends CustomState<ConversationListFAB, void, ConversationListController> {

  @override
  void initState() {
    super.initState();

    controller.materialScrollController.addListener(() {
      if (!material) return;
      if (controller.materialScrollStartPosition - controller.materialScrollController.offset < -75
          && controller.materialScrollController.position.userScrollDirection == ScrollDirection.reverse
          && controller.showMaterialFABText) {
        setState(() {
          controller.showMaterialFABText = false;
        });
      } else if (controller.materialScrollStartPosition - controller.materialScrollController.offset > 75
          && controller.materialScrollController.position.userScrollDirection == ScrollDirection.forward
          && !controller.showMaterialFABText) {
        setState(() {
          controller.showMaterialFABText = true;
        });
      }
    });
    ns.listener.stream.listen((event) {
      if (!mounted) return;
      if (ns.isAvatarOnly(context) && controller.showMaterialFABText) {
        setState(() {
          controller.showMaterialFABText = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final widget = Obx(() => Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (ss.settings.cameraFAB.value && iOS && !kIsWeb && !kIsDesktop)
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 45,
              maxHeight: 45,
            ),
            child: FloatingActionButton(
              child: Icon(
                iOS ? CupertinoIcons.camera : Icons.photo_camera,
                size: 20,
                color: context.theme.colorScheme.onPrimaryContainer
              ),
              onPressed: () => controller.openCamera(context),
              heroTag: null,
              backgroundColor: context.theme.colorScheme.primaryContainer,
            ),
          ),
        if (ss.settings.cameraFAB.value && iOS && !kIsWeb && !kIsDesktop)
          const SizedBox(
            height: 10,
          ),
        InkWell(
          onLongPress: iOS || !ss.settings.cameraFAB.value || kIsWeb || kIsDesktop
            ? null : () => controller.openCamera(context),
          child: FloatingActionButton(
            backgroundColor: context.theme.colorScheme.primary,
            child: Icon(
              iOS ? CupertinoIcons.pencil : Icons.message,
              color: context.theme.colorScheme.onPrimary,
              size: 25
            ),
            onPressed: () => controller.openNewChatCreator(context)
          ),
        ),
      ],
    ));

    return ThemeSwitcher(
      iOSSkin: widget,
      materialSkin: AnimatedCrossFade(
        crossFadeState: controller.selectedChats.isEmpty
            ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        alignment: Alignment.center,
        duration: const Duration(milliseconds: 300),
        secondChild: const SizedBox.shrink(),
        firstChild: SizedBox(
          width: ns.width(context),
          height: 125,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              AnimatedOpacity(
                opacity: !controller.showMaterialFABText ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: FloatingActionButton.small(
                  heroTag: null,
                  onPressed: () async {
                    await controller.materialScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    setState(() {
                      controller.showMaterialFABText = true;
                    });
                  },
                  child: Icon(
                    Icons.arrow_upward,
                    color: context.theme.colorScheme.onSecondary,
                  ),
                  backgroundColor: context.theme.colorScheme.secondary,
                ),
              ),
              Positioned(
                right: material ? 15 : 0,
                child: InkWell(
                  onLongPress: ss.settings.cameraFAB.value && !kIsWeb && !kIsDesktop
                      ? () => controller.openCamera(context) : null,
                  child: Container(
                    height: 65,
                    padding: const EdgeInsets.only(right: 4.5, bottom: 9),
                    child: FloatingActionButton.extended(
                      backgroundColor: context.theme.colorScheme.primaryContainer,
                      label: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (Widget child, Animation<double> animation) => SizeTransition(
                          child: child,
                          sizeFactor: animation,
                          axis: Axis.horizontal,
                        ),
                        child: controller.showMaterialFABText ? Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: Text(
                            "Start Chat",
                            style: TextStyle(
                              color: context.theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ) : const SizedBox.shrink(),
                      ),
                      extendedIconLabelSpacing: 0,
                      icon: Padding(
                        padding: const EdgeInsets.only(left: 5.0),
                        child: Icon(
                          Icons.message_outlined,
                          color: context.theme.colorScheme.onPrimaryContainer,
                          size: 25,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                      onPressed: () => controller.openNewChatCreator(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      samsungSkin: widget,
    );
  }
}
