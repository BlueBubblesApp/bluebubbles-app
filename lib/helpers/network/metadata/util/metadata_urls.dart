/// URL parsing, resolution and normalisation shared across the metadata stack.
abstract final class MetadataUrls {
  /// Matches a leading RFC 3986 scheme (`https:`, `mailto:`, `bbmsg:` ...).
  static final RegExp _schemePrefix = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:');

  /// Query parameters that only exist for analytics. Stripping them before the
  /// fetch improves cache hit rate and avoids handing the target site a
  /// campaign ID, without changing which page is loaded.
  ///
  /// Deliberately conservative: only parameters that are universally inert.
  /// Site-specific ones (`si` on YouTube, `context` on Reddit) are handled by
  /// the relevant [SiteMetadataParser] instead.
  static const Set<String> trackingParams = {
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'utm_id',
    'utm_name',
    'utm_reader',
    'utm_brand',
    'utm_social',
    'utm_social-type',
    'fbclid',
    'gclid',
    'gclsrc',
    'gbraid',
    'wbraid',
    'dclid',
    'msclkid',
    'yclid',
    'twclid',
    'ttclid',
    'igshid',
    'igsh',
    'li_fat_id',
    'mc_cid',
    'mc_eid',
    'mkt_tok',
    'epik',
    '_hsenc',
    '_hsmi',
    'oly_anon_id',
    'oly_enc_id',
    'vero_id',
    's_kwcid',
    'ncid',
    'cmpid',
    'soc_src',
    'soc_trk',
    'at_medium',
    'at_campaign',
  };

  /// Parses [raw] into an absolute URL, defaulting a missing scheme to HTTPS.
  ///
  /// Unlike the old `startsWith("http")` check this recognises any scheme, so
  /// `mailto:a@b.com` is parsed as a mailto URI (and later rejected by
  /// [UrlSafetyGuard]) rather than being mangled into
  /// `https://mailto:a@b.com`.
  static Uri? parse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final withScheme = _schemePrefix.hasMatch(trimmed) || trimmed.startsWith('//')
        ? (trimmed.startsWith('//') ? 'https:$trimmed' : trimmed)
        : 'https://$trimmed';

    // Anything that parses is returned as-is; deciding whether the scheme and
    // host are acceptable is [UrlSafetyGuard]'s job, so that callers get a
    // specific rejection reason instead of a bare null.
    return Uri.tryParse(withScheme);
  }

  /// Resolves a possibly-relative [raw] URL against [base].
  ///
  /// Handles every relative form correctly (`//cdn/x.png`, `/x.png`,
  /// `../x.png`, `x.png`) because it defers to [Uri.resolveUri] rather than
  /// concatenating strings. Returns `null` for anything that does not resolve
  /// to an http(s) URL — including `data:` and `javascript:` values.
  static Uri? resolve(Uri base, String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final parsed = Uri.parse(trimmed);
      final resolved = base.resolveUri(parsed);
      if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
      if (resolved.host.isEmpty) return null;
      return resolved;
    } on FormatException {
      return null;
    }
  }

  /// Upper bound on a URL we are willing to store or re-request.
  ///
  /// Every URL field ends up persisted on the message row and handed back to
  /// the network layer later, so an unbounded one is both database bloat and a
  /// request we would rather not make. Well past what any real CDN produces.
  static const int maxLength = 2048;

  /// [resolve], returning a string, and rejecting absurdly long URLs.
  static String? resolveToString(Uri base, String? raw) {
    final resolved = resolve(base, raw)?.toString();
    if (resolved == null || resolved.length > maxLength) return null;
    return resolved;
  }

  /// Removes analytics-only query parameters and the fragment.
  ///
  /// The fragment is never transmitted, and keeping it would fragment the
  /// metadata cache across links that point at the same document.
  static Uri stripTrackingParams(Uri uri, {Set<String> extra = const {}}) {
    final hasFragment = uri.fragment.isNotEmpty;
    if (uri.queryParameters.isEmpty) {
      return hasFragment ? uri.removeFragment() : uri;
    }

    final kept = <String, List<String>>{};
    uri.queryParametersAll.forEach((key, values) {
      final lower = key.toLowerCase();
      if (trackingParams.contains(lower) || extra.contains(lower)) return;
      kept[key] = values;
    });

    if (kept.length == uri.queryParametersAll.length && !hasFragment) return uri;

    return uri.replace(queryParameters: kept.isEmpty ? null : kept).removeFragment();
  }

  /// A stable key identifying the document a URL points at.
  ///
  /// Lowercases the scheme and host, drops the default port, drops the
  /// fragment and sorts the query so that links which differ only in
  /// parameter order share a cache entry.
  static String cacheKey(Uri uri) {
    final sortedQuery = uri.queryParametersAll.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer()
      ..write(uri.scheme.toLowerCase())
      ..write('://')
      ..write(uri.host.toLowerCase());

    final isDefaultPort =
        (uri.scheme == 'http' && uri.port == 80) || (uri.scheme == 'https' && uri.port == 443) || uri.port == 0;
    if (!isDefaultPort) buffer.write(':${uri.port}');

    buffer.write(uri.path.isEmpty ? '/' : uri.path);

    if (sortedQuery.isNotEmpty) {
      final parts = <String>[];
      for (final entry in sortedQuery) {
        final values = [...entry.value]..sort();
        for (final value in values) {
          parts.add('${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}');
        }
      }
      buffer.write('?${parts.join('&')}');
    }

    return buffer.toString();
  }

  /// The registrable-looking host for display, with a leading `www.` removed.
  static String? displayHost(Uri uri) {
    final host = uri.host;
    if (host.isEmpty) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// True when [host] equals [domain] or is a subdomain of it.
  static bool hostMatches(String host, String domain) {
    final lower = host.toLowerCase();
    return lower == domain || lower.endsWith('.$domain');
  }

  /// True when [host] is `<anything>.<domain>` for one of the public suffixes
  /// a site uses per-country (`amazon.co.uk`, `amazon.de`, ...).
  static bool hostMatchesAny(String host, Iterable<String> domains) {
    for (final domain in domains) {
      if (hostMatches(host, domain)) return true;
    }
    return false;
  }
}
