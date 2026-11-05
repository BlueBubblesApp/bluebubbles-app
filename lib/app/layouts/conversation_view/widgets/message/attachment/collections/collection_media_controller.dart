import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_grid_page.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:flutter/material.dart';

/// Owns opening [CollectionMediaGridPage] for a message media collection.
///
/// Created by collage/stack/grid layouts. Passed into fullscreen only from
/// collection cards (not from [CollectionMediaGridPage]) so the grid button
/// cannot nest endlessly.
class CollectionMediaController {
  const CollectionMediaController({
    required this.chat,
    required this.media,
    required this.messageState,
    required this.collectionPart,
  });

  final Chat chat;
  final List<Attachment> media;
  final MessageState messageState;
  final MessagePart collectionPart;

  String get title => CollectionMediaGridPage.titleForAttachments(media);

  void openGallery(BuildContext context, {String? title}) {
    CollectionMediaGridPage.open(
      context,
      collectionController: this,
      title: title,
    );
  }
}
