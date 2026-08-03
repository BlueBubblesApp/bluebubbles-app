import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_text.dart';
import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';
import 'package:flutter/foundation.dart';

/// Everything the app knows about a linked page.
///
/// Immutable. Parsers each produce a partially-populated instance and the
/// pipeline folds them together with [fillMissingFrom], which is what gives
/// the "Open Graph wins, then Twitter Card, then JSON-LD..." precedence
/// without any parser needing to know about the others.
@immutable
class UrlMetadata {
  /// Page title.
  final String? title;

  /// Short summary of the page.
  final String? description;

  /// Absolute URL of the preview image.
  final String? imageUrl;

  /// Intrinsic size of [imageUrl], when the page declared it. Used to reserve
  /// layout space before the image finishes downloading.
  final int? imageWidth;
  final int? imageHeight;

  /// Absolute URL of the site's icon (apple-touch-icon / favicon).
  final String? iconUrl;

  /// Human readable site name (`og:site_name`, oEmbed `provider_name`).
  final String? siteName;

  /// `<link rel="canonical">` or `og:url` — where the page says it lives.
  final String? canonicalUrl;

  /// `<meta name="theme-color">`, as authored (e.g. `#1a1a1a`).
  final String? themeColor;

  /// The URL originally requested, before redirects. This is what the user
  /// tapped and what the UI should open.
  final String? requestUrl;

  /// The URL the fetch actually landed on after redirects.
  final String? finalUrl;

  /// Which strategies contributed to this instance. Debug/logging only.
  final Set<MetadataSource> sources;

  /// When this was fetched, in milliseconds since epoch. Drives the retry TTL.
  final int? fetchedAt;

  const UrlMetadata({
    this.title,
    this.description,
    this.imageUrl,
    this.imageWidth,
    this.imageHeight,
    this.iconUrl,
    this.siteName,
    this.canonicalUrl,
    this.themeColor,
    this.requestUrl,
    this.finalUrl,
    this.sources = const {},
    this.fetchedAt,
  });

  static const UrlMetadata empty = UrlMetadata();

  /// True when there is nothing worth showing or persisting.
  bool get isEmpty => title == null && description == null && imageUrl == null && iconUrl == null && siteName == null;

  bool get isNotEmpty => !isEmpty;

  /// True when the fields a preview card actually renders are all present, so
  /// the pipeline can stop running further parsers.
  bool get hasCoreFields => title != null && description != null && imageUrl != null;

  /// True when this describes the page rather than merely identifying its host.
  ///
  /// A failed fetch still yields a site name (and possibly an icon) so the card
  /// is not blank. That is worth showing, but it is not worth treating as a
  /// final answer — callers use this to decide whether a cached entry should
  /// ever be retried.
  bool get hasDisplayableContent => title != null || description != null || imageUrl != null;

  /// Best available display URL: what the user tapped, falling back to the
  /// canonical or post-redirect URL.
  String? get displayUrl => requestUrl ?? canonicalUrl ?? finalUrl;

  /// The aspect ratio declared by the page, if both dimensions are known and
  /// sane. Values outside a plausible range are ignored — some sites emit
  /// placeholder `og:image:width` values like `1`.
  double? get imageAspectRatio {
    final w = imageWidth;
    final h = imageHeight;
    if (w == null || h == null || w < 8 || h < 8) return null;
    final ratio = w / h;
    if (ratio < 0.05 || ratio > 20) return null;
    return ratio;
  }

  UrlMetadata copyWith({
    String? title,
    String? description,
    String? imageUrl,
    int? imageWidth,
    int? imageHeight,
    String? iconUrl,
    String? siteName,
    String? canonicalUrl,
    String? themeColor,
    String? requestUrl,
    String? finalUrl,
    Set<MetadataSource>? sources,
    int? fetchedAt,
  }) {
    return UrlMetadata(
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      iconUrl: iconUrl ?? this.iconUrl,
      siteName: siteName ?? this.siteName,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      themeColor: themeColor ?? this.themeColor,
      requestUrl: requestUrl ?? this.requestUrl,
      finalUrl: finalUrl ?? this.finalUrl,
      sources: sources ?? this.sources,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  /// Returns a copy where every field this instance is missing is taken from
  /// [other]. Fields already set here always win.
  ///
  /// Image dimensions travel with the image: if [other] supplies the image URL
  /// then its dimensions come along too, so we never pair one parser's URL
  /// with another parser's width/height.
  UrlMetadata fillMissingFrom(UrlMetadata? other) {
    if (other == null || other.isEmpty && other.canonicalUrl == null && other.themeColor == null) {
      return this;
    }

    final takesImageFromOther = imageUrl == null && other.imageUrl != null;

    return UrlMetadata(
      title: title ?? other.title,
      description: description ?? other.description,
      imageUrl: imageUrl ?? other.imageUrl,
      imageWidth: takesImageFromOther ? other.imageWidth : imageWidth,
      imageHeight: takesImageFromOther ? other.imageHeight : imageHeight,
      iconUrl: iconUrl ?? other.iconUrl,
      siteName: siteName ?? other.siteName,
      canonicalUrl: canonicalUrl ?? other.canonicalUrl,
      themeColor: themeColor ?? other.themeColor,
      requestUrl: requestUrl ?? other.requestUrl,
      finalUrl: finalUrl ?? other.finalUrl,
      sources: {...sources, ...other.sources},
      fetchedAt: fetchedAt ?? other.fetchedAt,
    );
  }

  /// Cleans every string field and resolves every URL field against [baseUri].
  ///
  /// Parsers may return raw, relative, whitespace-padded values; calling this
  /// once at the end of the pipeline is what guarantees the rest of the app
  /// only ever sees absolute http(s) URLs and tidy text.
  UrlMetadata normalized(Uri baseUri) {
    final cleanedSite = MetadataText.clean(siteName, maxLength: 80);
    var cleanedTitle = MetadataText.clean(title);
    // A title that is just the site name adds nothing over the site line the
    // card already renders.
    if (cleanedTitle != null && cleanedSite != null && cleanedTitle.toLowerCase() == cleanedSite.toLowerCase()) {
      cleanedTitle = null;
    }

    final cleanedDescription = MetadataText.cleanDescription(description);

    return UrlMetadata(
      title: cleanedTitle,
      // Some sites set the description to the title verbatim.
      description: cleanedDescription == cleanedTitle ? null : cleanedDescription,
      imageUrl: MetadataUrls.resolveToString(baseUri, imageUrl),
      imageWidth: _sanePixels(imageWidth),
      imageHeight: _sanePixels(imageHeight),
      iconUrl: MetadataUrls.resolveToString(baseUri, iconUrl),
      siteName: cleanedSite,
      canonicalUrl: MetadataUrls.resolveToString(baseUri, canonicalUrl),
      themeColor: MetadataText.clean(themeColor, maxLength: 32),
      requestUrl: requestUrl,
      finalUrl: finalUrl,
      sources: sources,
      fetchedAt: fetchedAt,
    );
  }

  static int? _sanePixels(int? value) {
    if (value == null || value <= 0 || value > 20000) return null;
    return value;
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Legacy keys written by the old `metadata_fetch`-based implementation.
  /// Still written on every save so that downgrading the app keeps working,
  /// and still read by [fromJson] so existing rows keep rendering.
  static const String _legacyImageKey = 'image';
  static const String _legacyUrlKey = 'url';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'iconUrl': iconUrl,
      'siteName': siteName,
      'canonicalUrl': canonicalUrl,
      'themeColor': themeColor,
      'requestUrl': requestUrl,
      'finalUrl': finalUrl,
      'metadataSources': sources.map((e) => e.name).toList(),
      'fetchedAt': fetchedAt,
      // Back-compat aliases — see [_legacyImageKey].
      _legacyImageKey: imageUrl,
      _legacyUrlKey: requestUrl ?? canonicalUrl,
    };
  }

  factory UrlMetadata.fromJson(Map<String, dynamic> json) {
    return UrlMetadata(
      title: _string(json['title']),
      description: _string(json['description']),
      imageUrl: _string(json['imageUrl']) ?? _string(json[_legacyImageKey]),
      imageWidth: _int(json['imageWidth']),
      imageHeight: _int(json['imageHeight']),
      iconUrl: _string(json['iconUrl']),
      siteName: _string(json['siteName']),
      canonicalUrl: _string(json['canonicalUrl']),
      themeColor: _string(json['themeColor']),
      requestUrl: _string(json['requestUrl']) ?? _string(json[_legacyUrlKey]),
      finalUrl: _string(json['finalUrl']),
      sources: _sources(json['metadataSources']),
      fetchedAt: _int(json['fetchedAt']),
    );
  }

  /// The keys [toJson] writes. Used when persisting into a shared map so that
  /// stale metadata keys are cleared without disturbing sibling entries such
  /// as `previewImageMd5`.
  static const Set<String> jsonKeys = {
    'title',
    'description',
    'imageUrl',
    'imageWidth',
    'imageHeight',
    'iconUrl',
    'siteName',
    'canonicalUrl',
    'themeColor',
    'requestUrl',
    'finalUrl',
    'metadataSources',
    'fetchedAt',
    _legacyImageKey,
    _legacyUrlKey,
  };

  static String? _string(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Set<MetadataSource> _sources(dynamic value) {
    if (value is! List) return const {};
    final result = <MetadataSource>{};
    for (final entry in value) {
      if (entry is! String) continue;
      for (final source in MetadataSource.values) {
        if (source.name == entry) result.add(source);
      }
    }
    return result;
  }

  @override
  String toString() =>
      'UrlMetadata(title: $title, image: $imageUrl, site: $siteName, '
      'sources: ${sources.map((e) => e.label).join(', ')})';
}
