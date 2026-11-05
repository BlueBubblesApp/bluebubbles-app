import 'package:bluebubbles/app/layouts/conversation_details/material/chat_detail_theme.dart';
import 'package:bluebubbles/app/layouts/conversation_details/widgets/sections/media/media_grid_section.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_attachment_card.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/media_collection.dart';
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

/// Full-page selectable grid for a message media collection, with per-item tapbacks.
///
/// Reuses [MediaGridSection]. Opened via [MediaCollection.openGallery].
class CollectionMediaGridPage extends StatefulWidget {
  const CollectionMediaGridPage({
    super.key,
    required this.collection,
    required this.title,
  });

  final MediaCollection collection;
  final String title;

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
    final collection = widget.collection;
    final chatState = ChatsSvc.getOrCreateChatState(collection.chat);
    return ChatStateScope(
      chatState: chatState,
      child: Obx(() {
        final chatDetailTheme = ChatDetailTheme.resolve(context, collection.chat);
        final scaffold = Theme(
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
                      _downloadAttachments(collection.media.where((e) => selected.contains(e.guid!)));
                    } else {
                      _downloadAttachments(collection.media);
                    }
                  },
                );
              }),
            ],
            bodySlivers: [
              MediaGridSection(
                chat: collection.chat,
                media: collection.media,
                selected: selected,
                isLoading: false,
                fullPage: true,
                crossAxisCount: 3,
                showSenderAvatar: false,
                cellOverlayBuilder: (context, index, _) => CollectionAttachmentReactions(
                  collectionPart: collection.collectionPart,
                  attachmentIndex: index,
                  alignTrailing: true,
                  tailType: ReactionTailType.inside,
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(top: 50)),
            ],
          ),
        );

        // ReactionHolder uses DeferPointer; needs a handler outside MessageHolder.
        return DeferredPointerHandler(
          child: MessageStateScope(
            messageState: collection.messageState,
            child: scaffold,
          ),
        );
      }),
    );
  }
}
