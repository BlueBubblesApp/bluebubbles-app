class AttributedBody {
  AttributedBody({
    required this.string,
    required this.runs,
  });

  final String string;
  final List<Run> runs;

  factory AttributedBody.fromMap(Map<String, dynamic> json) => AttributedBody(
        string: json["string"] ?? "",
        runs:
            json["runs"] == null ? [] : List<Run>.from(json["runs"].map((x) => Run.fromMap(x!.cast<String, dynamic>()))),
      );

  Map<String, dynamic> toMap() => {
        "string": string,
        "runs": List<Map<String, dynamic>>.from(runs.map((x) => x.toMap())),
      };

  /// Genmoji drawn inside their part's text. One alone in its part shows as an image instead, as iMessage does.
  Iterable<Run> get inlineRuns {
    final textParts = runs.where((r) => !r.isAttachment).map((r) => r.attributes?.messagePart).toSet();
    return runs.where((r) => r.isEmojiImage && textParts.contains(r.attributes?.messagePart));
  }
}

class Run {
  Run({
    required this.range,
    this.attributes,
  });

  final List<int> range;
  final Attributes? attributes;

  bool get isAttachment => attributes?.attachmentGuid != null;
  bool get hasMention => attributes?.mention != null;
  bool get isEmojiImage => isAttachment && (attributes?.emojiImage ?? false);

  factory Run.fromMap(Map<String, dynamic> json) => Run(
        range: json["range"] == null ? [] : List<int>.from(json["range"].map((x) => x)),
        attributes: json["attributes"] == null ? null : Attributes.fromMap(json["attributes"]!.cast<String, dynamic>()),
      );

  Map<String, dynamic> toMap() => {
        "range": range,
        "attributes": attributes?.toMap(),
      };
}

class Attributes {
  Attributes({this.messagePart, this.attachmentGuid, this.mention, this.audioTranscript, this.emojiImage = false});

  final int? messagePart;
  final String? attachmentGuid;
  final String? mention;
  final String? audioTranscript;

  /// The attachment is a Genmoji
  final bool emojiImage;

  factory Attributes.fromMap(Map<String, dynamic> json) => Attributes(
      messagePart: json["__kIMMessagePartAttributeName"],
      attachmentGuid: json["__kIMFileTransferGUIDAttributeName"],
      mention: json["__kIMMentionConfirmedMention"],
      audioTranscript: json["IMAudioTranscription"],
      emojiImage: json["__kIMEmojiImageAttributeName"] != null);

  Map<String, dynamic> toMap() {
    // Only include non-null values
    final Map<String, dynamic> map = {};
    if (messagePart != null) map["__kIMMessagePartAttributeName"] = messagePart;
    if (attachmentGuid != null) map["__kIMFileTransferGUIDAttributeName"] = attachmentGuid;
    if (mention != null) map["__kIMMentionConfirmedMention"] = mention;
    if (audioTranscript != null) map["IMAudioTranscription"] = audioTranscript;
    if (emojiImage) map["__kIMEmojiImageAttributeName"] = true;
    return map;
  }
}
