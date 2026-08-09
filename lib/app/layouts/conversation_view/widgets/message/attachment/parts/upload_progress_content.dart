import 'package:bluebubbles/app/components/circle_progress_bar.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/image_viewer.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/other_file.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/video_player.dart';
import 'package:bluebubbles/app/state/attachment_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Outgoing attachment: shows a preview (if available) at reduced opacity
/// with an upload progress overlay.  The Obx only rebuilds the overlay on
/// progress ticks.
class UploadProgressContent extends StatelessWidget {
  const UploadProgressContent({
    super.key,
    required this.isiOS,
    required this.cvController,
  });

  final bool isiOS;
  final ConversationViewController? cvController;

  Widget _buildPreview(BuildContext context) {
    final attachmentState = AttachmentStateScope.of(context);
    final attachment = attachmentState.attachment;
    final previewFile = attachmentState.uploadPreviewFile.value;
    final isFromMe = MessageStateScope.of(context).isFromMe.value;
    if (previewFile != null && attachment.mimeStart == "image" && !SettingsSvc.settings.highPerfMode.value) {
      return Container(
        color: context.theme.colorScheme.surfaceContainerHighest,
        child: ImageViewer(
          file: previewFile,
          attachment: attachment,
          isFromMe: isFromMe,
          controller: cvController,
        ),
      );
    }
    if (previewFile != null && attachment.mimeStart == "video" && !SettingsSvc.settings.highPerfMode.value) {
      return VideoPlayer(
        attachment: attachment,
        file: previewFile,
        controller: cvController,
        isFromMe: isFromMe,
      );
    }
    return Container(
      color: context.theme.colorScheme.surfaceContainerHighest,
      child: OtherFileRow(attachment: attachment, file: previewFile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachmentState = AttachmentStateScope.of(context);
    final previewFile = attachmentState.uploadPreviewFile.value;
    final messageError = MessageStateScope.of(context).error.value;
    return Stack(
      children: [
        Opacity(opacity: previewFile != null ? 0.8 : 1.0, child: _buildPreview(context)),
        // Subtle tint over the preview while uploading.
        Positioned.fill(
          child: Container(
            color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          ),
        ),
        // Top-left: circular cancel / waiting chip — styled like the Live photo tag.
        if (messageError == 0)
          Positioned(
            top: 8,
            left: 8,
            child: Obx(() {
              final isSending = (attachmentState.uploadProgress.value ?? 0.0) < 1.0;
              return GestureDetector(
                onTap: isSending ? () => OutgoingMsgHandler.latestCancelToken?.cancel("User cancelled send.") : null,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isSending ? Icons.close : Icons.access_time,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }),
          ),
        // Top-right: pill backdrop (matches cancel button) with a smaller
        // progress ring inset inside it.
        Positioned(
          top: 8,
          right: 16,
          child: Obx(() {
            return Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircleProgressBar(
                    value: attachmentState.uploadProgress.value ?? 0.0,
                    backgroundColor: Colors.white.withValues(alpha: 0.35),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    strokeWidth: 2.0,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
