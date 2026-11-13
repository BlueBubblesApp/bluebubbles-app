class AttributedBody {
  AttributedBody({required this.string, required this.runs});

  final String string;
  final List<Run> runs;

  factory AttributedBody.fromMap(Map<String, dynamic> json) => AttributedBody(
    string: json["string"] ?? "",
    runs: json["runs"] == null ? [] : List<Run>.from(json["runs"].map((x) => Run.fromMap(x!.cast<String, dynamic>()))),
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
  Run({required this.range, this.attributes});

  final List<int> range;
  final Attributes? attributes;

  bool get isAttachment => attributes?.attachmentGuid != null;
  bool get hasMention => attributes?.mention != null;
  bool get isEmojiImage => isAttachment && (attributes?.emojiImage ?? false);

  factory Run.fromMap(Map<String, dynamic> json) => Run(
    range: json["range"] == null ? [] : List<int>.from(json["range"].map((x) => x)),
    attributes: json["attributes"] == null ? null : Attributes.fromMap(json["attributes"]!.cast<String, dynamic>()),
  );

  Map<String, dynamic> toMap() => {"range": range, "attributes": attributes?.toMap()};
}

class Attributes {
  Attributes({
    int? messagePart,
    String? attachmentGuid,
    String? mention,
    String? audioTranscript,
    bool emojiImage = false,
    Map<String, dynamic> rawAttributes = const {},
  }) : rawAttributes = Map.unmodifiable({
         ...rawAttributes,
         '__kIMMessagePartAttributeName': ?messagePart,
         '__kIMFileTransferGUIDAttributeName': ?attachmentGuid,
         '__kIMMentionConfirmedMention': ?mention,
         'IMAudioTranscription': ?audioTranscript,
         if (emojiImage && !rawAttributes.containsKey('__kIMEmojiImageAttributeName'))
           '__kIMEmojiImageAttributeName': true,
       });

  /// All server attributes, including formatting and text effects not yet rendered by the app.
  /// The single source of truth for typed getters, JSON storage, and isolate serialization.
  final Map<String, dynamic> rawAttributes;

  int? get messagePart => rawAttributes['__kIMMessagePartAttributeName'] as int?;
  String? get attachmentGuid => rawAttributes['__kIMFileTransferGUIDAttributeName'] as String?;
  String? get mention => rawAttributes['__kIMMentionConfirmedMention'] as String?;
  String? get audioTranscript => rawAttributes['IMAudioTranscription'] as String?;

  bool get isBold => rawAttributes['__kIMTextBoldAttributeName'] == 1;
  bool get isItalic => rawAttributes['__kIMTextItalicAttributeName'] == 1;
  bool get isUnderlined => rawAttributes['__kIMTextUnderlineAttributeName'] == 1;
  bool get isStrikethrough => rawAttributes['__kIMTextStrikethroughAttributeName'] == 1;

  /// The attachment is a Genmoji
  bool get emojiImage => rawAttributes['__kIMEmojiImageAttributeName'] != null;

  factory Attributes.fromMap(Map<String, dynamic> json) => Attributes(rawAttributes: json);

  Map<String, dynamic> toMap() => Map.of(rawAttributes);
}
