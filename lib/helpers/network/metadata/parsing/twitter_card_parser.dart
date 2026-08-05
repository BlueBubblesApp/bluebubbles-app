import 'package:bluebubbles/helpers/network/metadata/models/metadata_source.dart';
import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';

/// Twitter Cards (`<meta name="twitter:*">`).
///
/// Both the `name` and `property` spellings are handled by [MetaTagIndex], so
/// this parser only has to list the key names.
class TwitterCardParser extends MetadataDocumentParser {
  const TwitterCardParser();

  @override
  MetadataSource get source => MetadataSource.twitterCard;

  /// `twitter:image:src` is the pre-2015 spelling; a surprising number of
  /// long-lived pages still only emit that one.
  static const List<String> _imageKeys = [
    'twitter:image',
    'twitter:image:src',
    'twitter:image0',
  ];

  @override
  UrlMetadata parse(MetadataParseContext context) {
    final tags = context.metaTags;

    return build(
      title: tags.first('twitter:title'),
      description: tags.first('twitter:description'),
      imageUrl: tags.firstOf(_imageKeys),
      imageWidth: tags.firstInt('twitter:image:width'),
      imageHeight: tags.firstInt('twitter:image:height'),
      // Deliberately not reading `twitter:site` — it holds an @handle, not a
      // display name, and rendering "@nytimes" as the site line looks wrong.
    );
  }
}
