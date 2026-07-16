import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_image.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/fullscreen_video.dart';
import 'package:bluebubbles/app/wrappers/bb_app_bar.dart';
import 'package:bluebubbles/app/wrappers/bb_scaffold.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/backend_ui_interop/intents.dart';
import 'package:flutter/material.dart';
import 'package:gesture_x_detector/gesture_x_detector.dart';
import 'package:get/get.dart';

/// A lightweight, single-item counterpart to [ConversationFullscreenHolder].
///
/// [ConversationFullscreenHolder] is built around a [PageView] of a chat's attachments
/// (gallery paging, reply-to-attachment, keyboard arrow navigation) — none of
/// which apply when previewing one local, not-yet-sent [file]/[attachment] (e.g.
/// the composer's picked-attachment preview). This widget owns its app bar
/// directly and drives its visibility straight off the child's
/// `onOverlayToggle` callback, with no intermediate list/page-index state to
/// keep in sync.
class SingleAttachmentFullscreenViewer extends StatefulWidget {
  const SingleAttachmentFullscreenViewer({
    super.key,
    required this.file,
    required this.attachment,
    this.showInteractions = false,
  });

  final PlatformFile file;
  final Attachment attachment;
  final bool showInteractions;

  @override
  State<SingleAttachmentFullscreenViewer> createState() => _SingleAttachmentFullscreenViewerState();
}

class _SingleAttachmentFullscreenViewerState extends State<SingleAttachmentFullscreenViewer> with ThemeHelpers {
  final focusNode = FocusNode();

  bool get _isVideo => widget.attachment.mimeStart == "video";

  // Start hidden for video (it auto-plays and manages its own overlay); show for images.
  late bool showAppBar = !_isVideo;

  @override
  Widget build(BuildContext context) {
    return TitleBarWrapper(
      child: Actions(
        actions: {
          GoBackIntent: GoBackAction(context),
        },
        child: BBScaffold(
          safeAreaLeft: false,
          safeAreaRight: false,
          extendBodyBehindAppBar: true,
          extendBodyBehindBottomPill: true,
          // FullscreenVideo/FullscreenImage render their own self-contained close bar
          // for the Android/Material skin (see their `!iOS` overlay blocks), so this
          // app bar — matching BBAppBar's "Done" convention — is iOS-skin only.
          appBar: !iOS || !showAppBar
              ? null
              : BBAppBar(
                  leading: XGestureDetector(
                    supportTouch: true,
                    onTap: !kIsDesktop
                        ? null
                        : (details) {
                            Navigator.of(context).pop();
                          },
                    child: TextButton(
                      child: Text("Done",
                          style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)),
                      onPressed: () {
                        if (kIsDesktop) return;
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  leadingWidth: 75,
                  titleText: "Media",
                  titleStyle:
                      context.theme.textTheme.titleLarge!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                  iconTheme: IconThemeData(color: context.theme.colorScheme.primary),
                  backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
                ),
          backgroundColor: Colors.black,
          body: FocusScope(
            child: Focus(
              focusNode: focusNode,
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event.physicalKey.debugName == "Escape") {
                  Navigator.of(context).pop();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: _isVideo
                  ? FullscreenVideo(
                      file: widget.file,
                      attachment: widget.attachment,
                      showInteractions: widget.showInteractions,
                      onOverlayToggle: (show) {
                        if (showAppBar != show) {
                          setState(() {
                            showAppBar = show;
                          });
                        }
                      },
                    )
                  : FullscreenImage(
                      file: widget.file,
                      attachment: widget.attachment,
                      showInteractions: widget.showInteractions,
                      updatePhysics: (_) {},
                      onOverlayToggle: (show) {
                        if (showAppBar != show) {
                          setState(() {
                            showAppBar = show;
                          });
                        }
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
