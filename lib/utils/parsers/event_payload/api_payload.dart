import 'dart:convert';

import 'package:bluebubbles/services/backend/settings/settings_service.dart';
import 'package:bluebubbles/utils/crypto_utils.dart';
import 'package:get/get.dart';

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

SettingsService configuration = Get.isRegistered<SettingsService>() ? Get.find<SettingsService>() : Get.put(SettingsService());

class ApiPayload {
  Map<String, dynamic> payload;
  late dynamic data;
  late bool isLegacy;
  late PayloadType? type;
  late String? subtype;
  late bool isEncrypted;
  late bool isPartial;
  late PayloadEncoding encoding;
  late bool dataIsList;
  late bool dataIsString;

  ApiPayload(this.payload) {
    data = payload['data'];
    isLegacy = !payload.containsKey("type");
    type = payload['type'];
    subtype = payload['subtype'];
    isEncrypted = payload['encrypted'] ?? false;
    isPartial = payload['partial'] ?? false;
    encoding = payload['encoding'] ?? PayloadEncoding.JSON_OBJECT;

    // Decrypt the payload using the password (if encrypted)
    if (isEncrypted) {
      data = decryptAESCryptoJS(data, configuration.settings.guidAuthKey.value);
    }

    // If the data is encoded as a JSON and is a string, decode it and set the encoding
    if ([PayloadEncoding.JSON_OBJECT, PayloadEncoding.JSON_STRING].contains(encoding) && data is String) {
      data = jsonDecode(data);
      encoding = PayloadEncoding.JSON_OBJECT;
    }

    // These must be loaded after the data is decoded
    dataIsList = (isLegacy && payload is List) || (!isLegacy && data is List);
    dataIsString = (isLegacy && payload is String) || (!isLegacy && data is String);
  }
}