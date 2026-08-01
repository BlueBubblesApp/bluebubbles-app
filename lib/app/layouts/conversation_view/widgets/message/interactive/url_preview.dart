import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _UrlPreviewState extends State<UrlPreview> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  UrlPreviewData get data => widget.data;
  UrlPreviewData? dataOverride;
  PlatformFile? get resolvedContent => content is PlatformFile ? content as PlatformFile : null;
  File? get file => resolvedContent?.path != null ? File(resolvedContent!.path!) : null;
  Object? content;
  UrlMetadata? _fetchedMetadata;
  String? _previewImagePath;
  String? _iconImagePath;
  bool _previewImageFromDisk = false;
  late final AnimationController _imageAnimController;
  Worker? _refreshWorker;

  @override
  bool get wantKeepAlive => true;

  /// Sets [_previewImagePath] and starts the grow-in animation for fresh
  /// downloads. Disk-loaded images are shown immediately without animation.
  void _setPreviewImagePath(String path, {required bool fromDisk}) {
    if (!mounted) return;
    setState(() {
      _previewImagePath = path;
      _previewImageFromDisk = fromDisk;
    });
    if (!fromDisk) {
      _imageAnimController.forward(from: 0);
    }
  }

  /// Resolves an image URL to a local disk file. If the hash is already stored
  /// on the message and the file exists on disk, [onResult] is called
  /// immediately with `fromDisk: true` (no animation). Otherwise the image is
  /// downloaded, validated, saved, and [onResult] is called with
  /// `fromDisk: false`.
  Future<void> _resolveImage({
    required String imageUrl,
    required Message message,
    required void Function(CachedPreviewImage image) onResult,
    bool isIcon = false,
  }) async {
    if (kIsWeb) return;
    final result = await MetadataHelper.resolveCachedImage(message, imageUrl, isIcon: isIcon);
    if (result != null) onResult(result);
  }

  @override
  void initState() {
    super.initState();
    _imageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    // UrlPreview is also used outside a message context (links/locations
    // sections in conversation details), so look up the scope defensively
    // rather than asserting one exists.
    final messageState = context.findAncestorWidgetOfExactType<MessageStateScope>()?.messageState;
    if (messageState != null) {
      _refreshWorker = ever(messageState.previewRefreshKey, (_) {
        if (!mounted) return;
        setState(() {
          content = null;
          dataOverride = null;
          _fetchedMetadata = null;
          _previewImagePath = null;
          _iconImagePath = null;
          _previewImageFromDisk = false;
        });
        unawaited(_init());
      });
    }
    unawaited(_init());
  }

  @override
  void dispose() {
    _refreshWorker?.dispose();
    _imageAnimController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (widget.file != null) {
      await _initLocationPreview();
    } else {
      await _initMessagePreview();
    }
  }

  /// Handles Apple Maps location widget previews (the vCard file attachment path).
  Future<void> _initLocationPreview() async {
    String? location;
    if (kIsWeb || widget.file!.path == null) {
      location = utf8.decode(widget.file!.bytes!);
    } else {
      location = await File(widget.file!.path!).readAsString();
    }

    final mapsUrl = AttachmentsSvc.parseAppleLocationUrl(location)
        ?.replaceAll("\\", "")
        .replaceAll("http:", "https:")
        .replaceAll("/?", "/place?")
        .replaceAll(",", "%2C");
    if (mapsUrl == null) return;

    dataOverride = UrlPreviewData(title: data.title, siteName: data.siteName)..url = mapsUrl;
    if (mounted) setState(() {});

    // A single fetch now covers both halves of this: `AppleMapsSiteParser`
    // pulls the place title and the canonical "open in Maps" link out of the
    // same document the preview metadata comes from. This used to download the
    // page twice — once here for the link, once inside the metadata library.
    final metadata = (await MetadataHelper.fetchForUrl(mapsUrl)).metadata;
    if (metadata == null || !mounted) return;

    setState(() {
      if (metadata.imageUrl != null) {
        dataOverride!.imageMetadata = MediaMetadata(size: const Size.square(1), url: metadata.imageUrl);
      }
      dataOverride!.summary = metadata.description ?? metadata.title;
      dataOverride!.url = metadata.canonicalUrl ?? mapsUrl;
    });
  }

  /// Top-level coordinator for standard message URL previews.
  Future<void> _initMessagePreview() async {
    final message = context.findAncestorWidgetOfExactType<MessageStateScope>()?.messageState.message;
    if (message == null) return;

    // Use getInheritedWidgetOfExactType (no dependency registration) since this
    // runs during initState where dependOnInheritedWidgetOfExactType is illegal.
    final inReply = context.getInheritedWidgetOfExactType<ReplyScope>() != null;

    if (await _resolvePluginPayloadAttachment(message)) return;
    await _resolveServerImages(message, inReply);
    await _fetchMissingMetadata(message, inReply);
  }

  /// Checks for a plugin payload attachment (e.g. Apple Music). Returns true
  /// and populates [content] if one is found — callers should stop further work.
  Future<bool> _resolvePluginPayloadAttachment(Message message) async {
    if (data.imageMetadata?.url != null || data.iconMetadata?.url != null) return false;

    final attachment =
        message.dbAttachments.firstWhereOrNull((e) => e.transferName?.contains("pluginPayloadAttachment") ?? false);
    if (attachment == null) return false;

    content = AttachmentsSvc.getContent(attachment, autoDownload: true, onComplete: (file) {
      if (mounted) {
        setState(() {
          content = file;
        });
      }
    });
    if (content is PlatformFile && mounted) setState(() {});
    return true;
  }

  /// Resolves server-provided image and icon URLs to disk-cached files.
  Future<void> _resolveServerImages(Message message, bool inReply) async {
    if (data.imageMetadata?.url != null && !inReply) {
      await _resolveImage(
        imageUrl: data.imageMetadata!.url!,
        message: message,
        onResult: (image) => _setPreviewImagePath(image.path, fromDisk: image.fromDisk),
      );
    }

    if (data.iconMetadata?.url != null) {
      await _resolveImage(
        imageUrl: data.iconMetadata!.url!,
        message: message,
        isIcon: true,
        onResult: (image) {
          if (mounted) setState(() => _iconImagePath = image.path);
        },
      );
    }
  }

  /// Fetches metadata when the server provided no image or icon.
  ///
  /// Cached metadata is restored first; a fresh fetch only runs when the store
  /// says the last attempt has aged out (or never happened).
  Future<void> _fetchMissingMetadata(Message message, bool inReply) async {
    final hasServerImages = data.imageMetadata?.url != null || data.iconMetadata?.url != null;
    if (hasServerImages || message.url == null) return;

    final cached = MessageMetadataStore.read(message);
    if (cached != null) {
      await _applyMetadata(message, cached, inReply, persist: false);

      // Real metadata never goes stale. A cache entry holding only a site name
      // is the fallback written after a failed attempt, so it is retried once
      // the store's TTL elapses rather than sticking forever.
      if (cached.hasDisplayableContent || !MessageMetadataStore.shouldFetch(message)) return;
    } else if (!MessageMetadataStore.shouldFetch(message)) {
      return;
    }

    await _runMetadataFetch(message, inReply);
  }

  /// Performs a live metadata fetch, persists the result and downloads the
  /// preview image.
  ///
  /// Transient failures (timeouts, socket errors, 5xx, rate limiting) are left
  /// unrecorded so the next build retries; permanent ones are stamped so the
  /// fetch is not repeated until the store's TTL elapses.
  Future<void> _runMetadataFetch(Message message, bool inReply) async {
    final result = await MetadataHelper.fetchForMessage(message);

    if (!result.isSuccess) {
      // A site parser may still have supplied a usable icon or site name for a
      // link the site itself refused to describe.
      final partial = result.metadata;
      if (partial != null && partial.isNotEmpty) {
        await _applyMetadata(message, partial, inReply, persist: result.shouldMarkAttempted);
        return;
      }

      if (result.shouldMarkAttempted) MessageMetadataStore.markAttempted(message);
      return;
    }

    await _applyMetadata(message, result.metadata!, inReply, persist: true);
  }

  /// Renders [metadata], resolving its image and icon, and optionally writes
  /// it back to the message.
  Future<void> _applyMetadata(
    Message message,
    UrlMetadata metadata,
    bool inReply, {
    required bool persist,
  }) async {
    if (mounted) setState(() => _fetchedMetadata = metadata);

    if (kIsWeb) {
      if (persist) MessageMetadataStore.write(message, metadata);
      return;
    }

    String? imageHash;
    String? iconHash;

    // Reply bubbles render text only, so downloading a hero image for them is
    // wasted bandwidth and disk.
    final imageUrl = metadata.imageUrl;
    if (!inReply && imageUrl != null) {
      final image = await MetadataHelper.resolveCachedImage(message, imageUrl);
      if (image != null) {
        imageHash = image.md5;
        _setPreviewImagePath(image.path, fromDisk: image.fromDisk);
      }
    }

    final iconUrl = metadata.iconUrl;
    if (iconUrl != null) {
      final icon = await MetadataHelper.resolveCachedImage(message, iconUrl, isIcon: true);
      if (icon != null) {
        iconHash = icon.md5;
        if (mounted) setState(() => _iconImagePath = icon.path);
      }
    }

    if (persist) {
      MessageMetadataStore.write(message, metadata, imageHash: imageHash, iconHash: iconHash);
    }
  }

  /// Builds the preview image container. When [animate] is true (fresh
  /// download) the container is wrapped in [AnimatedSize] so it grows in
  /// smoothly. When [animate] is false (disk load or web) it is returned as-is
  /// to avoid the re-entrancy crash that occurs when [AnimatedSize] ticks its
  /// animation controller during its own [performLayout].
  Widget _buildPreviewImage(BuildContext context, {required bool animate, String? webImageUrl}) {
    final ImageProvider imageProvider =
        _previewImagePath != null ? FileImage(File(_previewImagePath!)) : NetworkImage(webImageUrl!) as ImageProvider;

    final container = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: context.height * 0.4, minHeight: 100),
                child: _previewImagePath != null
                    ? Image.file(
                        File(_previewImagePath!),
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => Center(
                          heightFactor: 1,
                          child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                        ),
                      )
                    : Image.network(
                        webImageUrl ?? '',
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => Center(
                          heightFactor: 1,
                          child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!animate) return container;

    // SizeTransition animates via the ticker between frames (not during
    // performLayout), so it never causes the re-entrancy crash that
    // AnimatedSize triggers when a child changes size during layout.
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _imageAnimController, curve: Curves.easeIn),
      axisAlignment: -1.0,
      child: container,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final message = MessageStateScope.maybeMessageOf(context);
    // Web-only fallback: disk caching is unavailable on web, so fall back to network image.
    final webImageUrl = kIsWeb ? (data.imageMetadata?.url ?? _fetchedMetadata?.imageUrl) : null;
    // Prefer the site name the page declared (`og:site_name`) over the bare
    // host, falling back to the host when nothing declared one.
    final _rawSiteText = widget.file != null
        ? (dataOverride?.siteName ?? "")
        : data.siteName ??
            _fetchedMetadata?.siteName ??
            Uri.tryParse(data.originalUrl ?? data.url ?? "")?.host;
    final siteText = _rawSiteText?.replaceFirst(RegExp(r'^www\.'), '');
    // Show the plugin-payload attachment image only when no disk-cached preview is available.
    final hasAppleImage = _previewImagePath == null && webImageUrl == null;
    final _data = dataOverride ?? data;
    final inReply = ReplyScope.maybeOf(context) != null;
    return InkWell(
      onTap: widget.file != null && (_data.originalUrl ?? _data.url) != null
          ? () async {
              await launchUrl(Uri.parse(_data.originalUrl ?? _data.url!), mode: LaunchMode.externalApplication);
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!inReply && (_previewImagePath != null || webImageUrl != null))
            _buildPreviewImage(context,
                animate: _previewImagePath != null && !_previewImageFromDisk, webImageUrl: webImageUrl),
          if (resolvedContent?.bytes != null && hasAppleImage && !inReply)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: MemoryImage(resolvedContent!.bytes!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: context.height * 0.4, minHeight: 100),
                      child: Image.memory(
                        resolvedContent!.bytes!,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (context, object, stacktrace) => Center(
                          heightFactor: 1,
                          child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (resolvedContent != null && hasAppleImage && resolvedContent?.bytes == null && file != null && !inReply)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: FileImage(file!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: context.height * 0.4, minHeight: 100),
                      child: Image.file(
                        file!,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (context, object, stacktrace) => Center(
                          heightFactor: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 5.0),
                            child: Row(children: [
                              Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
                              const SizedBox(width: 2.0),
                              IconButton(
                                  onPressed: () {
                                    showBBDialog(
                                      context: context,
                                      title: "URL Preview Stacktrace",
                                      content: SizedBox(
                                        width: NavigationSvc.width(context) * 3 / 5,
                                        height: context.height * 1 / 4,
                                        child: Container(
                                          padding: const EdgeInsets.all(10.0),
                                          decoration: BoxDecoration(
                                              color: context.theme.colorScheme.surface,
                                              borderRadius: const BorderRadius.all(Radius.circular(10))),
                                          child: SingleChildScrollView(
                                            child: SelectableText(
                                              stacktrace.toString(),
                                              style: context.theme.textTheme.bodyLarge,
                                            ),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        BBDialogAction(
                                          text: "Close",
                                          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                                        ),
                                      ],
                                    );
                                  },
                                  icon: const Icon(CupertinoIcons.info_circle))
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: inReply
                ? const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0)
                : const EdgeInsets.fromLTRB(15.0, 20, 15.0, 15.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child:
                      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // The `!= "www"` guards that used to live here existed
                    // because the old metadata library defaulted a failed
                    // fetch's title to the first dot-segment of the host. The
                    // parser no longer invents titles, so a null title now
                    // genuinely means the page had none.
                    Text(
                      !isNullOrEmpty(_data.title)
                          ? _data.title!
                          : !isNullOrEmpty(_fetchedMetadata?.title)
                              ? _fetchedMetadata!.title!
                              : !isNullOrEmpty(siteText)
                                  ? siteText!
                                  : message?.text ?? '',
                      style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((!isNullOrEmpty(_data.summary) || !isNullOrEmpty(_fetchedMetadata?.description)) && !inReply)
                      const SizedBox(height: 5),
                    if ((!isNullOrEmpty(_data.summary) || !isNullOrEmpty(_fetchedMetadata?.description)) && !inReply)
                      Text(_data.summary ?? _fetchedMetadata?.description ?? "",
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)),
                    if (!isNullOrEmpty(siteText) && !inReply) const SizedBox(height: 5),
                    if (!isNullOrEmpty(siteText) && !inReply)
                      Text(
                        siteText!,
                        style: context.theme.textTheme.labelMedium!
                            .copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                        overflow: TextOverflow.clip,
                        maxLines: 1,
                      ),
                    if (!isNullOrEmpty(siteText) && inReply) const SizedBox(height: 5),
                    if (!isNullOrEmpty(siteText) && inReply)
                      Text(
                        siteText!,
                        style: context.theme.textTheme.labelMedium!
                            .copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ]),
                ),
                if (_data.iconMetadata?.url != null || _iconImagePath != null) const SizedBox(width: 10),
                if (_data.iconMetadata?.url != null || _iconImagePath != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 45,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _iconImagePath != null
                          ? Image.file(
                              File(_iconImagePath!),
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.none,
                            )
                          : Image.network(
                              _data.iconMetadata!.url!,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.none,
                            ),
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
