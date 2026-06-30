import 'package:bluebubbles/database/global/attributed_body.dart';
import 'package:bluebubbles/utils/deep_map_normalize.dart';

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

  factory MessageSummaryInfo.fromJson(Map<String, dynamic> json) {
    json = asStringDynamicMapRequired(json);
    return MessageSummaryInfo(
      retractedParts: json["retractedParts"]?.cast<int>() ?? json["rp"]?.cast<int>() ?? [],
      editedContent: json["editedContent"] == null
          ? {}
          : json["editedContent"] is List
              ? {
                  "0": List<EditedContent>.from(
                    json["editedContent"].map((x) => EditedContent.fromJson(asStringDynamicMapRequired(x))),
                  )
                }
              : Map<String, List<EditedContent>>.from(
                  asStringDynamicMapRequired(json["editedContent"])!.map(
                    (k, v) => MapEntry(
                      k,
                      List<EditedContent>.from(
                        (v as List).map((x) => EditedContent.fromJson(asStringDynamicMapRequired(x))),
                      ),
                    ),
                  ),
                ),
      originalTextRange: json["originalTextRange"] == null
          ? {}
          : json["originalTextRange"] is List
              ? {"0": List<int>.from(json["originalTextRange"])}
              : Map<String, List<int>>.from(
                  asStringDynamicMapRequired(json["originalTextRange"])!.map(
                    (k, v) => MapEntry(k.toString(), List<int>.from(v as List)),
                  ),
                ),
      editedParts: json["editedParts"]?.cast<int>() ?? [],
    );
  }

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

  Content? text;
  double? date;

  factory EditedContent.fromJson(Map<String, dynamic> json) {
    json = asStringDynamicMapRequired(json);
    return EditedContent(
      text: json["text"] == null ? null : Content.fromJson(asStringDynamicMapRequired(json["text"])),
      date: json["date"],
    );
  }

  Map<String, dynamic> toJson() => {
        "text": text?.toJson(),
        "date": date,
      };
}

class Content {
  Content({
    required this.values,
  });

  List<AttributedBody> values;

  factory Content.fromJson(Map<String, dynamic> json) {
    json = asStringDynamicMapRequired(json);
    return Content(
      values: json["values"] == null
          ? []
          : List<AttributedBody>.from(
              json["values"].map((x) => AttributedBody.fromMap(asStringDynamicMapRequired(x))),
            ),
    );
  }

  Map<String, dynamic> toJson() => {
        "values": values.map((x) => x.toMap()).toList(),
      };
}