
import 'package:bluebubbles/utils/parsers/event_payload/event_payload.dart';

class ApiPayloadParser {

  EventPayload payload;

  ApiPayloadParser(this.payload);

  dynamic parse() {
    if (payload.isLegacy) {
      return parseLegacyPayload();
    } else {
      return parsePayload();
    }
  }

  dynamic parseLegacyPayload() {
    // The legacy payload is just a message payload (JSON)
    return parseMessage(payload as Map<String, dynamic>);
  }

  dynamic parsePayload() {
    if ([PayloadType.NEW_MESAGE, PayloadType.UPDATED_MESSAGE, PayloadType.MESSAGE].contains(payload.type)) {
      return parseMessage(payload.data);
    } else if (payload.type == PayloadType.CHAT) {
      return parseChat(payload.data);
    } else if (payload.type == PayloadType.ATTACHMENT) {
      return parseAttachment(payload.data);
    } else if (payload.type == PayloadType.HANDLE) {
      return parseHandle(payload.data);
    } else {
      return null;
    }
  }

  dynamic parseMessage(Map<String, dynamic> message) {

  }

  dynamic parseAttachment(Map<String, dynamic> attachment) {

  }

  dynamic parseChat(Map<String, dynamic> chat) {

  }

  dynamic parseHandle(Map<String, dynamic> handle) {

  }
}