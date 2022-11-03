import 'package:bluebubbles/models/global/attributed_body.dart';

class MessageSummaryInfo {
  MessageSummaryInfo({
    required this.retractedParts,
    required this.editedContent,
    required this.originalTextRange,
    required this.editedParts,
  });

  List<int> retractedParts;
  Map<String, List<EditedContent>> editedContent;
  Map<String, List<int>> originalTextRange;
  List<int> editedParts;

  factory MessageSummaryInfo.fromJson(Map<String, dynamic> json) => MessageSummaryInfo(
    retractedParts: json["retractedParts"] ?? json["rp"] ?? [],
    editedContent: json["editedContent"] == null ? {} : json["editedContent"].map((String k, List v) => MapEntry(k, List<EditedContent>.from(v.map((x) => EditedContent.fromJson(x))))),
    originalTextRange: json["originalTextRange"] == null ? {} : json["originalTextRange"].map((String k, List v) => MapEntry(k, v)),
    editedParts: json["editedParts"] ?? [],
  );

  Map<String, dynamic> toJson() => {
    "retractedParts": retractedParts,
    "editedContent": editedContent.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
    "originalTextRange": originalTextRange,
    "editedParts": editedParts,
  };
}

class EditedContent {
  EditedContent({
    this.text,
    this.date,
  });

  Text? text;
  double? date;

  factory EditedContent.fromJson(Map<String, dynamic> json) => EditedContent(
    text: json["text"] == null ? null : Text.fromJson(json["text"]),
    date: json["date"],
  );

  Map<String, dynamic> toJson() => {
    "text": text?.toJson(),
    "date": date,
  };
}

class Text {
  Text({
    required this.values,
  });

  List<AttributedBody> values;

  factory Text.fromJson(Map<String, dynamic> json) => Text(
    values: json["values"] == null ? [] : List<AttributedBody>.from(json["values"].map((x) => AttributedBody.fromMap(x))),
  );

  Map<String, dynamic> toJson() => {
    "values": values.map((x) => x.toMap()),
  };
}
