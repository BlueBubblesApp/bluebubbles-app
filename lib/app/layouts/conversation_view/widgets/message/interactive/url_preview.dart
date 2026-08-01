import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/cupertino_url_preview.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/expressive_url_preview.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:flutter/material.dart';

/// Link preview card.
///
/// Owns the [UrlPreviewController] — all fetch, cache and policy wiring — and
/// dispatches rendering to a skin.
///
/// The dispatch is a plain branch rather than a `ThemeSwitcher`. `ThemeSwitcher`
/// takes already-constructed widgets for every skin, so it would allocate both
/// variants on each build and throw one away — acceptable for a settings page
/// built once, wasteful for a widget that exists per message in a scrolling
/// list. Its `Obx` is also redundant here: changing the app skin runs
/// `ChatsSvc.setAllInactive()` first, which tears down open conversation views
/// so they rebuild against the new skin. That is why nothing else under
/// `widgets/message/` uses `ThemeSwitcher` either.
class UrlPreview extends StatefulWidget {
  final UrlPreviewData data;
  final PlatformFile? file;

  const UrlPreview({
    super.key,
    required this.data,
    this.file,
  });

  @override
  State<StatefulWidget> createState() => _UrlPreviewState();
}

class _UrlPreviewState extends State<UrlPreview>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin, ThemeHelpers {
  late final UrlPreviewController controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    controller = UrlPreviewController(data: widget.data, file: widget.file, vsync: this);

    // UrlPreview is also used outside a message context (the links and
    // locations sections of conversation details), so look the scope up
    // defensively rather than asserting one exists.
    //
    // getInheritedWidgetOfExactType (no dependency registration) is used for
    // ReplyScope because dependOnInheritedWidgetOfExactType is illegal here.
    controller.attach(
      messageState: context.findAncestorWidgetOfExactType<MessageStateScope>()?.messageState,
      inReply: context.getInheritedWidgetOfExactType<ReplyScope>() != null,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return iOS ? CupertinoUrlPreview(controller: controller) : ExpressiveUrlPreview(controller: controller);
  }
}
