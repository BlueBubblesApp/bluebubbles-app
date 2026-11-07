import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/collections/collection_media_grid_page.dart';
import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/widgets.dart';

/// The media of one collapsed collection part (collage / stack / grid), plus the actions on it.
///
/// An immutable value: build it with [MediaCollection.forPart] and provide it to descendants with
/// [MediaCollectionScope] rather than passing it through constructors.
@immutable
class MediaCollection {
  const MediaCollection({
    required this.chat,
    required this.media,
    required this.messageState,
    required this.collectionPart,
  });

  /// Builds the collection for [collectionPart], reading the message from the surrounding [MessageStateScope].
  factory MediaCollection.forPart(
    BuildContext context, {
    required MessagePart collectionPart,
    required ConversationViewController cvController,
  }) {
    return MediaCollection(
      chat: cvController.chat,
      media: collectionPart.attachments,
      messageState: MessageStateScope.of(context),
      collectionPart: collectionPart,
    );
  }

  final Chat chat;
  final List<Attachment> media;
  final MessageState messageState;
  final MessagePart collectionPart;

  /// "3 Photos", "2 Videos", or "5 Items" for mixed media.
  String get title {
    final photoCount = media.where((a) => a.mimeStart == 'image').length;
    final videoCount = media.where((a) => a.mimeStart == 'video').length;
    if (photoCount > 0 && videoCount > 0) return '${photoCount + videoCount} Items';
    if (videoCount > 0) return '$videoCount ${videoCount == 1 ? 'Video' : 'Videos'}';
    return '$photoCount ${photoCount == 1 ? 'Photo' : 'Photos'}';
  }

  /// Opens the full-page grid of this collection's media.
  void openGallery(BuildContext context, {String? title}) {
    NavigationSvc.push(context, CollectionMediaGridPage(collection: this, title: title ?? this.title));
  }
}

/// Provides the [MediaCollection] that encloses a subtree, so attachment renderers deep inside a
/// collection card (image / video viewers opening fullscreen) can page through the collection without
/// every intermediate widget taking a parameter.
///
/// Provided by each collection layout. Absent everywhere else, including inside
/// [CollectionMediaGridPage], so fullscreen opened from the gallery never offers to reopen it.
class MediaCollectionScope extends InheritedWidget {
  const MediaCollectionScope({
    super.key,
    required this.collection,
    required super.child,
  });

  final MediaCollection collection;

  /// The enclosing collection, or null outside a collection layout.
  static MediaCollection? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MediaCollectionScope>()?.collection;

  @override
  bool updateShouldNotify(MediaCollectionScope oldWidget) {
    final old = oldWidget.collection;
    return !identical(old.media, collection.media) ||
        old.messageState != collection.messageState ||
        old.collectionPart != collection.collectionPart ||
        old.chat != collection.chat;
  }
}
