import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/helpers/helpers.dart';

/// Domain text for a link preview — the configured [SiteDisplayNames] label for
/// the host, else the host without a leading `www.`.
///
/// Mirrors `UrlPreviewController.siteText`, including its fallbacks: Apple's
/// payload does not always carry a URL — an Apple Music link arrives as a
/// `specialization` blob with the link only on the message — so [messageUrl] is
/// threaded in, and `Uri.tryParse('')` yields an empty host rather than null,
/// which is why the `siteName` fallback needs an explicit emptiness check.
String linkPreviewDomain(UrlPreviewData data, {String? messageUrl}) {
  final host = MetadataUrls.parse(data.originalUrl ?? data.url ?? messageUrl)?.host;
  if (!isNullOrEmpty(host)) return SiteDisplayNames.forHost(host) ?? host!;
  return (data.siteName ?? '').replaceFirst(RegExp(r'^www\.'), '');
}

int _fieldMatchScore(String field, String query, int tierBase) {
  if (field.isEmpty) return 0;
  if (field == query) return tierBase + 30;
  if (field.startsWith(query)) return tierBase + 20;
  if (field.contains(query)) return tierBase + 10;
  return 0;
}

/// Match score for a link preview. Higher is better; `0` means no match.
/// Priority: domain (300) > title (200) > description/summary (100).
int linkPreviewSearchScore(UrlPreviewData data, String query, {String? messageUrl}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return 0;

  final domain = linkPreviewDomain(data, messageUrl: messageUrl).toLowerCase();
  final title = (data.title ?? '').toLowerCase();
  final description = (data.summary ?? '').toLowerCase();

  // Scored on the raw host too, not just the label [linkPreviewDomain] resolved
  // to. Once `chat.whatsapp.com` renders as "WhatsApp", searching for either the
  // name or the address a user remembers typing should still find the link.
  final host = (MetadataUrls.parse(data.originalUrl ?? data.url ?? messageUrl)?.host ?? '').toLowerCase();

  return [
    _fieldMatchScore(domain, normalizedQuery, 300),
    if (host != domain) _fieldMatchScore(host, normalizedQuery, 300),
    _fieldMatchScore(title, normalizedQuery, 200),
    _fieldMatchScore(description, normalizedQuery, 100),
  ].reduce((a, b) => a > b ? a : b);
}

/// Filters [messages] to link previews matching [query], ordered by best match then recency.
List<Message> filterAndSortLinks(List<Message> messages, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return messages;

  final scored = <({Message message, int score})>[];
  for (final message in messages) {
    final data = message.payloadData?.urlData?.firstOrNull;
    if (data == null) continue;
    final score = linkPreviewSearchScore(data, normalizedQuery, messageUrl: message.url);
    if (score > 0) {
      scored.add((message: message, score: score));
    }
  }

  scored.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    final aDate = a.message.dateCreated?.millisecondsSinceEpoch ?? 0;
    final bDate = b.message.dateCreated?.millisecondsSinceEpoch ?? 0;
    return bDate.compareTo(aDate);
  });

  return scored.map((e) => e.message).toList();
}
