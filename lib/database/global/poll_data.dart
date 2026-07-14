import 'dart:convert';

/// Distinguishes the two poll response payload shapes. The initial poll
/// message carries no parseable vote/option data of its own (see
/// POLL_NOTES.md), so it has no corresponding kind here.
enum PollPayloadKind { vote, optionsUpdate }

class PollOption {
  PollOption({
    required this.optionIdentifier,
    required this.text,
    this.creatorHandle,
    this.canBeEdited = false,
  });

  final String optionIdentifier;
  final String text;
  final String? creatorHandle;
  final bool canBeEdited;

  factory PollOption.fromJson(Map<String, dynamic> json) => PollOption(
        optionIdentifier: json["optionIdentifier"] as String? ?? "",
        text: (json["text"] ?? json["attributedText"] ?? "") as String,
        creatorHandle: json["creatorHandle"] as String?,
        canBeEdited: json["canBeEdited"] == true,
      );
}

class PollVote {
  PollVote({required this.participantHandle, required this.voteOptionIdentifier});

  final String participantHandle;
  final String voteOptionIdentifier;

  factory PollVote.fromJson(Map<String, dynamic> json) => PollVote(
        participantHandle: json["participantHandle"] as String? ?? "",
        voteOptionIdentifier: json["voteOptionIdentifier"] as String? ?? "",
      );
}

class PollOptionsUpdate {
  PollOptionsUpdate({required this.options, this.creatorHandle, this.title});

  final List<PollOption> options;
  final String? creatorHandle;
  final String? title;

  factory PollOptionsUpdate.fromJson(Map<String, dynamic> item) {
    final title = item["title"] as String?;
    return PollOptionsUpdate(
      options: ((item["orderedPollOptions"] as List?) ?? [])
          .map((e) => PollOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      creatorHandle: item["creatorHandle"] as String?,
      title: (title == null || title.isEmpty) ? null : title,
    );
  }
}

class PollVoteBatch {
  PollVoteBatch({required this.votes});

  final List<PollVote> votes;

  factory PollVoteBatch.fromJson(Map<String, dynamic> item) => PollVoteBatch(
        votes: ((item["votes"] as List?) ?? [])
            .map((e) => PollVote.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// A decoded poll response payload — either a vote batch or an options
/// update, never both. Use [tryParse] as the single entry point.
class PollPayload {
  PollPayload({required this.kind, required this.version, this.voteBatch, this.optionsUpdate});

  final PollPayloadKind kind;
  final int version;
  final PollVoteBatch? voteBatch;
  final PollOptionsUpdate? optionsUpdate;

  /// Parses the `data:,<base64json>[?query]` URI found at
  /// `iMessageAppData.url` for a poll vote or options-update message.
  ///
  /// Returns null for a non-poll url, the initial poll message (which
  /// carries no vote/option data of its own), or any payload that fails to
  /// decode/parse.
  ///
  /// Note: this is NOT a standard RFC 2397 base64 data URI (no `;base64`
  /// media-type marker) — `Uri.parse(...).data`/`UriData` must not be used,
  /// as it would treat the payload as literal percent-decoded text rather
  /// than base64. The base64 blob is also missing its trailing `=` padding
  /// and, on options-update payloads, has a `?query` suffix appended after
  /// the base64 that is not part of it.
  ///
  /// Pure and synchronous — safe to call from inside GlobalIsolate or the
  /// main thread.
  static PollPayload? tryParse(String? rawUrl) {
    if (rawUrl == null || !rawUrl.startsWith("data:,")) return null;

    String b64 = rawUrl.substring("data:,".length);
    final queryIndex = b64.indexOf("?");
    if (queryIndex >= 0) b64 = b64.substring(0, queryIndex);

    Map<String, dynamic> json;
    try {
      final padded = base64.normalize(b64);
      json = jsonDecode(utf8.decode(base64.decode(padded))) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final item = json["item"] as Map<String, dynamic>?;
    if (item == null) return null;
    final version = json["version"] as int? ?? 1;

    if (item.containsKey("votes")) {
      return PollPayload(kind: PollPayloadKind.vote, version: version, voteBatch: PollVoteBatch.fromJson(item));
    } else if (item.containsKey("orderedPollOptions")) {
      return PollPayload(
          kind: PollPayloadKind.optionsUpdate, version: version, optionsUpdate: PollOptionsUpdate.fromJson(item));
    }
    return null;
  }
}
