/// Identifies which extraction strategy produced a given metadata field.
///
/// The order of the enum values is the order the document pipeline runs them
/// in, and is also their trust order — earlier sources win when two strategies
/// both produce a value for the same field.
enum MetadataSource {
  /// `<meta property="og:*">` — the Open Graph protocol. Highest quality and
  /// by far the most widely deployed.
  openGraph('Open Graph'),

  /// `<meta name="twitter:*">` (also seen with `property=`).
  twitterCard('Twitter Card'),

  /// A provider's oEmbed endpoint, either discovered from a
  /// `<link rel="alternate" type="application/json+oembed">` tag or looked up
  /// in the known-provider registry.
  oEmbed('oEmbed'),

  /// `<script type="application/ld+json">` schema.org payloads.
  jsonLd('JSON-LD'),

  /// schema.org microdata (`itemprop` attributes).
  microdata('Microdata'),

  /// Plain HTML: `<title>`, `<meta name="description">`, `<link rel="canonical">`.
  htmlMeta('HTML'),

  /// A [SiteMetadataParser] that knows the specific site's DOM.
  siteParser('Site Parser'),

  /// The URL itself pointed directly at an image.
  directImage('Direct Image');

  const MetadataSource(this.label);

  /// Human readable name, used in debug logging only.
  final String label;
}
