import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

class ConversationListFAB extends CustomStateful<ConversationListController> {
  const ConversationListFAB({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _ConversationListFABState();
}

class _ConversationListFABState extends CustomState<ConversationListFAB, void, ConversationListController> with ThemeHelpers {

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
  }

  @override
  Widget build(BuildContext context) {
    final widget = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (ss.settings.cameraFAB.value && iOS)
          ConstrainedBox(
            constraints: BoxConstraints(
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
        if (ss.settings.cameraFAB.value && iOS)
          const SizedBox(
            height: 10,
          ),
        InkWell(
          onLongPress: iOS || !ss.settings.cameraFAB.value
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
    );

    return ThemeSwitcher(
      iOSSkin: widget,
      materialSkin: AnimatedCrossFade(
        crossFadeState: controller.selectedChats.isEmpty
            ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        alignment: Alignment.center,
        duration: const Duration(milliseconds: 300),
        secondChild: const SizedBox.shrink(),
        firstChild: InkWell(
          onLongPress: ss.settings.cameraFAB.value
              ? () => controller.openCamera(context) : null,
          child: Container(
            height: 65,
            padding: const EdgeInsets.only(right: 4.5, bottom: 9),
            child: FloatingActionButton.extended(
              backgroundColor: context.theme.colorScheme.primaryContainer,
              label: AnimatedSwitcher(
                duration: Duration(milliseconds: 150),
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
      samsungSkin: widget,
    );
  }
}
