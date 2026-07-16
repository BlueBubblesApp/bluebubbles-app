import 'package:animations/animations.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/audio_player.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/contact_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/image_viewer.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/other_file.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/video_player.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/url_preview.dart';
import 'package:bluebubbles/app/state/attachment_state_scope.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/fullscreen_media/conversation_fullscreen_holder.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Fully resolved attachment: dispatches to the appropriate viewer widget.
/// No reactive state is needed here — the file is static once this is shown.
class ResolvedFileContent extends StatelessWidget {
  const ResolvedFileContent({
    super.key,
    required this.file,
    required this.audioTranscript,
    required this.showTail,
    required this.isiOS,
    required this.cvController,
    this.isInReply = false,
    this.forceAllCornersRounded = false,
    this.galleryAttachments,
  });

  final PlatformFile file;
  final String? audioTranscript;
  final bool showTail;
  final bool isiOS;
  final ConversationViewController? cvController;
  final bool isInReply;
  final bool forceAllCornersRounded;
  final List<Attachment>? galleryAttachments;

  @override
  Widget build(BuildContext context) {
    final message = MessageStateScope.messageOf(context);
    final attachment = AttachmentStateScope.attachmentOf(context);
    final currentChat = ChatStateScope.maybeChatOf(context);
    final tailPadding = EdgeInsets.only(
      left: message.isFromMe! ? 0 : 10,
      right: message.isFromMe! ? 10 : 0,
    );
    if (attachment.mimeStart == "image" && !SettingsSvc.settings.highPerfMode.value) {
      return OpenContainer(
        tappable: false,
        openColor: Colors.black,
        closedColor: context.theme.colorScheme.surfaceContainerHighest,
        closedShape: isiOS
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20.0),
                  topRight: const Radius.circular(20.0),
                  bottomLeft: forceAllCornersRounded
                      ? const Radius.circular(20.0)
                      : (message.isFromMe! ? const Radius.circular(20.0) : Radius.zero),
                  bottomRight: forceAllCornersRounded
                      ? const Radius.circular(20.0)
                      : (!message.isFromMe! ? const Radius.circular(20.0) : Radius.zero),
                ),
              )
            : const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(5.0))),
        useRootNavigator: false,
        openBuilder: (context, _) => ConversationFullscreenHolder(
          currentChat: currentChat,
          attachment: attachment,
          showInteractions: true,
          galleryAttachments: galleryAttachments,
        ),
        closedBuilder: (context, openContainer) => GestureDetector(
          onTap: () {
            final ctrl = cvController ?? cvc(currentChat!);
            ctrl.focusNode.unfocus();
            ctrl.subjectFocusNode.unfocus();
            openContainer();
          },
          child: Container(
            color: context.theme.colorScheme.surfaceContainerHighest,
            child: ImageViewer(
              file: file,
              attachment: attachment,
              isFromMe: message.isFromMe!,
              isInReply: isInReply,
              controller: cvController,
            ),
          ),
        ),
      );
    }

    if (attachment.mimeStart == "video" && !SettingsSvc.settings.highPerfMode.value && !isSnap) {
      return VideoPlayer(
        attachment: attachment,
        file: file,
        controller: cvController,
        isFromMe: message.isFromMe!,
        galleryAttachments: galleryAttachments,
      );
    }

    if (attachment.mimeStart == "audio") {
      return Padding(
        padding: showTail ? tailPadding : EdgeInsets.zero,
        child: AudioPlayer(
          transcript: audioTranscript,
          attachment: attachment,
          file: file,
          controller: cvController,
        ),
      );
    }

    if (attachment.mimeType == "text/x-vlocation" || attachment.uti == 'public.vlocation') {
      return Padding(
        padding: showTail ? tailPadding : EdgeInsets.zero,
        child: UrlPreview(
          data: UrlPreviewData(
            title: "Location from ${DateFormat.yMd().format(message.dateCreated!)}",
            siteName: "Tap to open",
          ),
          file: file,
        ),
      );
    }

    if (attachment.mimeType?.contains("vcard") ?? false) {
      return Padding(
        padding: showTail ? tailPadding : EdgeInsets.zero,
        child: ContactCard(attachment: attachment, file: file),
      );
    }

    return Padding(
      padding: showTail ? tailPadding : EdgeInsets.zero,
      child: OtherFile(attachment: attachment, file: file),
    );
  }
}
