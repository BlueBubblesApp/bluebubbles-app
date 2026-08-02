import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/app/state/message_state.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' show basename;
import 'package:universal_io/io.dart';

/// How much a link preview card has to work with, and therefore which shape it
/// renders as.
///
/// The states are ordered by how much the page told us about itself. Both skins
/// implement all three; the width is the same in every one (see [UrlPreview]),
/// so moving between them only ever changes the card's height.
enum UrlPreviewLayout {
  /// A preview image resolved. The full card: image, favicon, title, site line.
  hero,

  /// No image, but the page gave us *something* — a title, a summary, or just a
  /// favicon. A dense row — favicon (when there is one), title, site line —
  /// with tighter padding and a smaller favicon than [hero].
  ///
  /// An icon on its own is enough to land here. It is the only shape that draws
  /// the favicon at all, so a page publishing an icon and nothing else would
  /// otherwise fall to [bare] and have that icon discarded. Such a card renders
  /// the icon beside the host, since [titleFor] falls back to the host when
  /// nothing supplied a title.
  ///
  /// The summary is not rendered in either shape. It is still parsed and
  /// stored, and [hasSummary] still counts toward [hasDescribedContent], so a
  /// page that supplied only a description still reaches this shape rather
  /// than falling to [bare].
  compact,

  /// Nothing beyond the link itself. A single line showing where it goes.
  bare,
}

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
    iconAnimation = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 200),
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

  /// Drives the pop-in for a freshly downloaded favicon.
  ///
  /// Starts at 1.0 so a disk-cached icon — the common path on every scroll —
  /// is simply already there. Only a fresh download rewinds and plays.
  late final AnimationController iconAnimation;

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

  /// True when the favicon came off disk, so the card skips the pop-in.
  final RxBool iconImageFromDisk = false.obs;

  /// True when the plugin payload's artwork was already on disk, so the card
  /// skips the grow-in.
  ///
  /// Starts true, like [iconAnimation] starts at its end value: the attachment
  /// is usually already downloaded, and a card scrolled into view should simply
  /// have its picture. Only [_resolvePluginPayloadAttachment] finishing a live
  /// download flips it.
  final RxBool appleImageFromDisk = true.obs;

  /// True when there is a preview to load but the policy says not to fetch it
  /// automatically. Drives the tap-to-load affordance.
  final RxBool needsManualLoad = false.obs;

  /// True while a user-initiated load is running.
  final RxBool manualLoadRunning = false.obs;

  /// True while a "Refresh Preview" run is in flight.
  ///
  /// Refreshing clears the card back to nothing and re-fetches, which without
  /// this reads as the preview having simply vanished — the action gives no
  /// other feedback, and a cache-cleared refetch is the slowest path there is.
  final RxBool refreshRunning = false.obs;

  static const String _tag = 'UrlPreview';

  /// Short identifier for log lines — the message GUID, or the link when the
  /// card is rendered outside a message.
  String get _logId => message?.guid ?? linkText ?? 'unknown';

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
  ///
  /// The fetched image is only a fallback for a card that has no artwork of its
  /// own — a plugin payload's attachment already heads the card, and the fetch
  /// that ran alongside it was for the title and summary, not to replace it.
  String? get webImageUrl {
    if (!kIsWeb) return null;
    return data.imageMetadata?.url ?? (content.value != null ? null : fetchedMetadata.value?.imageUrl);
  }

  /// Web-only fallback for the favicon, for the same reason as [webImageUrl].
  ///
  /// Everywhere else the icon renders **only** from [iconImagePath]. Pointing an
  /// `Image.network` at the payload's icon URL as a fallback looks harmless but
  /// undoes the whole gate: it is an outbound request to a third-party host,
  /// issued straight from `build`, bypassing [MetadataHelper.shouldAutoFetch],
  /// the disk cache and `UrlSafetyGuard`. A gated or failed icon simply is not
  /// drawn.
  String? get webIconUrl => kIsWeb ? effectiveData.iconMetadata?.url : null;

  /// Show the plugin-payload attachment image only when no disk-cached preview
  /// is available.
  bool get showsAppleImage => previewImagePath.value == null && webImageUrl == null;

  /// True when Apple's payload artwork is on hand **right now** — the file is
  /// downloaded and readable, not merely referenced.
  ///
  /// Deliberately a point-in-time answer, not "will there ever be artwork".
  /// [_loadMessagePreview] only trusts a `false` here on a forced load, where
  /// the attachment has had its chance; see the comment there.
  bool get hasPayloadArtwork => resolvedContent?.bytes != null || contentFile != null;

  bool get hasIcon => iconImagePath.value != null || webIconUrl != null;

  /// True when this card renders inside a reply bubble, which is laid out
  /// compactly and keeps shrink-wrapping rather than taking a stable width.
  bool get inReply => _inReply;

  /// True when there is an image to head the card with — a resolved preview
  /// image, a web fallback, or a plugin payload's own artwork.
  ///
  /// The favicon deliberately does not count. It is a 40px mark that belongs
  /// beside the title, and treating it as a hero image is what produced the
  /// stretched, blurry cards this state machine exists to avoid.
  bool get hasPreviewImage =>
      previewImagePath.value != null || webImageUrl != null || (showsAppleImage && hasPayloadArtwork);

  /// True when the page supplied something the URL does not already say.
  ///
  /// [titleFor] falls back to the host and then to the message text, so a
  /// non-empty title is not evidence of a successful fetch — this checks the
  /// payload and the fetched metadata directly.
  bool get hasDescribedContent =>
      !isNullOrEmpty(effectiveData.title) || !isNullOrEmpty(fetchedMetadata.value?.title) || hasSummary;

  /// Which shape the card renders as. See [UrlPreviewLayout].
  ///
  /// Reply bubbles never carry an image, so they can only ever be [compact] or
  /// [bare].
  ///
  /// [hasIcon] counts toward [compact] even with nothing else: a resolved
  /// favicon is a real, downloaded, decodable image, and [bare] is the one
  /// shape that does not draw it — so a page that published an icon but no
  /// title or description rendered a generic link glyph and threw the icon
  /// away. [bare] now means what it says: nothing resolved at all.
  ///
  /// Safe to key on because [hasIcon] reads `iconImagePath`, which is only set
  /// after a download succeeded. `metadata.iconUrl` would be the wrong signal —
  /// `IconParser` falls back to guessing `/favicon.ico` for every page, so it
  /// is nearly always non-null whether or not an icon exists.
  UrlPreviewLayout get layout {
    if (!_inReply && hasPreviewImage) return UrlPreviewLayout.hero;
    if (hasDescribedContent || hasIcon) return UrlPreviewLayout.compact;
    return UrlPreviewLayout.bare;
  }

  /// The link this card points at, for the [UrlPreviewLayout.bare] shape where
  /// it is the only thing to show.
  String? get linkText => effectiveData.originalUrl ?? effectiveData.url ?? message?.url;

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
  /// Resolved through [MetadataUrls.parse] rather than [Uri.tryParse], and with
  /// the message's own URL as a fallback, because Apple's payload does not
  /// always carry one. An Apple Music link arrives as a `specialization` blob —
  /// artwork, name, album — with no `URL`/`originalURL` at all, and the link
  /// itself only on the message. `Uri.tryParse('')` returns a Uri whose host is
  /// `''`, not null, so the old `?? siteName` fallback was unreachable and
  /// those cards rendered with no site line.
  /// The host is additionally run through [SiteDisplayNames], which maps a
  /// domain to the name people actually call it (`chat.whatsapp.com` ->
  /// "WhatsApp"). That is still URL-derived — the lookup key is the real host,
  /// so an unmapped lookalike renders its raw self and the anti-spoofing
  /// property above is untouched. The payload fallback is left alone: it has no
  /// host to key on.
  String? get siteText {
    if (file != null) return dataOverride.value?.siteName;

    final host = MetadataUrls.parse(effectiveData.originalUrl ?? effectiveData.url ?? message?.url)?.host;
    if (!isNullOrEmpty(host)) return SiteDisplayNames.forHost(host);
    return effectiveData.siteName?.replaceFirst(RegExp(r'^www\.'), '');
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

  /// Whether the site line says anything the title does not.
  ///
  /// [titleFor] falls back to [siteText] when nothing supplied a real title, so
  /// a card with no metadata would otherwise render the host twice — once bold
  /// as the title, once below it as the site line. The title wins because it is
  /// the more prominent slot, and on this path it *is* the URL-derived host, so
  /// dropping the other line gives up nothing.
  ///
  /// A genuine title that merely resembles the host (og:title `apple.com` on a
  /// page served from `evil.com`) is not equal to it, so both lines still
  /// render and the real host stays visible.
  bool showsSiteLine(String? messageText) {
    final site = siteText;
    if (isNullOrEmpty(site)) return false;
    return site!.trim().toLowerCase() != titleFor(messageText).trim().toLowerCase();
  }

  String? get summary => effectiveData.summary ?? fetchedMetadata.value?.description;

  bool get hasSummary =>
      !isNullOrEmpty(effectiveData.summary) || !isNullOrEmpty(fetchedMetadata.value?.description);

  /// True when Apple's payload gave us artwork but no words to go with it.
  ///
  /// Plenty of payloads arrive as an image and nothing else — an Apple Music
  /// plugin attachment, or an `imageMetadata` with no `title` — which renders
  /// as a hero card headed by the bare host. The page itself usually describes
  /// the link perfectly well, so the metadata fetch still runs for those cards;
  /// only the *image* is taken from the payload, and everything the fetch
  /// returns fills in behind it (see [titleFor], [summary], and the
  /// `keepPayloadImage` path in [_applyMetadata]).
  ///
  /// Deliberately requires **both** to be missing. A payload that supplied a
  /// title but no description is already a readable card, and fetching for the
  /// description alone would put an outbound request behind nearly every link
  /// preview in the app.
  bool get _payloadNeedsMetadata => isNullOrEmpty(data.title) && isNullOrEmpty(data.summary);

  /// The link to fetch metadata for.
  ///
  /// Usually the message's own URL. The payload's URL is the fallback because a
  /// plugin-payload message does not always put the link in `message.url` — an
  /// Apple Music card can arrive with the link only in the payload.
  String? get _fetchUrl {
    final url = message?.url;
    if (!isNullOrEmpty(url)) return url;
    return effectiveData.originalUrl ?? effectiveData.url;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Binds the controller to its message scope and kicks off the initial load.
  ///
  /// [messageState] is null when the card is rendered outside a message (the
  /// links and locations sections of conversation details).
  ///
  /// Set [isClone] for the decorative copy `MessagePopup` renders — see
  /// [MessageCloneScope]. It still runs the initial load, which normally
  /// resolves from disk without touching the network, but it does **not**
  /// subscribe to refreshes: both copies share one `MessageState`, so a
  /// subscribed clone makes every "Refresh Preview" run twice.
  void attach({required MessageState? messageState, required bool inReply, bool isClone = false}) {
    _messageState = messageState;
    _inReply = inReply;

    if (messageState != null && !isClone) {
      _refreshWorker = ever(messageState.previewRefreshKey, (_) async {
        if (_disposed) return;
        Logger.debug('Refresh requested; clearing card state for $_logId', tag: _tag);

        // Captured before anything is cleared. A refresh is destructive on both
        // sides — this controller blanks the card, and `refreshPreview` has
        // already wiped the row — so without this a refresh that fails (host
        // down, bot block, the network dropping mid-request) leaves a message
        // that had a perfectly good preview a moment ago with nothing at all,
        // permanently. Rolling back makes a failed refresh a no-op instead.
        final previous = _CardSnapshot.capture(this);

        content.value = null;
        dataOverride.value = null;
        fetchedMetadata.value = null;
        previewImagePath.value = null;
        iconImagePath.value = null;
        previewImageFromDisk.value = false;
        iconImageFromDisk.value = false;
        appleImageFromDisk.value = true;
        needsManualLoad.value = false;
        manualLoadRunning.value = false;
        refreshRunning.value = true;
        try {
          // `force`, for the same reason [loadManually] forces: the user picked
          // "Refresh Preview" out of a menu, which is consent every bit as much
          // as tapping the affordance is. Without it, refreshing a preview whose
          // sender the policy gates just replaces the card with the tap-to-load
          // prompt — the refresh appears to undo itself. Every other protection
          // (host guard, redirect vetting, size caps, image validation) still
          // applies.
          await load(force: true);
        } finally {
          if (!_disposed) {
            // The same predicate on both sides, so "did the refresh produce
            // anything" is asked the one way. Note it deliberately measures
            // only what a *load* produces — payload title/summary arrive with
            // the message and are present either way, so counting them would
            // make a refresh that lost everything look successful.
            //
            // Restores only on a total loss. A partial success — new words but
            // no new picture — is still the fresher answer, and stitching the
            // old image onto it would render a card that never existed.
            final produced = _CardSnapshot.capture(this);
            if (!produced.hasContent && previous.hasContent) {
              Logger.warn('Refresh produced nothing for $_logId; restoring the previous preview', tag: _tag);
              previous.restoreTo(this);
            }
            refreshRunning.value = false;
          }
          Logger.debug('Refresh finished for $_logId (layout: ${layout.name})', tag: _tag);
        }
      });
    }

    unawaited(load());
  }

  void dispose() {
    _disposed = true;
    _refreshWorker?.dispose();
    imageAnimation.dispose();
    iconAnimation.dispose();
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Runs the initial load, or a reload.
  ///
  /// Set [force] when the user asked for this preview, which skips the sender
  /// policy — see [loadManually] for why a deliberate action counts as consent.
  Future<void> load({bool force = false}) async {
    if (file != null) {
      await _loadLocationPreview();
    } else {
      await _loadMessagePreview(force: force);
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
    Logger.debug('Manual load tapped for $_logId', tag: _tag);
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

    final hasPluginPayload = await _resolvePluginPayloadAttachment(msg);

    // Resolved once and threaded through every branch, so scrolling a chat
    // costs at most one contact lookup per message rather than one per image.
    final canFetch = force || await MetadataHelper.shouldAutoFetch(msg);
    Logger.debug('Loading $_logId (force: $force, canFetch: $canFetch)', tag: _tag);

    if (hasPluginPayload) {
      Logger.debug('Using plugin payload attachment for $_logId', tag: _tag);

      // Whether the payload's artwork is a dead end, not merely late.
      //
      // On an automatic load the artwork is trusted to arrive: `getContent`
      // hands back a download controller and calls `onComplete` later, so on
      // the first build of a new message it is almost never on hand yet.
      // Treating "not here yet" as "not coming" would fetch the page's
      // og:image for nearly every payload message, and that image then *wins*
      // over the artwork landing a moment later (see [showsAppleImage]).
      //
      // A forced load is the opposite situation. The user picked "Refresh
      // Preview" or tapped to load and is watching the card: if the artwork
      // is still not on hand, it is not coming, and refusing to look anywhere
      // else is what made refresh appear to do nothing at all.
      final artworkIsDeadEnd = force && !hasPayloadArtwork;

      // Fetch when the payload left a gap the card would show — no words, or
      // no picture it can draw.
      if (_payloadNeedsMetadata || artworkIsDeadEnd) {
        Logger.debug(
            'Fetching to fill payload gaps for $_logId '
            '(needsMetadata: $_payloadNeedsMetadata, artworkDeadEnd: $artworkIsDeadEnd)',
            tag: _tag);
        await _fetchMissingMetadata(msg, canFetch: canFetch, keepPayloadImage: !artworkIsDeadEnd);
      }
      return;
    }

    if (data.imageMetadata?.url != null || data.iconMetadata?.url != null) {
      Logger.debug('Payload supplied its own image/icon; resolving those for $_logId', tag: _tag);
      await _resolveServerImages(msg, bypassGate: canFetch);

      // The card's title and summary arrived with the message, but its image
      // sits on a third-party host, so fetching that is an outbound request
      // like any other and is gated the same way. Anything already on disk was
      // returned above without touching the network.
      final imageStillMissing = data.imageMetadata?.url != null && previewImagePath.value == null && !_inReply;
      if (!canFetch && imageStillMissing && !_disposed) {
        Logger.debug('Payload image gated by the sender policy; offering tap-to-load for $_logId', tag: _tag);
        needsManualLoad.value = true;
      }

      // An image with nothing to caption it. Fetch the page for the title and
      // summary, keeping whatever artwork the payload already resolved.
      if (_payloadNeedsMetadata && !_disposed) {
        Logger.debug('Payload carries an image but no title or summary; fetching those for $_logId', tag: _tag);
        await _fetchMissingMetadata(msg, canFetch: canFetch, keepPayloadImage: previewImagePath.value != null);
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

    // `getContent` returns a ready `PlatformFile` synchronously when the
    // attachment is already on disk, and calls `onComplete` later when it had
    // to download it. That split is exactly the animation rule: a card scrolled
    // into view already has its picture, while one that lands while the user is
    // looking grows in.
    content.value = AttachmentsSvc.getContent(attachment, autoDownload: true, onComplete: (loaded) {
      if (_disposed) return;
      appleImageFromDisk.value = false;
      content.value = loaded;
      imageAnimation.forward(from: 0);
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
      Logger.debug(
          image == null
              ? 'No preview image resolved for $_logId'
              : 'Preview image resolved for $_logId (fromDisk: ${image.fromDisk})',
          tag: _tag);
      if (image != null) _setPreviewImage(image.path, fromDisk: image.fromDisk);
    }

    if (data.iconMetadata?.url != null) {
      final icon =
          await MetadataHelper.resolveCachedImage(msg, data.iconMetadata!.url!, isIcon: true, bypassGate: bypassGate);
      Logger.debug(
          icon == null ? 'No icon resolved for $_logId' : 'Icon resolved for $_logId (fromDisk: ${icon.fromDisk})',
          tag: _tag);
      if (icon != null) _setIconImage(icon.path, fromDisk: icon.fromDisk);
    }
  }

  /// Fetches metadata to fill in what the payload did not supply.
  ///
  /// Cached metadata is restored first; a fresh fetch only runs when the store
  /// says the last attempt has aged out (or never happened).
  ///
  /// Set [keepPayloadImage] when the card is already showing artwork from
  /// Apple's payload, so the fetch contributes text only and never swaps the
  /// image out from under it.
  Future<void> _fetchMissingMetadata(Message msg, {required bool canFetch, bool keepPayloadImage = false}) async {
    final url = _fetchUrl;
    if (url == null) return;

    final cached = MessageMetadataStore.read(msg);
    if (cached != null) {
      Logger.debug('Restoring cached metadata for $_logId (displayable: ${cached.hasDisplayableContent})', tag: _tag);
      await _applyMetadata(msg, cached, persist: false, bypassGate: canFetch, keepPayloadImage: keepPayloadImage);

      // Real metadata never goes stale. A cache entry holding only a site name
      // is the fallback written after a failed attempt, so it is retried once
      // the store's TTL elapses rather than sticking forever.
      if (cached.hasDisplayableContent || !MessageMetadataStore.shouldFetch(msg)) return;
    } else if (!MessageMetadataStore.shouldFetch(msg)) {
      Logger.debug('Skipping fetch for $_logId; a recent attempt has not aged out yet', tag: _tag);
      return;
    }

    // The policy says don't reach out on our own — offer the tap-to-load
    // affordance instead of silently showing a bare card.
    if (!canFetch) {
      Logger.debug('Fetch gated by the sender policy; offering tap-to-load for $_logId', tag: _tag);
      if (!_disposed) needsManualLoad.value = true;
      return;
    }

    await _runMetadataFetch(msg, url: url, keepPayloadImage: keepPayloadImage);
  }

  /// Performs a live metadata fetch, persists the result and downloads the
  /// preview image.
  ///
  /// Transient failures (timeouts, socket errors, 5xx, rate limiting) are left
  /// unrecorded so the next build retries; permanent ones are stamped so the
  /// fetch is not repeated until the store's TTL elapses.
  Future<void> _runMetadataFetch(Message msg, {required String url, bool keepPayloadImage = false}) async {
    // `manual: true` is correct on every path that reaches here: this only runs
    // once `canFetch` is satisfied, which means either the sender policy
    // allowed it or the user tapped. It exists to bypass the redundant
    // `fetchingEnabled` check, which would otherwise block a tapped load under
    // LinkPreviewPolicy.never.
    final result = await MetadataHelper.fetchForMessage(msg, urlOverride: url, manual: true);
    Logger.debug('Fetch for $_logId returned ${result.status.name} (retryable: ${result.isRetryable})', tag: _tag);

    if (!result.isSuccess) {
      // A site parser may still have supplied a usable icon or site name for a
      // link the site itself refused to describe.
      final partial = result.metadata;
      if (partial != null && partial.isNotEmpty) {
        await _applyMetadata(msg, partial,
            persist: result.shouldMarkAttempted, bypassGate: true, keepPayloadImage: keepPayloadImage);
        return;
      }

      if (result.shouldMarkAttempted) MessageMetadataStore.markAttempted(msg);
      return;
    }

    await _applyMetadata(msg, result.metadata!, persist: true, bypassGate: true, keepPayloadImage: keepPayloadImage);
  }

  /// Renders [metadata], resolving its image and icon, and optionally writes it
  /// back to the message.
  ///
  /// Set [bypassGate] when [metadata] came from a fetch that already cleared the
  /// sender policy. Restoring from cache leaves it false: the metadata may have
  /// been stored long ago, under a different policy, and the image download is a
  /// fresh outbound request.
  ///
  /// Set [keepPayloadImage] when the card is already headed by Apple's own
  /// artwork. The hero image is then left alone — downloading the page's
  /// `og:image` would only replace a picture the user is already looking at,
  /// for an outbound request and a second file on disk. The icon is still
  /// resolved when the payload did not carry one, and the persisted image hash
  /// is untouched: [MessageMetadataStore.write] only writes hashes it is given.
  Future<void> _applyMetadata(
    Message msg,
    UrlMetadata metadata, {
    required bool persist,
    bool bypassGate = false,
    bool keepPayloadImage = false,
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
    if (!_inReply && !keepPayloadImage && imageUrl != null) {
      final image = await MetadataHelper.resolveCachedImage(msg, imageUrl, bypassGate: bypassGate);
      if (image != null) {
        imageHash = image.hash;
        _setPreviewImage(image.path, fromDisk: image.fromDisk);
      }
    }

    // An icon already on the card came from the payload (or from the cached
    // metadata applied a moment ago) and is equally good, so it is not fetched
    // twice.
    final iconUrl = metadata.iconUrl;
    if (iconUrl != null && iconImagePath.value == null) {
      final icon = await MetadataHelper.resolveCachedImage(msg, iconUrl, isIcon: true, bypassGate: bypassGate);
      if (icon != null) {
        iconHash = icon.hash;
        _setIconImage(icon.path, fromDisk: icon.fromDisk);
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

  /// Sets the favicon and starts the pop-in for fresh downloads.
  /// Disk-loaded icons are shown immediately without animation.
  void _setIconImage(String path, {required bool fromDisk}) {
    if (_disposed) return;
    iconImagePath.value = path;
    iconImageFromDisk.value = fromDisk;
    if (!fromDisk) iconAnimation.forward(from: 0);
  }
}

/// Everything a card was showing, captured so a failed refresh can put it back.
///
/// Exists because "Refresh Preview" is destructive before it is productive: the
/// row is cleared by `refreshPreview`, the controller blanks its own state, and
/// only then does the network get involved. Any failure after that point used to
/// leave the message permanently blank.
class _CardSnapshot {
  const _CardSnapshot({
    required this.metadata,
    required this.previewImagePath,
    required this.iconImagePath,
    required this.previewImageFromDisk,
    required this.iconImageFromDisk,
    required this.appleImageFromDisk,
    required this.content,
    required this.dataOverride,
  });

  factory _CardSnapshot.capture(UrlPreviewController c) => _CardSnapshot(
        metadata: c.fetchedMetadata.value,
        previewImagePath: c.previewImagePath.value,
        iconImagePath: c.iconImagePath.value,
        previewImageFromDisk: c.previewImageFromDisk.value,
        iconImageFromDisk: c.iconImageFromDisk.value,
        appleImageFromDisk: c.appleImageFromDisk.value,
        content: c.content.value,
        dataOverride: c.dataOverride.value,
      );

  final UrlMetadata? metadata;
  final String? previewImagePath;
  final String? iconImagePath;
  final bool previewImageFromDisk;
  final bool iconImageFromDisk;
  final bool appleImageFromDisk;
  final Object? content;
  final UrlPreviewData? dataOverride;

  /// Whether there was anything here worth restoring.
  bool get hasContent =>
      metadata != null || previewImagePath != null || iconImagePath != null || content != null || dataOverride != null;

  void restoreTo(UrlPreviewController c) {
    c.fetchedMetadata.value = metadata;
    c.previewImagePath.value = previewImagePath;
    c.iconImagePath.value = iconImagePath;
    // Restored images are already on screen's terms — they came off disk the
    // first time and are not arriving fresh now, so nothing should animate in.
    c.previewImageFromDisk.value = previewImageFromDisk || previewImagePath != null;
    c.iconImageFromDisk.value = iconImageFromDisk || iconImagePath != null;
    c.appleImageFromDisk.value = true;
    c.content.value = content;
    c.dataOverride.value = dataOverride;

    _repersist(c);
  }

  /// Puts the metadata back on the message.
  ///
  /// `refreshPreview` cleared the row before the reload started, so an
  /// in-memory rollback alone would still lose the preview on the next app
  /// launch. The image hashes are recovered from the cached file paths —
  /// `FilesystemSvc.urlPreviewImagePath` is `join(dir, hash)`, so the basename
  /// *is* the hash, and those files were never deleted.
  void _repersist(UrlPreviewController c) {
    final msg = c.message;
    final data = metadata;
    if (msg == null || data == null) return;

    try {
      MessageMetadataStore.write(
        msg,
        data,
        imageHash: previewImagePath == null ? null : basename(previewImagePath!),
        iconHash: iconImagePath == null ? null : basename(iconImagePath!),
      );
    } catch (ex, stack) {
      // The card is already correct on screen; failing to re-persist costs the
      // preview on next launch, not now.
      Logger.warn('Could not re-persist the restored preview for ${msg.guid}',
          error: ex, trace: stack, tag: 'UrlPreview');
    }
  }
}
