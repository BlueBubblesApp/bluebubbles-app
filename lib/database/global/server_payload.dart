import 'dart:convert';

import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:bluebubbles/utils/crypto_utils.dart';
import 'package:collection/collection.dart';

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
  HANDLE,
  OTHER,
}

enum EncryptionType {
  AES_PB,
}

class ServerPayload {
  dynamic originalJson;
  dynamic data;
  final bool isLegacy;
  final PayloadType type;
  final String? subtype;
  final bool isEncrypted;
  final bool isPartial;
  PayloadEncoding encoding;
  final EncryptionType encryptionType;

  bool get isList => (isLegacy && originalJson is List) || (!isLegacy && data is List);
  bool get isString => (isLegacy && originalJson is String) || (!isLegacy && data is String);
  bool get isDict => (isLegacy && originalJson is Map) || (!isLegacy && data is Map);

  ServerPayload({
    required this.originalJson,
    this.data,
    required this.isLegacy,
    required this.type,
    this.subtype,
    required this.isEncrypted,
    required this.isPartial,
    required this.encoding,
    required this.encryptionType,
  });

  /// Creates a ServerPayload from JSON and handles decryption if needed
  static Future<ServerPayload> fromJsonAsync(Map<String, dynamic> json) async {
    final isEncrypted = json["encrypted"] ?? false;
    PayloadEncoding encoding =
        PayloadEncoding.values.firstWhereOrNull((element) => element.name == json["encoding"]) ?? PayloadEncoding.JSON_OBJECT;

    dynamic data = json["data"] ?? json;

    // Do not decode before decrypting encrypted payloads
    if (!isEncrypted && _shouldDecode(encoding, data)) {
      data = jsonDecode(data as String);
      encoding = PayloadEncoding.JSON_OBJECT;
    }

    final payload = ServerPayload(
      originalJson: json,
      data: data,
      isLegacy: json.containsKey("type"),
      type: PayloadType.values.firstWhereOrNull((element) => element.name == json["type"]) ?? PayloadType.OTHER,
      subtype: json["subtype"],
      isEncrypted: isEncrypted,
      isPartial: json["partial"] ?? false,
      encoding: encoding,
      encryptionType: EncryptionType.values.firstWhereOrNull((element) => element.name == json["encryptionType"]) ?? EncryptionType.AES_PB,
    );

    // Handle decryption if needed
    if (payload.isEncrypted) {
      if (payload.encryptionType == EncryptionType.AES_PB && payload.data is String) {
        payload.data = await decryptAESCryptoJS(payload.data, ss.settings.guidAuthKey.value);
      }
    }

    // Handle JSON decoding post-decryption
    if (_shouldDecode(payload.encoding, payload.data)) {
      payload.data = jsonDecode(payload.data as String);
      payload.encoding = PayloadEncoding.JSON_OBJECT;
    }

    return payload;
  }

  /// Synchronous factory for backward compatibility - use only when encryption is not used
  factory ServerPayload.fromJson(Map<String, dynamic> json) {
    final isEncrypted = json["encrypted"] ?? false;
    PayloadEncoding encoding =
        PayloadEncoding.values.firstWhereOrNull((element) => element.name == json["encoding"]) ?? PayloadEncoding.JSON_OBJECT;

    dynamic data = json["data"] ?? json;

    // Only decode when not encrypted; encrypted payloads must use fromJsonAsync
    if (!isEncrypted && _shouldDecode(encoding, data)) {
      data = jsonDecode(data as String);
      encoding = PayloadEncoding.JSON_OBJECT;
    }

    return ServerPayload(
      originalJson: json,
      data: data,
      isLegacy: json.containsKey("type"),
      type: PayloadType.values.firstWhereOrNull((element) => element.name == json["type"]) ?? PayloadType.OTHER,
      subtype: json["subtype"],
      isEncrypted: isEncrypted,
      isPartial: json["partial"] ?? false,
      encoding: encoding,
      encryptionType: EncryptionType.values.firstWhereOrNull((element) => element.name == json["encryptionType"]) ?? EncryptionType.AES_PB,
    );
  }
}

bool _shouldDecode(PayloadEncoding encoding, dynamic data) {
  return [PayloadEncoding.JSON_OBJECT, PayloadEncoding.JSON_STRING].contains(encoding) && data is String;
}