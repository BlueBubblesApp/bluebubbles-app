import 'dart:convert';

import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';

/// schema.org JSON-LD (`<script type="application/ld+json">`).
///
/// Handles the shapes real sites actually emit, which the previous
/// implementation did not:
///
///  * **every** script block, anywhere in the document — not just the first
///    one inside `<head>`;
///  * top-level arrays and `@graph` wrappers;
///  * `@type` as either a string or a list;
///  * nested objects (`image: {url: ...}`, `publisher: {name: ...}`).
///
/// Every value is type-checked before use. The old code called `.toString()`
/// on whatever it found, which turned a nested object into a title like
/// `{@type: Person, name: Jane}` and a missing key into the string `"null"`.
class JsonLdParser extends MetadataDocumentParser {
  const JsonLdParser();

  @override
  MetadataSource get source => MetadataSource.jsonLd;

  /// How useful each schema.org type is as a page description. The
  /// highest-scoring node supplies the title/description/image; low scorers
  /// are still mined for the site name and logo.
  static const Map<String, int> _typeScores = {
    'article': 100,
    'newsarticle': 100,
    'blogposting': 100,
    'techarticle': 100,
    'report': 95,
    'videoobject': 95,
    'podcastepisode': 92,
    'product': 90,
    'recipe': 90,
    'event': 88,
    'book': 85,
    'movie': 85,
    'tvepisode': 85,
    'musicrecording': 85,
    'musicalbum': 85,
    'socialmediaposting': 85,
    'discussionforumposting': 85,
    'question': 80,
    'course': 80,
    'jobposting': 80,
    'realestatelisting': 80,
    'profilepage': 60,
    'webpage': 55,
    'collectionpage': 50,
    'itempage': 50,
    'imageobject': 35,
    'website': 25,
    'organization': 15,
    'person': 15,
  };

  /// Types that describe the publisher rather than the page.
  static const Set<String> _publisherTypes = {'organization', 'website', 'newsmediaorganization', 'corporation'};

  /// Types that never describe the page and only add noise. Keys are stored
  /// lowercased to match [_types].
  static const Set<String> _ignoredTypes = {
    'breadcrumblist',
    'listitem',
    'searchaction',
    'sitenavigationelement',
    'wpheader',
    'wpfooter',
    'wpsidebar',
  };

  /// Guards against a pathological document with hundreds of blocks.
  static const int _maxNodes = 60;

  @override
  UrlMetadata parse(MetadataParseContext context) {
    final nodes = _collectNodes(context);
    if (nodes.isEmpty) return UrlMetadata.empty;

    Map<String, dynamic>? best;
    var bestScore = -1;

    String? publisherName;
    String? publisherLogo;

    for (final node in nodes) {
      final types = _types(node);
      if (types.any(_ignoredTypes.contains)) continue;

      if (types.any(_publisherTypes.contains)) {
        publisherName ??= _string(node['name']) ?? _string(node['alternateName']);
        publisherLogo ??= _imageUrl(node['logo']);
      }

      var score = 0;
      for (final type in types) {
        final typeScore = _typeScores[type] ?? 40;
        if (typeScore > score) score = typeScore;
      }
      // A node with no recognisable type still beats nothing at all.
      if (types.isEmpty) score = 30;

      // Prefer a node that actually carries the fields we want.
      if (_string(node['headline']) != null || _string(node['name']) != null) score += 5;
      if (_imageUrl(node['image']) != null) score += 3;

      if (score > bestScore) {
        bestScore = score;
        best = node;
      }
    }

    // The publisher block is also the best source of a site name when the page
    // node does not declare one.
    final fromPublisher = _fromPublisher(best, publisherName, publisherLogo);
    if (best == null) return fromPublisher;

    return build(
      title: _string(best['headline']) ?? _string(best['name']) ?? _string(best['alternativeHeadline']),
      description: _string(best['description']) ?? _string(best['abstract']),
      imageUrl: _imageUrl(best['image']) ?? _imageUrl(best['thumbnailUrl']) ?? _imageUrl(best['thumbnail']),
      siteName: fromPublisher.siteName ?? _string(_lookup(best, 'isPartOf', 'name')),
      iconUrl: fromPublisher.iconUrl,
      canonicalUrl: _string(best['url']) ?? _string(best['@id']),
    );
  }

  UrlMetadata _fromPublisher(Map<String, dynamic>? best, String? publisherName, String? publisherLogo) {
    final name = publisherName ?? _string(_lookup(best, 'publisher', 'name'));
    final logo = publisherLogo ?? _imageUrl(_lookup(best, 'publisher', 'logo'));
    return build(siteName: name, iconUrl: logo);
  }

  // ---------------------------------------------------------------------------
  // Collection & flattening
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _collectNodes(MetadataParseContext context) {
    final nodes = <Map<String, dynamic>>[];

    for (final script in context.document.getElementsByTagName('script')) {
      final type = script.attributes['type']?.trim().toLowerCase();
      if (type != 'application/ld+json') continue;

      final raw = script.text.trim();
      if (raw.isEmpty) continue;

      dynamic decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        // Invalid JSON-LD is common enough that it is not worth logging; just
        // move on to the next block.
        continue;
      }

      _flatten(decoded, nodes);
      if (nodes.length >= _maxNodes) break;
    }

    return nodes.length > _maxNodes ? nodes.sublist(0, _maxNodes) : nodes;
  }

  void _flatten(dynamic value, List<Map<String, dynamic>> out, {int depth = 0}) {
    if (out.length >= _maxNodes || depth > 4) return;

    if (value is List) {
      for (final entry in value) {
        _flatten(entry, out, depth: depth + 1);
      }
      return;
    }

    if (value is! Map) return;
    final map = value.cast<String, dynamic>();

    final graph = map['@graph'];
    if (graph != null) {
      _flatten(graph, out, depth: depth + 1);
      // A wrapper that only carries @graph is not itself a node.
      if (map.length <= 2) return;
    }

    out.add(map);

    // `mainEntity` / `mainEntityOfPage` frequently hold the real article node.
    for (final key in const ['mainEntity', 'mainEntityOfPage']) {
      final nested = map[key];
      if (nested is Map) _flatten(nested, out, depth: depth + 1);
    }
  }

  // ---------------------------------------------------------------------------
  // Type-safe field access
  // ---------------------------------------------------------------------------

  List<String> _types(Map<String, dynamic> node) {
    final raw = node['@type'];
    if (raw is String) return [raw.trim().toLowerCase()];
    if (raw is List) {
      return raw.whereType<String>().map((e) => e.trim().toLowerCase()).toList();
    }
    return const [];
  }

  /// `node[outer][inner]`, tolerating [outer] being a list or absent.
  dynamic _lookup(Map<String, dynamic>? node, String outer, String inner) {
    if (node == null) return null;
    var value = node[outer];
    if (value is List) value = value.isEmpty ? null : value.first;
    if (value is Map) return value[inner];
    return null;
  }

  /// Extracts a string, descending into the shapes schema.org allows.
  static String? _string(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) return value.toString();
    if (value is List) {
      for (final entry in value) {
        final result = _string(entry);
        if (result != null) return result;
      }
      return null;
    }
    if (value is Map) {
      // Language-tagged values (`{"@value": "...", "@language": "en"}`) and
      // named references (`{"@type": "Person", "name": "..."}`).
      return _string(value['@value']) ?? _string(value['name']);
    }
    return null;
  }

  /// Extracts an image URL from the several shapes `image` can take.
  static String? _imageUrl(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List) {
      for (final entry in value) {
        final result = _imageUrl(entry);
        if (result != null) return result;
      }
      return null;
    }
    if (value is Map) {
      // ImageObject.
      return _imageUrl(value['url']) ?? _imageUrl(value['contentUrl']) ?? _imageUrl(value['@id']);
    }
    return null;
  }
}
