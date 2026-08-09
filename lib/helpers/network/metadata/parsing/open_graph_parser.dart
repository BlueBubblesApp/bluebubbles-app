import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';

/// Open Graph (`<meta property="og:*">`).
///
/// The richest and most widely deployed vocabulary, so it runs first and its
/// values win over every other strategy.
class OpenGraphParser extends MetadataDocumentParser {
  const OpenGraphParser();

  @override
  MetadataSource get source => MetadataSource.openGraph;

  /// Image spellings in preference order. `og:image` is the canonical one, but
  /// pages served over HTTPS often only fill in the `secure_url` variant, and
  /// `og:image:url` is a common (technically redundant) alternative.
  static const List<String> _imageKeys = [
    'og:image:secure_url',
    'og:image',
    'og:image:url',
  ];

  @override
  UrlMetadata parse(MetadataParseContext context) {
    final tags = context.metaTags;

    var image = tags.firstOf(_imageKeys);
    int? width = tags.firstInt('og:image:width');
    int? height = tags.firstInt('og:image:height');

    // Only fall back to a video poster frame when there is no image at all.
    //
    // Note this is `og:video:thumbnail`, never `og:video` — the latter is a
    // player page or an .mp4, and feeding it to an image widget just renders
    // a broken-image placeholder.
    if (image == null) {
      image = tags.firstOf(const ['og:video:thumbnail', 'og:video:image']);
      if (image != null) {
        width = null;
        height = null;
      }
    }

    return build(
      title: tags.first('og:title'),
      description: tags.first('og:description'),
      imageUrl: image,
      imageWidth: width,
      imageHeight: height,
      siteName: tags.first('og:site_name'),
      canonicalUrl: tags.first('og:url'),
    );
  }
}
