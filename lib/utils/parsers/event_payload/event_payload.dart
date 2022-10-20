import 'dart:convert';

enum PayloadEncoding {
  JSON_OBJECT,
  BASE64,
  JSON_STRING
}

enum PayloadType {
  NEW_MESAGE,
  UPDATED_MESSAGE,
  MESSAGE,
  CHAT,
  ATTACHMENT,
  HANDLE
}

class EventPayload {
  late dynamic data;
  late bool isLegacy;
  late PayloadType? type;
  late String? subtype;
  late bool isEncrypted;
  late bool isPartial;
  late PayloadEncoding encoding;

  EventPayload(Map<String, dynamic> payload) {
    data = payload['data'];
    isLegacy = !payload.containsKey("type");
    type = payload['type'];
    subtype = payload['subtype'];
    isEncrypted = payload['encrypted'] ?? false;
    isPartial = payload['partial'] ?? false;
    encoding = payload['encoding'] ?? PayloadEncoding.JSON_OBJECT;

    // If the data is encoded as a JSON string, decode it and set the encoding
    if (encoding == PayloadEncoding.JSON_STRING && data is String) {
      data = jsonDecode(data);
      encoding = PayloadEncoding.JSON_OBJECT;
    }
  }
}