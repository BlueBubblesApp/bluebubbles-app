import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart' show SelectedContact;
import 'package:bluebubbles/app/layouts/chat_creator/chat_creator_controller.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/recipient_chips_row.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/search_results_list.dart';
import 'package:bluebubbles/app/layouts/chat_creator/widgets/service_type_picker.dart';
import 'package:bluebubbles/app/layouts/conversation_view/pages/messages_view.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/text_field/text_field_component.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Chat creation page.
///
/// Constructor parameters are API-compatible:
/// ```dart
/// NewChatCreator(
///   initialText: '...',
///   initialAttachments: [...],
///   initialSelected: [...],
/// )
/// ```
class NewChatCreator extends StatefulWidget {
  const NewChatCreator({
    super.key,
    this.initialText = '',
    this.initialAttachments = const [],
    this.initialSelected = const [],
  });

  final String? initialText;
  final List<PlatformFile> initialAttachments;
  final List<SelectedContact> initialSelected;

  @override
  State<NewChatCreator> createState() => _NewChatCreatorState();
}

class _NewChatCreatorState extends State<NewChatCreator> with ThemeHelpers<NewChatCreator> {
  late final String _tag;
  late final ChatCreatorController controller;

  @override
  void initState() {
    super.initState();
    _tag = randomString(8);
    controller = Get.put(
      ChatCreatorController(
        initialText: widget.initialText,
        initialAttachments: widget.initialAttachments,
        initialSelected: widget.initialSelected,
      ),
      tag: _tag,
    );

    if (widget.initialSelected.isNotEmpty) {
      // Focus the message field when contacts have been pre-selected (e.g. deep link).
      Future.delayed(Duration.zero, () {
        if (mounted) controller.messageNode.requestFocus();
      });
    } else {
      // Auto-focus the address field when opening fresh.
      Future.delayed(Duration.zero, () {
        if (mounted) controller.addressNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    Get.delete<ChatCreatorController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BBScaffold(
      safeAreaTop: true,
      safeAreaBottom: true,
      resizeToAvoidBottomInset: true,
      appBar: BBAppBar(
        titleText: 'New Message',
        leading: buildBackButton(context),
        // backgroundColor: Colors.transparent,
        toolbarHeight: kIsDesktop ? 90 : 60,
      ),
      body: FocusScope(
        child: Column(
          children: [
            _AnimatedHeader(controller: controller),
            Expanded(child: _ContentArea(controller: controller)),
            _TextFieldArea(controller: controller),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Header: service type picker + recipient chips + divider
// Collapses (AnimatedSize + AnimatedOpacity) when a message is sent to an
// existing chat just before navigating to the full ConversationView.
// -----------------------------------------------------------------------------

class _AnimatedHeader extends StatelessWidget {
  const _AnimatedHeader({required this.controller});

  final ChatCreatorController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final visible = controller.isHeaderVisible.value;
      return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: visible
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    ServiceTypePicker(controller: controller),
                    RecipientChipsRow(controller: controller),
                    const SizedBox(height: 8),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: context.theme.dividerColor.withValues(alpha: 0.25),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      );
    });
  }
}

// -----------------------------------------------------------------------------
// Content area: switches between the search results list and the embedded
// MessagesView once an existing chat has been resolved.
// -----------------------------------------------------------------------------

class _ContentArea extends StatelessWidget {
  const _ContentArea({required this.controller});

  final ChatCreatorController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeCVC = controller.activeController.value;

      Widget child;
      if (activeCVC == null) {
        child = SearchResultsList(key: const ValueKey('search'), controller: controller);
      } else {
        final isIMsg = activeCVC.chat.isIMessage;
        final colorScheme = context.theme.colorScheme;
        final bubbleColorsExt = context.theme.extensions[BubbleColors] as BubbleColors?;

        child = Theme(
          key: ValueKey(activeCVC.chat.guid),
          data: context.theme.copyWith(
            primaryColor: colorScheme.bubble(context, isIMsg),
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.bubble(context, isIMsg),
              onPrimary: colorScheme.onBubble(context, isIMsg),
              surface: ThemeSvc.isMaterialYouActive(context) ? null : bubbleColorsExt?.receivedBubbleColor,
              onSurface: ThemeSvc.isMaterialYouActive(context) ? null : bubbleColorsExt?.onReceivedBubbleColor,
            ),
          ),
          child: ChatStateScope(
            chatState: ChatsSvc.getOrCreateChatState(activeCVC.chat),
            child: MessagesView(
              customService: controller.messagesService,
              controller: activeCVC,
            ),
          ),
        );
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: child,
      );
    });
  }
}

// -----------------------------------------------------------------------------
// Text field area: switches between "new contact" mode (no attachments) and
// "existing chat" mode (full attachment / reply / recording support).
// Also applies the correct bubble color theme based on the selected service.
// -----------------------------------------------------------------------------

class _TextFieldArea extends StatelessWidget {
  const _TextFieldArea({required this.controller});

  final ChatCreatorController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final service = controller.selectedService.value;
      final isIMsg = service == ChatServiceType.iMessage;
      final activeCVC = controller.activeController.value;
      final sending = controller.isSending.value;

      return Padding(
        padding: const EdgeInsets.all(10.0),
        child: Theme(
          data: context.theme.copyWith(
            primaryColor: context.theme.colorScheme.bubble(context, isIMsg),
            colorScheme: context.theme.colorScheme.copyWith(
              primary: context.theme.colorScheme.bubble(context, isIMsg),
              onPrimary: context.theme.colorScheme.onBubble(context, isIMsg),
              surface: ThemeSvc.isMaterialYouActive(context)
                  ? null
                  : (context.theme.extensions[BubbleColors] as BubbleColors?)?.receivedBubbleColor,
              onSurface: ThemeSvc.isMaterialYouActive(context)
                  ? null
                  : (context.theme.extensions[BubbleColors] as BubbleColors?)?.onReceivedBubbleColor,
            ),
          ),
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  HardwareKeyboard.instance.isShiftPressed &&
                  event.logicalKey == LogicalKeyboardKey.tab) {
                controller.addressNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: activeCVC != null
                // Existing chat: pass focusNode so isChatCreator=true → media picker icons show.
                // alwaysShowSend: true so the send button is visible even with no content,
                // allowing the user to open the conversation without typing first.
                ? TextFieldComponent(
                    key: ValueKey(activeCVC.chat.guid),
                    focusNode: controller.messageNode,
                    textController: activeCVC.textController,
                    subjectTextController: activeCVC.subjectTextController,
                    controller: activeCVC,
                    recorderController: null,
                    alwaysShowSend: true,
                    sendMessage: ({String? effect}) => controller.sendMessage(context, effectId: effect),
                  )
                // New contact: isChatCreator = true → initialAttachments only (no controller)
                : TextFieldComponent(
                    key: ValueKey(service),
                    focusNode: controller.messageNode,
                    textController: controller.textController,
                    controller: null,
                    recorderController: null,
                    initialAttachments: controller.initialAttachments,
                    sendMessage: sending
                        ? ({String? effect}) async {}
                        : ({String? effect}) => controller.sendMessage(context, effectId: effect),
                  ),
          ),
        ),
      );
    });
  }
}
