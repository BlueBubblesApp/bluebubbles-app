import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

/// All fetch, cache and policy wiring for a URL preview card.
///
/// Owns every piece of state the card renders; the skin widgets
/// (`CupertinoUrlPreview`, `ExpressiveUrlPreview`) are presentation only and
/// read from here. Keeping this in one place matters more than usual — it is
/// the code that carries the sender policy, the disk-cache reuse and the
/// retry-TTL bookkeeping, none of which should ever be duplicated per skin.
///
/// Deliberately **not** a `GetxController` registered with `Get.put`. There is
/// no stable tag available when the widget is constructed — the message GUID
/// only becomes reachable through `MessageStateScope` once there is a
/// `BuildContext` — and registering under a random tag would defeat the point.
/// It is instead owned by `_UrlPreviewState`, created in `initState` so a
/// parent rebuild cannot silently replace it, and disposed with the widget.
class UrlPreviewController {
  UrlPreviewController({
    required this.data,
    required this.file,
    required TickerProvider vsync,
  }) {
    imageAnimation = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
  }

  /// Server-supplied preview payload (Apple's own metadata for this message).
  final UrlPreviewData data;

  /// Set for the Apple Maps location-attachment variant, which renders from a
  /// vCard on disk rather than from a link in the message.
  final PlatformFile? file;

  /// Drives the grow-in for a freshly downloaded preview image.
  late final AnimationController imageAnimation;

  // ---------------------------------------------------------------------------
  // Rendered state
  // ---------------------------------------------------------------------------

  /// Replaces [data] for the location variant, once the Maps page resolves.
  final Rxn<UrlPreviewData> dataOverride = Rxn<UrlPreviewData>();

  /// Plugin-payload attachment content (Apple Music and friends).
  final Rxn<Object> content = Rxn<Object>();

  /// Metadata fetched from the page, when the server supplied none.
  final Rxn<UrlMetadata> fetchedMetadata = Rxn<UrlMetadata>();

  final RxnString previewImagePath = RxnString();
  final RxnString iconImagePath = RxnString();

  /// True when the preview image came off disk, so the card skips the grow-in.
  final RxBool previewImageFromDisk = false.obs;

  /// True when there is a preview to load but the policy says not to fetch it
  /// automatically. Drives the tap-to-load affordance.
  final RxBool needsManualLoad = false.obs;

  /// True while a user-initiated load is running.
  final RxBool manualLoadRunning = false.obs;

  MessageState? _messageState;
  bool _inReply = false;
  Worker? _refreshWorker;
  bool _disposed = false;

  Message? get message => _messageState?.message;

  // ---------------------------------------------------------------------------
  // Derived values shared by every skin
  // ---------------------------------------------------------------------------

  /// The payload actually being rendered — the location override when present.
  UrlPreviewData get effectiveData => dataOverride.value ?? data;

  PlatformFile? get resolvedContent => content.value is PlatformFile ? content.value as PlatformFile : null;

  File? get contentFile => resolvedContent?.path != null ? File(resolvedContent!.path!) : null;

  /// Web-only fallback: disk caching is unavailable there, so the card falls
  /// back to a network image.
  String? get webImageUrl => kIsWeb ? (data.imageMetadata?.url ?? fetchedMetadata.value?.imageUrl) : null;

  /// Show the plugin-payload attachment image only when no disk-cached preview
  /// is available.
  bool get showsAppleImage => previewImagePath.value == null && webImageUrl == null;

  bool get hasIcon => effectiveData.iconMetadata?.url != null || iconImagePath.value != null;

  /// The site line.
  ///
  /// Derived from the URL, **never** from `og:site_name`, which is
  /// attacker-controlled text — a phishing page at any domain can declare
  /// itself "Apple", and this is the one line on the card a user relies on to
  /// tell them otherwise. The declared site name is still parsed and stored; it
  /// earns its keep by letting `MetadataText.stripSiteSuffix` trim
  /// " - Site Name" off titles. `data.siteName` below comes from Apple's own
  /// payload via the server, not from the page, so it remains an acceptable
  /// last resort.
  String? get siteText {
    final raw = file != null
        ? (dataOverride.value?.siteName ?? "")
        : Uri.tryParse(data.originalUrl ?? data.url ?? "")?.host ?? data.siteName;
    return raw?.replaceFirst(RegExp(r'^www\.'), '');
  }

  /// Title to render, falling back through the payload, the fetched metadata,
  /// the host, and finally the raw message text.
  ///
  /// There is deliberately no `!= "www"` guard here. The old metadata library
  /// defaulted a failed fetch's title to the first dot-segment of the host, so
  /// the card had to filter that out; the current parser never invents a title,
  /// so a null title genuinely means the page had none.
  String titleFor(String? messageText) {
    final payloadTitle = effectiveData.title;
    if (!isNullOrEmpty(payloadTitle)) return payloadTitle!;

    final metadataTitle = fetchedMetadata.value?.title;
    if (!isNullOrEmpty(metadataTitle)) return metadataTitle!;

    final site = siteText;
    if (!isNullOrEmpty(site)) return site!;

    return messageText ?? '';
  }

  String? get summary => effectiveData.summary ?? fetchedMetadata.value?.description;

  bool get hasSummary =>
      !isNullOrEmpty(effectiveData.summary) || !isNullOrEmpty(fetchedMetadata.value?.description);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Binds the controller to its message scope and kicks off the initial load.
  ///
  /// [messageState] is null when the card is rendered outside a message (the
  /// links and locations sections of conversation details).
  void attach({required MessageState? messageState, required bool inReply}) {
    _messageState = messageState;
    _inReply = inReply;

    if (messageState != null) {
      _refreshWorker = ever(messageState.previewRefreshKey, (_) {
        if (_disposed) return;
        content.value = null;
        dataOverride.value = null;
        fetchedMetadata.value = null;
        previewImagePath.value = null;
        iconImagePath.value = null;
        previewImageFromDisk.value = false;
        needsManualLoad.value = false;
        manualLoadRunning.value = false;
        unawaited(load());
      });
    }

    unawaited(load());
  }

  void dispose() {
    _disposed = true;
    _refreshWorker?.dispose();
    imageAnimation.dispose();
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    if (file != null) {
      await _loadLocationPreview();
    } else {
      await _loadMessagePreview();
    }
  }

  /// Loads the preview in response to an explicit tap.
  ///
  /// A tap is consent, so this re-enters the normal flow with the policy forced
  /// open. That covers both shapes: a server-supplied image that was gated, and
  /// a link whose metadata has never been fetched. Every other protection —
  /// host guard, per-hop redirect vetting, size caps, image validation — still
  /// applies.
  Future<void> loadManually() async {
    if (manualLoadRunning.value) return;

    manualLoadRunning.value = true;
    try {
      await _loadMessagePreview(force: true);
    } finally {
      if (!_disposed) {
        manualLoadRunning.value = false;
        needsManualLoad.value = false;
      }
    }
  }

  /// Apple Maps location widget previews (the vCard attachment path).
  Future<void> _loadLocationPreview() async {
    String? location;
    if (kIsWeb || file!.path == null) {
      location = utf8.decode(file!.bytes!);
    } else {
      location = await File(file!.path!).readAsString();
    }

    final mapsUrl = AttachmentsSvc.parseAppleLocationUrl(location)
        ?.replaceAll("\\", "")
        .replaceAll("http:", "https:")
        .replaceAll("/?", "/place?")
        .replaceAll(",", "%2C");
    if (mapsUrl == null) return;

    dataOverride.value = UrlPreviewData(title: data.title, siteName: data.siteName)..url = mapsUrl;

    // A single fetch covers both halves of this: `AppleMapsSiteParser` pulls the
    // place title and the canonical "open in Maps" link out of the same document
    // the preview metadata comes from. This used to download the page twice —
    // once here for the link, once inside the metadata library.
    final metadata = (await MetadataHelper.fetchForUrl(mapsUrl)).metadata;
    if (metadata == null || _disposed) return;

    final override = dataOverride.value;
    if (override == null) return;
    if (metadata.imageUrl != null) {
      override.imageMetadata = MediaMetadata(size: const Size.square(1), url: metadata.imageUrl);
    }
    override.summary = metadata.description ?? metadata.title;
    override.url = metadata.canonicalUrl ?? mapsUrl;
    dataOverride.refresh();
  }

  /// Standard message URL previews.
  ///
  /// Set [force] when the user tapped to load, which skips the sender policy.
  Future<void> _loadMessagePreview({bool force = false}) async {
    final msg = message;
    if (msg == null) return;

    if (await _resolvePluginPayloadAttachment(msg)) return;

    // Resolved once and threaded through both branches, so scrolling a chat
    // costs at most one contact lookup per message rather than one per image.
    final canFetch = force || await MetadataHelper.shouldAutoFetch(msg);

    if (data.imageMetadata?.url != null || data.iconMetadata?.url != null) {
      await _resolveServerImages(msg, bypassGate: canFetch);

      // The card's title and summary arrived with the message, but its image
      // sits on a third-party host, so fetching that is an outbound request
      // like any other and is gated the same way. Anything already on disk was
      // returned above without touching the network.
      final imageStillMissing = data.imageMetadata?.url != null && previewImagePath.value == null && !_inReply;
      if (!canFetch && imageStillMissing && !_disposed) {
        needsManualLoad.value = true;
      }
      return;
    }

    await _fetchMissingMetadata(msg, canFetch: canFetch);
  }

  /// Checks for a plugin payload attachment (e.g. Apple Music). Returns true
  /// and populates [content] if one is found — callers should stop further work.
  Future<bool> _resolvePluginPayloadAttachment(Message msg) async {
    if (data.imageMetadata?.url != null || data.iconMetadata?.url != null) return false;

    final attachment =
        msg.dbAttachments.firstWhereOrNull((e) => e.transferName?.contains("pluginPayloadAttachment") ?? false);
    if (attachment == null) return false;

    content.value = AttachmentsSvc.getContent(attachment, autoDownload: true, onComplete: (loaded) {
      if (!_disposed) content.value = loaded;
    });
    return true;
  }

  /// Resolves server-provided image and icon URLs to disk-cached files.
  ///
  /// A disk hit is always served; [bypassGate] only decides whether a cache
  /// miss may go to the network.
  Future<void> _resolveServerImages(Message msg, {required bool bypassGate}) async {
    if (data.imageMetadata?.url != null && !_inReply) {
      final image = await MetadataHelper.resolveCachedImage(msg, data.imageMetadata!.url!, bypassGate: bypassGate);
      if (image != null) _setPreviewImage(image.path, fromDisk: image.fromDisk);
    }

    if (data.iconMetadata?.url != null) {
      final icon =
          await MetadataHelper.resolveCachedImage(msg, data.iconMetadata!.url!, isIcon: true, bypassGate: bypassGate);
      if (icon != null && !_disposed) iconImagePath.value = icon.path;
    }
  }

  /// Fetches metadata when the server provided no image or icon.
  ///
  /// Cached metadata is restored first; a fresh fetch only runs when the store
  /// says the last attempt has aged out (or never happened).
  Future<void> _fetchMissingMetadata(Message msg, {required bool canFetch}) async {
    if (msg.url == null) return;

    final cached = MessageMetadataStore.read(msg);
    if (cached != null) {
      await _applyMetadata(msg, cached, persist: false, bypassGate: canFetch);

      // Real metadata never goes stale. A cache entry holding only a site name
      // is the fallback written after a failed attempt, so it is retried once
      // the store's TTL elapses rather than sticking forever.
      if (cached.hasDisplayableContent || !MessageMetadataStore.shouldFetch(msg)) return;
    } else if (!MessageMetadataStore.shouldFetch(msg)) {
      return;
    }

    // The policy says don't reach out on our own — offer the tap-to-load
    // affordance instead of silently showing a bare card.
    if (!canFetch) {
      if (!_disposed) needsManualLoad.value = true;
      return;
    }

    await _runMetadataFetch(msg);
  }

  /// Performs a live metadata fetch, persists the result and downloads the
  /// preview image.
  ///
  /// Transient failures (timeouts, socket errors, 5xx, rate limiting) are left
  /// unrecorded so the next build retries; permanent ones are stamped so the
  /// fetch is not repeated until the store's TTL elapses.
  Future<void> _runMetadataFetch(Message msg) async {
    // `manual: true` is correct on every path that reaches here: this only runs
    // once `canFetch` is satisfied, which means either the sender policy
    // allowed it or the user tapped. It exists to bypass the redundant
    // `fetchingEnabled` check, which would otherwise block a tapped load under
    // LinkPreviewPolicy.never.
    final result = await MetadataHelper.fetchForMessage(msg, manual: true);

    if (!result.isSuccess) {
      // A site parser may still have supplied a usable icon or site name for a
      // link the site itself refused to describe.
      final partial = result.metadata;
      if (partial != null && partial.isNotEmpty) {
        await _applyMetadata(msg, partial, persist: result.shouldMarkAttempted, bypassGate: true);
        return;
      }

      if (result.shouldMarkAttempted) MessageMetadataStore.markAttempted(msg);
      return;
    }

    await _applyMetadata(msg, result.metadata!, persist: true, bypassGate: true);
  }

  /// Renders [metadata], resolving its image and icon, and optionally writes it
  /// back to the message.
  ///
  /// Set [bypassGate] when [metadata] came from a fetch that already cleared the
  /// sender policy. Restoring from cache leaves it false: the metadata may have
  /// been stored long ago, under a different policy, and the image download is a
  /// fresh outbound request.
  Future<void> _applyMetadata(
    Message msg,
    UrlMetadata metadata, {
    required bool persist,
    bool bypassGate = false,
  }) async {
    if (!_disposed) fetchedMetadata.value = metadata;

    if (kIsWeb) {
      if (persist) MessageMetadataStore.write(msg, metadata);
      return;
    }

    String? imageHash;
    String? iconHash;

    // Reply bubbles render text only, so downloading a hero image for them is
    // wasted bandwidth and disk.
    final imageUrl = metadata.imageUrl;
    if (!_inReply && imageUrl != null) {
      final image = await MetadataHelper.resolveCachedImage(msg, imageUrl, bypassGate: bypassGate);
      if (image != null) {
        imageHash = image.hash;
        _setPreviewImage(image.path, fromDisk: image.fromDisk);
      }
    }

    final iconUrl = metadata.iconUrl;
    if (iconUrl != null) {
      final icon = await MetadataHelper.resolveCachedImage(msg, iconUrl, isIcon: true, bypassGate: bypassGate);
      if (icon != null) {
        iconHash = icon.hash;
        if (!_disposed) iconImagePath.value = icon.path;
      }
    }

    if (persist) {
      MessageMetadataStore.write(msg, metadata, imageHash: imageHash, iconHash: iconHash);
    }
  }

  /// Sets the preview image and starts the grow-in for fresh downloads.
  /// Disk-loaded images are shown immediately without animation.
  void _setPreviewImage(String path, {required bool fromDisk}) {
    if (_disposed) return;
    previewImagePath.value = path;
    previewImageFromDisk.value = fromDisk;
    if (!fromDisk) imageAnimation.forward(from: 0);
  }
}
