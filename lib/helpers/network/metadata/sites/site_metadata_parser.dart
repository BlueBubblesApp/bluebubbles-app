import 'package:bluebubbles/helpers/network/metadata/models/url_metadata.dart';
import 'package:bluebubbles/helpers/network/metadata/parsing/metadata_parse_context.dart';

/// Site-specific knowledge that the generic vocabularies cannot express.
///
/// Most sites need none of this — Open Graph is enough. A site parser earns
/// its place only when a site is worth special-casing because its markup is
/// weak, its URLs need canonicalising, or its thumbnails live somewhere
/// predictable.
///
/// Each hook is optional; override only what the site actually needs.
abstract class SiteMetadataParser {
  const SiteMetadataParser();

  /// Name for logging.
  String get name;

  /// Whether this parser handles [url].
  bool matches(Uri url);

  /// Canonicalises [url] *before* the fetch.
  ///
  /// Use for expanding short forms and dropping site-specific tracking
  /// parameters. The user's original URL is preserved separately, so rewriting
  /// here never changes what tapping the preview opens.
  Uri prepare(Uri url) => url;

  /// Adjusts the parsed result using knowledge of the site's DOM.
  ///
  /// Runs after the generic pipeline, so [base] already holds whatever Open
  /// Graph and friends produced. Return [base] unchanged when there is nothing
  /// to add.
  UrlMetadata refine(UrlMetadata base, MetadataParseContext context) => base;

  /// Metadata derivable from the URL alone, applied when the fetch produced
  /// nothing usable.
  ///
  /// This is how a site that blocks crawlers still gets a recognisable card
  /// instead of a bare hostname. Only ever supply facts that follow from the
  /// URL itself — never invent a title or description.
  UrlMetadata? fallback(Uri url) => null;
}
