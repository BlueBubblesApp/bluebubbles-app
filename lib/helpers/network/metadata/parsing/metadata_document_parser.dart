import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';

/// One metadata extraction strategy over an already-parsed document.
///
/// Implementations return whatever they can find and leave everything else
/// null; the pipeline handles precedence, URL resolution and text cleanup, so
/// a parser only has to know about its own tag vocabulary.
abstract class MetadataDocumentParser {
  const MetadataDocumentParser();

  /// Which strategy this is, recorded on the resulting [UrlMetadata].
  MetadataSource get source;

  /// Extracts what this strategy can from [context].
  ///
  /// Must not throw — the pipeline guards each parser, but returning
  /// [UrlMetadata.empty] is cheaper than an exception.
  UrlMetadata parse(MetadataParseContext context);

  /// Convenience for tagging a result with [source]. Returns
  /// [UrlMetadata.empty] untagged when nothing was found, so the pipeline's
  /// merge can skip it cheaply.
  UrlMetadata build({
    String? title,
    String? description,
    String? imageUrl,
    int? imageWidth,
    int? imageHeight,
    String? iconUrl,
    String? siteName,
    String? canonicalUrl,
    String? themeColor,
  }) {
    final result = UrlMetadata(
      title: title,
      description: description,
      imageUrl: imageUrl,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      iconUrl: iconUrl,
      siteName: siteName,
      canonicalUrl: canonicalUrl,
      themeColor: themeColor,
      sources: {source},
    );

    return result.isEmpty && result.canonicalUrl == null && result.themeColor == null ? UrlMetadata.empty : result;
  }
}
