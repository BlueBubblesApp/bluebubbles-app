import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:html/dom.dart';

/// schema.org microdata (`itemprop` attributes on ordinary elements).
///
/// Rare on modern sites but still the only structured data on a long tail of
/// older pages, and cheap to support now that the DOM is already parsed.
class MicrodataParser extends MetadataDocumentParser {
  const MicrodataParser();

  @override
  MetadataSource get source => MetadataSource.microdata;

  /// Scanning the whole DOM is only worth it for smallish documents; past this
  /// many elements the earlier parsers have almost certainly found something.
  static const int _maxElements = 4000;

  @override
  UrlMetadata parse(MetadataParseContext context) {
    String? title;
    String? description;
    String? image;

    var seen = 0;
    for (final element in context.document.querySelectorAll('[itemprop]')) {
      if (++seen > _maxElements) break;

      final prop = element.attributes['itemprop']?.trim().toLowerCase();
      if (prop == null || prop.isEmpty) continue;

      switch (prop) {
        case 'name':
        case 'headline':
          title ??= _value(element);
          break;
        case 'description':
          description ??= _value(element);
          break;
        case 'image':
        case 'thumbnailurl':
          image ??= _value(element);
          break;
        default:
          break;
      }

      if (title != null && description != null && image != null) break;
    }

    return build(title: title, description: description, imageUrl: image);
  }

  /// The value of a microdata property, following the spec's element-type
  /// rules: `content` for meta, `src` for media, `href` for links, otherwise
  /// the element's text.
  String? _value(Element element) {
    final attributes = element.attributes;

    for (final attribute in const ['content', 'src', 'href', 'data-src']) {
      final value = attributes[attribute]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }

    final text = element.text.trim();
    // Guard against an `itemprop` on a wrapper element that contains the whole
    // page body.
    if (text.isEmpty || text.length > 1000) return null;
    return text;
  }
}
