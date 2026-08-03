import 'dart:async';

import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// Renders a Photos app (iCloud shared album/photo/video) interactive
/// message. The share link may point at a single photo, an album, or a
/// video - and the underlying "attachment" iMessage records for these can be
/// arbitrarily large (a shared video can be several GB), so this widget
/// never downloads it. It only ever fetches the lightweight Open Graph
/// preview image from the share URL itself; tapping the bubble (handled by
/// the parent [InteractiveHolder]) opens the actual link in the browser.
class PhotoSlideshow extends StatefulWidget {
  final iMessageAppData data;

  const PhotoSlideshow({
    super.key,
    required this.data,
  });

  @override
  State<StatefulWidget> createState() => _PhotoSlideshowState();
}

class _PhotoSlideshowState extends State<PhotoSlideshow> with AutomaticKeepAliveClientMixin, ThemeHelpers {
  iMessageAppData get data => widget.data;

  String? _previewImagePath;
  bool _previewFetchStarted = false;
  bool _previewFetchFailed = false;

  late MessageState _ms;
  Worker? _refreshWorker;
  Message get message => _ms.message;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ms = MessageStateScope.readStateOnce(context);
    _refreshWorker = ever(_ms.previewRefreshKey, (_) {
      if (!mounted) return;
      setState(() {
        _previewImagePath = null;
        _previewFetchStarted = false;
        _previewFetchFailed = false;
      });
    });
  }

  @override
  void dispose() {
    _refreshWorker?.dispose();
    super.dispose();
  }

  /// Fetches the Open Graph preview image from the share URL (e.g. an
  /// iCloud shared-album link). Reuses [MetadataHelper]'s disk-caching so the
  /// image is only ever downloaded once per unique preview image. This never
  /// touches the underlying photo/video itself - only the small preview
  /// thumbnail the share page exposes for link unfurling.
  Future<void> _resolvePreviewImage(Message message) async {
    if (kIsWeb) {
      if (mounted) setState(() => _previewFetchFailed = true);
      return;
    }

    // Already cached on disk from a previous fetch.
    final storedMd5 = message.metadata?['photoPreviewImageMd5'] as String?;
    if (storedMd5 != null) {
      final cachedPath = FilesystemSvc.urlPreviewImagePath(storedMd5);
      if (await File(cachedPath).exists()) {
        if (mounted) setState(() => _previewImagePath = cachedPath);
        return;
      }
    }

    // A previous attempt already ran and found no image to cache - don't retry every build.
    if (message.metadata?['photoPreviewImageFetched'] == true) {
      if (mounted) setState(() => _previewFetchFailed = true);
      return;
    }

    if (isNullOrEmpty(data.url)) {
      if (mounted) setState(() => _previewFetchFailed = true);
      return;
    }

    try {
      final metadata = await MetadataHelper.fetchMetadata(message, urlOverride: data.url);
      if (metadata?.image != null) {
        final result = await MetadataHelper.resolveCachedImage(
          message,
          'photoPreviewImageMd5',
          metadata!.image!,
          optimize: true,
        );
        if (result != null) {
          if (mounted) setState(() => _previewImagePath = result.$1);
          return;
        }
      }
      message.metadata = {...?message.metadata, 'photoPreviewImageFetched': true};
      if (message.id != null) message.save();
    } catch (ex, stack) {
      Logger.warn('Failed to fetch Photos preview image', error: ex, trace: stack, tag: 'PhotoSlideshow');
    }
    if (mounted) setState(() => _previewFetchFailed = true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_previewImagePath == null && !_previewFetchStarted) {
      _previewFetchStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_resolvePreviewImage(message));
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.bottomLeft,
          children: [
            if (_previewImagePath != null)
              Image.file(
                File(_previewImagePath!),
                gaplessPlayback: true,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, object, stacktrace) => SizedBox(
                  width: 200,
                  height: 150,
                  child: Center(
                    child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                  ),
                ),
              ),
            if (_previewImagePath == null)
              SizedBox(
                width: 200,
                height: 150,
                child: Center(
                  child: _previewFetchFailed
                      ? Icon(
                          iOS ? CupertinoIcons.photo : Icons.photo_outlined,
                          size: 40,
                          color: context.theme.colorScheme.outline,
                        )
                      : (iOS
                          ? const CupertinoActivityIndicator()
                          : CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(context.theme.colorScheme.onSurfaceVariant),
                            )),
                ),
              ),
            if (!isNullOrEmpty(data.userInfo?.imageTitle) || !isNullOrEmpty(data.userInfo?.imageSubtitle))
              Positioned(
                bottom: 5,
                left: 15,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isNullOrEmpty(data.userInfo?.imageTitle))
                      Text(
                        data.userInfo!.imageTitle!,
                        style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!isNullOrEmpty(data.userInfo?.imageSubtitle))
                      Text(data.userInfo!.imageSubtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)),
                  ],
                ),
              ),
            if (!isNullOrEmpty(data.userInfo?.subcaption))
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    data.userInfo!.subcaption!,
                    style: context.theme.textTheme.labelMedium!.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!isNullOrEmpty(data.userInfo?.caption) || !isNullOrEmpty(data.ldText))
              Text(
                (data.userInfo?.caption?.isNotEmpty ?? false) ? data.userInfo!.caption! : data.ldText!,
                style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (!isNullOrEmpty(data.userInfo?.secondarySubcaption))
              Text(
                data.userInfo!.secondarySubcaption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal),
              ),
            if (!isNullOrEmpty(data.userInfo?.tertiarySubcaption))
              Text(
                data.userInfo!.tertiarySubcaption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal),
              ),
            if (!isNullOrEmpty(data.appName)) const SizedBox(height: 5),
            if (!isNullOrEmpty(data.appName))
              Text(
                data.appName!,
                style: context.theme.textTheme.labelMedium!
                    .copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                overflow: TextOverflow.clip,
                maxLines: 1,
              ),
          ]),
        )
      ],
    );
  }
}
