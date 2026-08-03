import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/body_image_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/html_meta_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/icon_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/json_ld_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_document_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/microdata_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/open_graph_parser.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/twitter_card_parser.dart';
import 'package:bluebubbles/utils/logger/logger.dart';

/// Runs every document parser in trust order and folds the results together.
///
/// Precedence is expressed purely by ordering: the first strategy to produce a
/// field owns it, because [UrlMetadata.fillMissingFrom] never overwrites a
/// value that is already set.
abstract final class MetadataDocumentPipeline {
  /// Strategies that are always worth running, best-quality first.
  static const List<MetadataDocumentParser> _primary = [
    OpenGraphParser(),
    TwitterCardParser(),
    JsonLdParser(),
    HtmlMetaParser(),
  ];

  /// Only run when the primary strategies left a gap — these walk the DOM.
  static const MicrodataParser _microdata = MicrodataParser();
  static const BodyImageParser _bodyImage = BodyImageParser();
  static const IconParser _icon = IconParser();

  /// Extracts everything the document has to offer.
  ///
  /// Individual parsers are guarded: one malformed JSON-LD block or an
  /// unexpected DOM shape degrades that strategy rather than failing the whole
  /// preview.
  static UrlMetadata run(MetadataParseContext context) {
    var result = UrlMetadata.empty;

    for (final parser in _primary) {
      result = result.fillMissingFrom(_guard(parser, context));
      // Stop early only when the fields a card actually renders are all
      // present; a missing site name or icon is filled in below.
      if (result.hasCoreFields) break;
    }

    if (!result.hasCoreFields) {
      result = result.fillMissingFrom(_guard(_microdata, context));
    }

    if (result.imageUrl == null) {
      result = result.fillMissingFrom(_guard(_bodyImage, context));
    }

    if (result.iconUrl == null) {
      result = result.fillMissingFrom(_guard(_icon, context));
    }

    return result
        .copyWith(
          requestUrl: context.requestUri.toString(),
          finalUrl: context.finalUri.toString(),
        )
        .normalized(context.baseUri);
  }

  static UrlMetadata _guard(MetadataDocumentParser parser, MetadataParseContext context) {
    try {
      return parser.parse(context);
    } catch (ex, stack) {
      Logger.debug(
        'Metadata parser ${parser.runtimeType} failed for ${context.finalUri}: $ex',
        error: ex,
        trace: stack,
        tag: 'MetadataPipeline',
      );
      return UrlMetadata.empty;
    }
  }
}
