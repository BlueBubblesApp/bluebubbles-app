class AttributedBody {
  AttributedBody({
    required this.string,
    required this.runs,
  });

  final String string;
  final List<Run> runs;

  factory AttributedBody.fromMap(Map<String, dynamic> json) => AttributedBody(
    string: json["string"],
    runs: json["runs"] == null ? [] : List<Run>.from(json["runs"].map((x) => Run.fromMap(x!.cast<String, Object>()))),
  );

  Map<String, dynamic> toMap() => {
    "string": string,
    "runs": List<Map<String, dynamic>>.from(runs.map((x) => x.toMap())),
  };
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

  factory Run.fromMap(Map<String, dynamic> json) => Run(
    range: json["range"] == null ? [] : List<int>.from(json["range"].map((x) => x)),
    attributes: json["attributes"] == null ? null : Attributes.fromMap(json["attributes"]!.cast<String, Object>()),
  );

  Map<String, dynamic> toMap() => {
    "range": range,
    "attributes": attributes?.toMap(),
  };
}

class Attributes {
  Attributes({
    this.messagePart,
    this.attachmentGuid,
    this.mention,
    this.audioTranscript
  });

  final int? messagePart;
  final String? attachmentGuid;
  final String? mention;
  final String? audioTranscript;

  factory Attributes.fromMap(Map<String, dynamic> json) => Attributes(
    messagePart: json["__kIMMessagePartAttributeName"],
    attachmentGuid: json["__kIMFileTransferGUIDAttributeName"],
    mention: json["__kIMMentionConfirmedMention"],
    audioTranscript: json["IMAudioTranscription"]
  );

  Map<String, dynamic> toMap() => {
    "__kIMMessagePartAttributeName": messagePart,
    "__kIMFileTransferGUIDAttributeName": attachmentGuid,
    "__kIMMentionConfirmedMention": mention,
    "IMAudioTranscription": audioTranscript
  };
}
