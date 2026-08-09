import 'package:bluebubbles/database/models.dart';

int _fieldMatchScore(String field, String query, int tierBase) {
  if (field.isEmpty) return 0;
  if (field == query) return tierBase + 30;
  if (field.startsWith(query)) return tierBase + 20;
  if (field.contains(query)) return tierBase + 10;
  return 0;
}

/// Match score for a file attachment. Higher is better; `0` means no match.
/// Priority: filename (200) > mime type (100).
int fileSearchScore(Attachment attachment, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return 0;

  final name = (attachment.transferName ?? '').toLowerCase();
  final mime = (attachment.mimeType ?? '').toLowerCase();

  return [
    _fieldMatchScore(name, normalizedQuery, 200),
    _fieldMatchScore(mime, normalizedQuery, 100),
  ].reduce((a, b) => a > b ? a : b);
}

/// Filters [attachments] to those matching [query], ordered by best match then recency.
List<Attachment> filterAndSortFiles(List<Attachment> attachments, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return attachments;

  final scored = <({Attachment attachment, int score})>[];
  for (final attachment in attachments) {
    final score = fileSearchScore(attachment, normalizedQuery);
    if (score > 0) {
      scored.add((attachment: attachment, score: score));
    }
  }

  scored.sort((a, b) {
    final scoreCompare = b.score.compareTo(a.score);
    if (scoreCompare != 0) return scoreCompare;
    final aDate = a.attachment.message.target?.dateCreated?.millisecondsSinceEpoch ?? 0;
    final bDate = b.attachment.message.target?.dateCreated?.millisecondsSinceEpoch ?? 0;
    return bDate.compareTo(aDate);
  });

  return scored.map((e) => e.attachment).toList();
}
