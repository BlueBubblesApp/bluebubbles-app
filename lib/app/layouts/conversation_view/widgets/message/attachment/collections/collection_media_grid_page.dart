import 'package:bluebubbles/app/layouts/conversation_details/material/chat_detail_theme.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/media/media_grid_section.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_controller.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reaction/reaction_clipper.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Full-page selectable grid for a message media collection.
///
/// Reuses [MediaGridSection].
class CollectionMediaGridPage extends StatefulWidget {
  const CollectionMediaGridPage({
    super.key,
    required this.chat,
    required this.media,
    required this.title,
    this.collectionController,
  });

  final Chat chat;
  final List<Attachment> media;
  final String title;
  final CollectionMediaController? collectionController;

  static String titleForAttachments(List<Attachment> attachments) {
    final photoCount = attachments.where((a) => a.mimeStart == 'image').length;
    final videoCount = attachments.where((a) => a.mimeStart == 'video').length;
    final totalCount = photoCount + videoCount;
    if (photoCount > 0 && videoCount > 0) return '$totalCount Items';
    if (videoCount > 0) return '$videoCount ${videoCount == 1 ? 'Video' : 'Videos'}';
    return '$photoCount ${photoCount == 1 ? 'Photo' : 'Photos'}';
  }

  static void open(
    BuildContext context, {
    required CollectionMediaController collectionController,
    String? title,
  }) {
    NavigationSvc.push(
      context,
      CollectionMediaGridPage(
        chat: collectionController.chat,
        media: collectionController.media,
        title: title ?? collectionController.title,
        collectionController: collectionController,
      ),
    );
  }

  @override
  State<CollectionMediaGridPage> createState() => _CollectionMediaGridPageState();
}

class _CollectionMediaGridPageState extends State<CollectionMediaGridPage> with ThemeHelpers {
  final RxList<String> selected = <String>[].obs;

  void _downloadAttachments(Iterable<Attachment> attachments) {
    for (final a in attachments) {
      final file = AttachmentsSvc.getContent(a, autoDownload: false);
      if (file is PlatformFile) {
        AttachmentsSvc.saveToDisk(file);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ChatsSvc.getOrCreateChatState(widget.chat);
    return ChatStateScope(
      chatState: chatState,
      child: Obx(() {
        final chatDetailTheme = ChatDetailTheme.resolve(context, widget.chat);
        final collectionController = widget.collectionController;
        final showReactions = collectionController != null;

        Widget scaffold = Theme(
          data: chatDetailTheme.theme,
          child: SettingsScaffold(
            headerColor: chatDetailTheme.headerColor,
            title: widget.title,
            tileColor: chatDetailTheme.tileColor,
            initialHeader: null,
            iosSubtitle: iosSubtitle,
            materialSubtitle: materialSubtitle,
            actions: [
              Obx(() {
                if (selected.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: Icon(iOS ? CupertinoIcons.xmark : Icons.close, color: context.theme.colorScheme.onSurface),
                  onPressed: () => selected.clear(),
                );
              }),
              Obx(() {
                final inSelectionMode = selected.isNotEmpty;
                return IconButton(
                  icon: Icon(
                    iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                    color: inSelectionMode
                        ? context.theme.colorScheme.onSurface
                        : context.theme.colorScheme.primary,
                  ),
                  onPressed: () {
                    if (inSelectionMode) {
                      _downloadAttachments(widget.media.where((e) => selected.contains(e.guid!)));
                    } else {
                      _downloadAttachments(widget.media);
                    }
                  },
                );
              }),
            ],
            bodySlivers: [
              MediaGridSection(
                chat: widget.chat,
                media: widget.media,
                selected: selected,
                isLoading: false,
                fullPage: true,
                crossAxisCount: 3,
                showSenderAvatar: false,
                cellOverlayBuilder: showReactions
                    ? (context, index, _) => CollectionAttachmentReactions(
                          collectionPart: collectionController.collectionPart,
                          attachmentIndex: index,
                          alignTrailing: true,
                          tailType: ReactionTailType.inside,
                        )
                    : null,
              ),
              const SliverPadding(padding: EdgeInsets.only(top: 50)),
            ],
          ),
        );

        if (showReactions) {
          // ReactionHolder uses DeferPointer; needs a handler outside MessageHolder.
          scaffold = DeferredPointerHandler(
            child: MessageStateScope(
              messageState: collectionController.messageState,
              child: scaffold,
            ),
          );
        }

        return scaffold;
      }),
    );
  }
}
