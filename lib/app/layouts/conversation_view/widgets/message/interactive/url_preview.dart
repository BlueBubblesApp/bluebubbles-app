import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'dart:ui';

import 'package:bluebubbles/app/state/message_state_scope.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_bubble.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart' as parser;
import 'package:metadata_fetch/metadata_fetch.dart';
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
  Metadata? _fetchedMetadata;
  String? _previewImagePath;
  String? _iconImagePath;
  bool _previewImageFromDisk = false;
  late final AnimationController _imageAnimController;
  Worker? _refreshWorker;

  /// Incremented on every [_init] run. A run whose token no longer matches has
  /// been superseded by a refresh and must not write state — otherwise a slow
  /// in-flight fetch can land after the refresh reset and restore the very
  /// values the refresh just cleared.
  int _initToken = 0;

  bool _isStale(int token) => !mounted || token != _initToken;

  @override
  bool get wantKeepAlive => true;

  /// Sets [_previewImagePath] and starts the grow-in animation for fresh
  /// downloads. Disk-loaded images are shown immediately without animation.
  void _setPreviewImagePath(String path, {required bool fromDisk, required int token}) {
    if (_isStale(token)) return;
    setState(() {
      _previewImagePath = path;
      _previewImageFromDisk = fromDisk;
    });
    if (!fromDisk) {
      _imageAnimController.forward(from: 0);
    }
  }

  /// Resolves an image URL to a local disk file. If the MD5 hash is already
  /// stored in [message.metadata] and the file exists on disk, [onResult] is
  /// called immediately with [fromDisk] = true (no animation). Otherwise the
  /// image is downloaded, saved and [onResult] is called with [fromDisk] = false.
  Future<void> _resolveImage({
    required String imageUrl,
    required String metadataKey,
    required Message message,
    required void Function(String path, bool fromDisk) onResult,
    bool optimize = false,
  }) async {
    if (kIsWeb) return;
    final result = await MetadataHelper.resolveCachedImage(message, metadataKey, imageUrl, optimize: optimize);
    if (result != null) onResult(result.$1, result.$2);
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
    // Deferred off the build phase. _init's first leg runs synchronously up to
    // its first real await, and _resolvePluginPayloadAttachment has none — it
    // calls setState and kicks off an auto-download (which writes observables
    // other widgets may be listening to) straight from initState, i.e. from
    // inside the ancestor's build.
    unawaited(Future.microtask(_init));
  }

  @override
  void dispose() {
    _refreshWorker?.dispose();
    _imageAnimController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    if (!mounted) return;
    final token = ++_initToken;
    if (widget.file != null) {
      await _initLocationPreview(token);
    } else {
      await _initMessagePreview(token);
    }
  }

  /// Handles Apple Maps location widget previews (the vCard file attachment path).
  Future<void> _initLocationPreview(int token) async {
    String? location;
    if (kIsWeb || widget.file!.path == null) {
      location = utf8.decode(widget.file!.bytes!);
    } else {
      location = await File(widget.file!.path!).readAsString();
    }

    dataOverride = UrlPreviewData(title: data.title, siteName: data.siteName);
    dataOverride!.url = AttachmentsSvc.parseAppleLocationUrl(location)
        ?.replaceAll("\\", "")
        .replaceAll("http:", "https:")
        .replaceAll("/?", "/place?")
        .replaceAll(",", "%2C");
    if (dataOverride!.url == null) return;

    final response = await HttpSvc.dio.get(dataOverride!.url!,
        options: Options(followRedirects: true, maxRedirects: 2));
    final document = parser.parse(response.data);
    final link = document
        .getElementsByClassName("sc-platter-cell")
        .firstOrNull
        ?.children
        .firstWhereOrNull((e) => e.localName == "a");
    final url = link?.attributes["href"];
    if (url == null) return;

    MetadataFetch.extract(dataOverride!.url!).then((metadata) {
      if (metadata?.image != null) {
        dataOverride!.imageMetadata = MediaMetadata(size: const Size.square(1), url: metadata!.image);
        dataOverride!.summary = metadata.description ?? metadata.title;
        dataOverride!.url = url;
        if (!_isStale(token)) setState(() {});
      }
    });
  }

  /// Top-level coordinator for standard message URL previews.
  Future<void> _initMessagePreview(int token) async {
    final message = context.findAncestorWidgetOfExactType<MessageStateScope>()?.messageState.message;
    if (message == null) return;

    // Use getInheritedWidgetOfExactType (no dependency registration) since this
    // runs during initState where dependOnInheritedWidgetOfExactType is illegal.
    final inReply = context.getInheritedWidgetOfExactType<ReplyScope>() != null;

    if (await _resolvePluginPayloadAttachment(message, token)) return;
    await _resolveServerImages(message, inReply, token);
    await _fetchMissingMetadata(message, inReply, token);
  }

  /// Checks for a plugin payload attachment (e.g. Apple Music). Returns true
  /// and populates [content] if one is found — callers should stop further work.
  Future<bool> _resolvePluginPayloadAttachment(Message message, int token) async {
    if (data.imageMetadata?.url != null || data.iconMetadata?.url != null) return false;

    final attachment =
        message.dbAttachments.firstWhereOrNull((e) => e.transferName?.contains("pluginPayloadAttachment") ?? false);
    if (attachment == null) return false;

    content = AttachmentsSvc.getContent(attachment, autoDownload: true, onComplete: (file) {
      if (_isStale(token)) return;
      setState(() {
        content = file;
      });
    });
    if (content is PlatformFile && !_isStale(token)) setState(() {});
    return true;
  }

  /// Resolves server-provided image and icon URLs to disk-cached files.
  Future<void> _resolveServerImages(Message message, bool inReply, int token) async {
    if (data.imageMetadata?.url != null && !inReply) {
      await _resolveImage(
        imageUrl: data.imageMetadata!.url!,
        metadataKey: 'previewImageMd5',
        message: message,
        // Icons are left alone: they are already tiny, and re-encoding a PNG
        // favicon as JPEG would flatten its alpha.
        optimize: true,
        onResult: (path, fromDisk) => _setPreviewImagePath(path, fromDisk: fromDisk, token: token),
      );
    }

    if (data.iconMetadata?.url != null) {
      await _resolveImage(
        imageUrl: data.iconMetadata!.url!,
        metadataKey: 'previewIconMd5',
        message: message,
        onResult: (path, _) {
          if (_isStale(token)) return;
          setState(() {
            _iconImagePath = path;
          });
        },
      );
    }
  }

  /// Fetches OG metadata when the server provided no image/icon. Skips if
  /// metadata was already fetched successfully, or retries if the last attempt
  /// failed due to a network error (so the flag is not set on network failures).
  Future<void> _fetchMissingMetadata(Message message, bool inReply, int token) async {
    final hasServerImages = data.imageMetadata?.url != null || data.iconMetadata?.url != null;
    if (hasServerImages || message.url == null) return;

    if (MetadataHelper.mapIsNotEmpty(message.metadata)) {
      await _restoreCachedMetadata(message, inReply, token);
      return;
    }

    if (MetadataHelper.hasAttemptedFetch(message.metadata)) return;

    await _runMetadataFetch(message, inReply, token);
  }

  /// Restores previously fetched metadata from [message.metadata] and
  /// re-resolves the cached preview image if available.
  Future<void> _restoreCachedMetadata(Message message, bool inReply, int token) async {
    final meta = Metadata.fromJson(message.metadata!);
    if (_isStale(token)) return;
    setState(() {
      _fetchedMetadata = meta;
    });
    if (kIsWeb || inReply || meta.image == null) return;

    await _resolveImage(
      imageUrl: meta.image!,
      metadataKey: 'previewImageMd5',
      message: message,
      optimize: true,
      onResult: (path, fromDisk) => _setPreviewImagePath(path, fromDisk: fromDisk, token: token),
    );
  }

  /// Performs a live OG metadata fetch, caches the result, and downloads the
  /// preview image. Network errors are not marked as "attempted" so the next
  /// load can retry; non-network errors are marked to avoid repeated fetches.
  Future<void> _runMetadataFetch(Message message, bool inReply, int token) async {
    try {
      final fetched = await MetadataHelper.fetchMetadata(message);
      final metaMap = <String, dynamic>{
        ...?message.metadata,
        ...(fetched?.toJson() ?? {}),
        'previewImageFetched': true,
      };

      if (!kIsWeb && !inReply && fetched?.image != null) {
        try {
          final response = await HttpSvc.dio.get<List<int>>(
            fetched!.image!,
            options: Options(responseType: ResponseType.bytes, followRedirects: true, maxRedirects: 2),
          );
          final bytes = response.data;
          if (bytes != null && bytes.isNotEmpty) {
            final hash = await FilesystemSvc.saveUrlPreviewImage(Uint8List.fromList(bytes));
            metaMap['previewImageMd5'] = hash;
            _setPreviewImagePath(FilesystemSvc.urlPreviewImagePath(hash), fromDisk: false, token: token);
          }
        } catch (ex, stack) {
          Logger.warn('Failed to download URL preview image', error: ex, trace: stack, tag: 'UrlPreview');
        }
      }

      message.metadata = metaMap;
      if (!kIsWeb && message.id != null) message.save();
      if (_isStale(token)) return;
      setState(() {
        _fetchedMetadata = fetched;
      });
    } on SocketException catch (ex, stack) {
      Logger.warn('Network unavailable for URL preview fetch; will retry', error: ex, trace: stack, tag: 'UrlPreview');
    } on TimeoutException catch (ex, stack) {
      Logger.warn('Timeout during URL preview fetch; will retry', error: ex, trace: stack, tag: 'UrlPreview');
    } catch (ex, stack) {
      Logger.error('Failed to fetch URL preview metadata', error: ex, trace: stack, tag: 'UrlPreview');
      message.metadata = {...?message.metadata, 'previewImageFetched': true};
      if (!kIsWeb && message.id != null) message.save();
    }
  }

  /// Builds the preview image container.
  ///
  /// When the cached image's dimensions are known ([knownSize], recorded at
  /// cache time by [MetadataHelper.resolveCachedImage]) the exact box is
  /// reserved before the image decodes, so the card never resizes as the frame
  /// lands. That is the common path — every scroll past an already-cached
  /// preview. It also lets the decode be bounded to the pixels actually drawn.
  ///
  /// [animate] applies only to a first-ever download, where there is no way to
  /// know the size ahead of the bytes; the container grows in via
  /// [SizeTransition] rather than snapping. SizeTransition animates on the
  /// ticker between frames, unlike AnimatedSize, which drives its controller
  /// during its own performLayout and crashes on re-entrancy here.
  Widget _buildPreviewImage(BuildContext context, {required bool animate, String? webImageUrl, Size? knownSize}) {
    final ImageProvider imageProvider =
        _previewImagePath != null ? FileImage(File(_previewImagePath!)) : NetworkImage(webImageUrl!) as ImageProvider;
    final maxHeight = context.height * 0.4;

    Widget image({double? width, double? height, int? cacheWidth}) {
      Widget onError(BuildContext context) => Center(
            heightFactor: 1,
            child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge),
          );
      // filterQuality was `none` (nearest-neighbour), which visibly aliases any
      // downscaled photo. `medium` is the right pick now that the decode is
      // bounded near the drawn size, so there is little scaling left to do.
      if (_previewImagePath != null) {
        return Image.file(
          File(_previewImagePath!),
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          width: width,
          height: height,
          cacheWidth: cacheWidth,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => onError(context),
        );
      }
      return Image.network(
        webImageUrl ?? '',
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        width: width,
        height: height,
        cacheWidth: cacheWidth,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => onError(context),
      );
    }

    // Unsized fallback: dimensions unknown, so the image defines the box once it
    // decodes (the pre-existing behaviour).
    Widget sizedImage = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, minHeight: 100),
      child: image(),
    );

    if (knownSize != null) {
      sizedImage = LayoutBuilder(
        builder: (context, constraints) {
          // A LayoutBuilder can legitimately be handed an unbounded width; fall
          // back rather than producing NaN.
          if (!constraints.hasBoundedWidth) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight, minHeight: 100),
              child: image(),
            );
          }
          // Mirrors what RenderImage would have computed from the decoded
          // bitmap: scale to the card width, then clamp to the height bounds.
          final aspect = knownSize.width / knownSize.height;
          final boxHeight = (constraints.maxWidth / aspect).clamp(100.0, maxHeight);
          final boxWidth = min(constraints.maxWidth, boxHeight * aspect);
          return SizedBox(
            height: boxHeight,
            width: constraints.maxWidth,
            child: Center(
              child: image(
                width: boxWidth,
                height: boxHeight,
                // Display space, width only — passing both axes makes
                // ResizeImagePolicy.exact behave like BoxFit.fill.
                cacheWidth: (boxWidth * MediaQuery.devicePixelRatioOf(context)).round().clamp(1, 4096),
              ),
            ),
          );
        },
      );
    }

    final container = ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Center(heightFactor: 1, child: sizedImage),
          ),
        ),
      ),
    );

    // Nothing to animate once the box is reserved up front.
    if (!animate || knownSize != null) return container;

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
    final webImageUrl = kIsWeb ? (data.imageMetadata?.url ?? _fetchedMetadata?.image) : null;
    final _rawSiteText = widget.file != null
        ? (dataOverride?.siteName ?? "")
        : Uri.tryParse(data.originalUrl ?? data.url ?? "")?.host ?? data.siteName;
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
            _buildPreviewImage(
              context,
              animate: _previewImagePath != null && !_previewImageFromDisk,
              webImageUrl: webImageUrl,
              // Only meaningful for the disk-cached path; a network image on web
              // has no recorded size.
              knownSize: _previewImagePath != null ? MetadataHelper.cachedImageSize(message, 'previewImageMd5') : null,
            ),
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
                    Text(
                      !isNullOrEmpty(_data.title) && _data.title != "www"
                          ? _data.title!
                          : !isNullOrEmpty(_fetchedMetadata?.title) && _fetchedMetadata?.title != "www"
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
                      // The icon never draws wider than 45pt, so cap the decode
                      // there — some sites serve a 512px app icon as their
                      // favicon.
                      child: _iconImagePath != null
                          ? Image.file(
                              File(_iconImagePath!),
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              cacheWidth: (45 * MediaQuery.devicePixelRatioOf(context)).round(),
                            )
                          : Image.network(
                              _data.iconMetadata!.url!,
                              gaplessPlayback: true,
                              filterQuality: FilterQuality.medium,
                              cacheWidth: (45 * MediaQuery.devicePixelRatioOf(context)).round(),
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
